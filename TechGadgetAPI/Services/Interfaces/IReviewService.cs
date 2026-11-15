using BusinessObjects.DTOs;

namespace Services.Interfaces;

public interface IReviewService
{
    // Public
    Task<ProductReviewsResponse> GetProductReviewsAsync(Guid productId, ReviewQueryParams query, Guid? currentUserId);

    // Customer
    Task<MyReviewStatusDto> GetMyReviewStatusAsync(Guid productId, Guid userId);
    Task<ReviewDto> SubmitReviewAsync(Guid productId, Guid userId, SubmitReviewRequest request);
    Task<List<PendingReviewItemDto>> GetPendingReviewsAsync(Guid userId);

    // Admin
    Task<PagedResult<AdminReviewDto>> GetAdminReviewsAsync(AdminReviewQueryParams query);
    Task<AdminReviewDto> ReplyAsync(Guid reviewId, string? reply);

    /// <summary>Ẩn / hiện nội dung (bình luận + ảnh) của đánh giá khiếm nhã. Số sao luôn được giữ.</summary>
    Task<AdminReviewDto> SetContentHiddenAsync(Guid reviewId, bool hidden, string? reason);
}
