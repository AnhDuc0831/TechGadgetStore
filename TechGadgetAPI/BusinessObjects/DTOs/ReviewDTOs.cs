using Microsoft.AspNetCore.Http;

namespace BusinessObjects.DTOs;

// =====================================================================
// PUBLIC
// =====================================================================

public class ReviewQueryParams
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 10;

    /// <summary>Lọc theo số sao (1-5), null = tất cả.</summary>
    public int? Rating { get; set; }

    /// <summary>Chỉ lấy đánh giá có ảnh.</summary>
    public bool HasImages { get; set; }
}

public class ReviewDto
{
    public Guid Id { get; set; }
    public Guid ProductId { get; set; }
    public int Rating { get; set; }
    public string? Comment { get; set; }
    public List<string> Images { get; set; } = new();

    /// <summary>Tên đã che bớt, VD: "Nguyễn V***".</summary>
    public string ReviewerName { get; set; } = string.Empty;
    public string? ReviewerAvatarUrl { get; set; }
    public string? VariantSku { get; set; }
    public bool IsVerifiedPurchase { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? EditedAt { get; set; }
    public string? AdminReply { get; set; }
    public DateTimeOffset? RepliedAt { get; set; }
    public bool IsMine { get; set; }
}

public class ReviewSummaryDto
{
    public double AverageRating { get; set; }
    public int TotalCount { get; set; }
    public int WithImagesCount { get; set; }

    /// <summary>Số lượng theo sao: key "5","4","3","2","1".</summary>
    public Dictionary<string, int> RatingCounts { get; set; } = new();
}

public class ProductReviewsResponse
{
    public ReviewSummaryDto Summary { get; set; } = new();
    public PagedResult<ReviewDto> Reviews { get; set; } = new();
}

// =====================================================================
// CUSTOMER
// =====================================================================

public class MyReviewStatusDto
{
    public bool CanReview { get; set; }

    /// <summary>Lý do chưa thể đánh giá (chưa mua / đơn chưa hoàn thành...).</summary>
    public string? Reason { get; set; }
    public ReviewDto? MyReview { get; set; }
}

public class SubmitReviewRequest
{
    public int Rating { get; set; }
    public string? Comment { get; set; }

    /// <summary>Ảnh mới tải lên (multipart).</summary>
    public List<IFormFile>? Images { get; set; }

    /// <summary>Khi sửa đánh giá: các URL ảnh cũ muốn giữ lại.</summary>
    public List<string>? KeepImageUrls { get; set; }
}

public class PendingReviewItemDto
{
    public Guid ProductId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string? ThumbnailUrl { get; set; }
    public string? VariantSku { get; set; }
    public Guid OrderId { get; set; }
    public DateTimeOffset PurchasedAt { get; set; }
}

// =====================================================================
// ADMIN
// =====================================================================

public class AdminReviewQueryParams
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
    public int? Rating { get; set; }

    /// <summary>true = đã phản hồi, false = chưa phản hồi, null = tất cả.</summary>
    public bool? HasReply { get; set; }
    public string? Search { get; set; }
}

public class AdminReviewDto : ReviewDto
{
    public string ProductName { get; set; } = string.Empty;
    public string? ProductThumbnailUrl { get; set; }
    public Guid? OrderId { get; set; }
}

public class ReplyReviewRequest
{
    /// <summary>Nội dung phản hồi. Để trống để gỡ phản hồi.</summary>
    public string? Reply { get; set; }
}
