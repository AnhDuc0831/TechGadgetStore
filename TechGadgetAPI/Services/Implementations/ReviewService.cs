using BusinessObjects.DTOs;
using BusinessObjects.Helpers;
using BusinessObjects.Models;
using Microsoft.AspNetCore.Http;
using Repositories.Interfaces;
using Services.Interfaces;

namespace Services.Implementations;

/// <summary>
/// Đánh giá sản phẩm.
/// Quy tắc:
///  1. Chỉ khách có đơn ĐÃ HOÀN THÀNH chứa sản phẩm mới được đánh giá.
///  2. Mỗi khách 1 đánh giá / sản phẩm, được sửa (hiển thị "đã chỉnh sửa").
///  3. Shop KHÔNG được ẩn/xóa/sửa đánh giá, chỉ được phản hồi công khai.
///  4. Nội dung vi phạm (SĐT, email, link, từ thô tục, spam) bị chặn tự động lúc gửi.
///  5. Mọi đánh giá đều được tính vào điểm trung bình.
/// </summary>
public class ReviewService : IReviewService
{
    public const int MaxImages = 5;
    public const int MaxReplyLength = 1000;
    public const int RateLimitCount = 5;
    public static readonly TimeSpan RateLimitWindow = TimeSpan.FromMinutes(10);
    private const string ImageFolder = "tech_gadgets/reviews";

    private readonly IReviewRepository _reviewRepo;
    private readonly ICloudinaryService _cloudinary;
    private readonly TimeProvider _timeProvider;

    public ReviewService(IReviewRepository reviewRepo, ICloudinaryService cloudinary, TimeProvider? timeProvider = null)
    {
        _reviewRepo = reviewRepo;
        _cloudinary = cloudinary;
        _timeProvider = timeProvider ?? TimeProvider.System;
    }

    private DateTimeOffset Now => _timeProvider.GetUtcNow();

    // =====================================================================
    // PUBLIC
    // =====================================================================

    public async Task<ProductReviewsResponse> GetProductReviewsAsync(Guid productId, ReviewQueryParams query, Guid? currentUserId)
    {
        if (!await _reviewRepo.ProductExistsAsync(productId))
        {
            throw new KeyNotFoundException("Không tìm thấy sản phẩm.");
        }

        var page = Math.Max(1, query.Page);
        var pageSize = Math.Clamp(query.PageSize, 1, 50);

        var (items, total) = await _reviewRepo.GetProductReviewsAsync(productId, page, pageSize, query.Rating, query.HasImages);
        var (counts, withImages) = await _reviewRepo.GetSummaryAsync(productId);

        var totalAll = counts.Values.Sum();
        var average = totalAll == 0 ? 0 : counts.Sum(kv => kv.Key * kv.Value) / (double)totalAll;

        return new ProductReviewsResponse
        {
            Summary = new ReviewSummaryDto
            {
                AverageRating = Math.Round(average, 1),
                TotalCount = totalAll,
                WithImagesCount = withImages,
                RatingCounts = Enumerable.Range(1, 5)
                    .Reverse()
                    .ToDictionary(star => star.ToString(), star => counts.GetValueOrDefault(star))
            },
            Reviews = new PagedResult<ReviewDto>
            {
                Items = items.Select(r => MapToDto(r, currentUserId)).ToList(),
                Page = page,
                PageSize = pageSize,
                TotalCount = total
            }
        };
    }

    // =====================================================================
    // CUSTOMER
    // =====================================================================

    public async Task<MyReviewStatusDto> GetMyReviewStatusAsync(Guid productId, Guid userId)
    {
        var myReview = await _reviewRepo.GetUserReviewAsync(productId, userId);
        var purchase = await _reviewRepo.GetCompletedPurchaseAsync(productId, userId);

        if (purchase == null && myReview == null)
        {
            return new MyReviewStatusDto
            {
                CanReview = false,
                Reason = await GetCannotReviewReasonAsync(productId, userId)
            };
        }

        return new MyReviewStatusDto
        {
            CanReview = true,
            MyReview = myReview == null ? null : MapToDto(myReview, userId)
        };
    }

    public async Task<ReviewDto> SubmitReviewAsync(Guid productId, Guid userId, SubmitReviewRequest request)
    {
        // 1. Kiểm tra dữ liệu đầu vào (trước khi upload ảnh để không tạo ảnh rác)
        if (request.Rating < 1 || request.Rating > 5)
        {
            throw new InvalidOperationException("Vui lòng chọn số sao từ 1 đến 5.");
        }

        var comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim();
        var violation = ReviewContentFilter.Validate(comment);
        if (violation != null)
        {
            throw new InvalidOperationException(violation);
        }

        if (!await _reviewRepo.ProductExistsAsync(productId))
        {
            throw new KeyNotFoundException("Không tìm thấy sản phẩm.");
        }

        // 2. Chỉ khách đã mua & đơn đã hoàn thành
        var existing = await _reviewRepo.GetUserReviewAsync(productId, userId);
        var purchase = await _reviewRepo.GetCompletedPurchaseAsync(productId, userId);
        if (purchase == null && existing == null)
        {
            throw new InvalidOperationException(await GetCannotReviewReasonAsync(productId, userId));
        }

        // 3. Chống spam
        var now = Now;
        var recent = await _reviewRepo.CountRecentSubmissionsAsync(userId, now - RateLimitWindow);
        if (recent >= RateLimitCount)
        {
            throw new InvalidOperationException("Bạn gửi đánh giá quá nhanh. Vui lòng thử lại sau ít phút.");
        }

        // 4. Ảnh: giữ ảnh cũ (chỉ những ảnh thực sự thuộc đánh giá này) + ảnh mới
        var keepImages = existing == null
            ? new List<string>()
            : (request.KeepImageUrls ?? new List<string>()).Where(existing.Images.Contains).Distinct().ToList();

        var newFiles = (request.Images ?? new List<IFormFile>()).Where(f => f.Length > 0).ToList();
        ValidateImages(newFiles, keepImages.Count);

        var uploaded = newFiles.Count == 0
            ? new List<string>()
            : await _cloudinary.UploadImagesAsync(newFiles, ImageFolder);

        var images = keepImages.Concat(uploaded).Take(MaxImages).ToList();

        // 5. Tạo mới hoặc cập nhật
        if (existing != null)
        {
            existing.Rating = (short)request.Rating;
            existing.Comment = comment;
            existing.Images = images;
            existing.EditedAt = now;
            if (purchase != null)
            {
                existing.OrderId = purchase.Value.OrderId;
                existing.VariantSku = purchase.Value.Sku;
            }
            await _reviewRepo.UpdateAsync(existing);
            return MapToDto(existing, userId);
        }

        var review = new Review
        {
            Id = Guid.NewGuid(),
            ProductId = productId,
            UserId = userId,
            Rating = (short)request.Rating,
            Comment = comment,
            Images = images,
            OrderId = purchase!.Value.OrderId,
            VariantSku = purchase.Value.Sku,
            CreatedAt = now,
            UpdatedAt = now
        };
        await _reviewRepo.AddAsync(review);

        // Tải lại để có thông tin người đánh giá (tên, avatar)
        var saved = await _reviewRepo.GetUserReviewAsync(productId, userId) ?? review;
        return MapToDto(saved, userId);
    }

    public async Task<List<PendingReviewItemDto>> GetPendingReviewsAsync(Guid userId)
    {
        var rows = await _reviewRepo.GetPendingReviewsAsync(userId);
        return rows.Select(r => new PendingReviewItemDto
        {
            ProductId = r.ProductId,
            ProductName = r.ProductName,
            ThumbnailUrl = r.Thumbnail,
            VariantSku = r.Sku,
            OrderId = r.OrderId,
            PurchasedAt = r.PurchasedAt
        }).ToList();
    }

    // =====================================================================
    // ADMIN
    // =====================================================================

    public async Task<PagedResult<AdminReviewDto>> GetAdminReviewsAsync(AdminReviewQueryParams query)
    {
        var page = Math.Max(1, query.Page);
        var pageSize = Math.Clamp(query.PageSize, 1, 100);
        var (items, total) = await _reviewRepo.GetAdminReviewsAsync(page, pageSize, query.Rating, query.HasReply, query.Search);

        return new PagedResult<AdminReviewDto>
        {
            Items = items.Select(MapToAdminDto).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = total
        };
    }

    public async Task<AdminReviewDto> ReplyAsync(Guid reviewId, string? reply)
    {
        var review = await _reviewRepo.GetByIdAsync(reviewId)
                     ?? throw new KeyNotFoundException("Không tìm thấy đánh giá.");

        var text = string.IsNullOrWhiteSpace(reply) ? null : reply.Trim();
        if (text != null && text.Length > MaxReplyLength)
        {
            throw new InvalidOperationException($"Phản hồi tối đa {MaxReplyLength} ký tự.");
        }

        // Shop chỉ thay đổi phần phản hồi của mình, KHÔNG đụng tới nội dung/số sao của khách
        review.AdminReply = text;
        review.RepliedAt = text == null ? null : Now;
        await _reviewRepo.UpdateAsync(review);

        return MapToAdminDto(review);
    }

    // =====================================================================
    // HELPERS
    // =====================================================================

    private async Task<string> GetCannotReviewReasonAsync(Guid productId, Guid userId)
    {
        return await _reviewRepo.HasInProgressPurchaseAsync(productId, userId)
            ? "Bạn có thể đánh giá sau khi đơn hàng được giao thành công."
            : "Chỉ khách hàng đã mua và nhận sản phẩm này mới có thể đánh giá.";
    }

    private static void ValidateImages(List<IFormFile> files, int keptCount)
    {
        if (keptCount + files.Count > MaxImages)
        {
            throw new InvalidOperationException($"Mỗi đánh giá tối đa {MaxImages} ảnh.");
        }

        foreach (var f in files)
        {
            ImageFileRules.EnsureValid(f);
        }
    }

    private static ReviewDto MapToDto(Review r, Guid? currentUserId) => Fill(new ReviewDto(), r, currentUserId);

    private static AdminReviewDto MapToAdminDto(Review r)
    {
        var dto = Fill(new AdminReviewDto(), r, null);
        dto.ProductName = r.Product?.Name ?? string.Empty;
        dto.ProductThumbnailUrl = r.Product?.ThumbnailUrl;
        dto.OrderId = r.OrderId;
        return dto;
    }

    private static T Fill<T>(T dto, Review r, Guid? currentUserId) where T : ReviewDto
    {
        dto.Id = r.Id;
        dto.ProductId = r.ProductId;
        dto.Rating = r.Rating;
        dto.Comment = r.Comment;
        dto.Images = r.Images ?? new List<string>();
        dto.ReviewerName = ReviewContentFilter.MaskName(r.User?.FullName);
        dto.ReviewerAvatarUrl = r.User?.AvatarUrl;
        dto.VariantSku = r.VariantSku;
        dto.IsVerifiedPurchase = r.OrderId != null;
        dto.CreatedAt = r.CreatedAt;
        dto.EditedAt = r.EditedAt;
        dto.AdminReply = r.AdminReply;
        dto.RepliedAt = r.RepliedAt;
        dto.IsMine = currentUserId.HasValue && r.UserId == currentUserId.Value;
        return dto;
    }
}
