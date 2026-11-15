using BusinessObjects.Models;

namespace Repositories.Interfaces;

public interface IReviewRepository
{
    Task<(List<Review> Items, int TotalCount)> GetProductReviewsAsync(Guid productId, int page, int pageSize, int? rating, bool hasImages);
    Task<(Dictionary<int, int> RatingCounts, int WithImages)> GetSummaryAsync(Guid productId);
    Task<bool> ProductExistsAsync(Guid productId);

    Task<Review?> GetUserReviewAsync(Guid productId, Guid userId);
    Task<(Guid OrderId, string Sku)?> GetCompletedPurchaseAsync(Guid productId, Guid userId);
    Task<bool> HasInProgressPurchaseAsync(Guid productId, Guid userId);
    Task<int> CountRecentSubmissionsAsync(Guid userId, DateTimeOffset since);
    Task<List<(Guid ProductId, string ProductName, string? Thumbnail, string Sku, Guid OrderId, DateTimeOffset PurchasedAt)>> GetPendingReviewsAsync(Guid userId);
    Task<Review> AddAsync(Review review);
    Task UpdateAsync(Review review);

    Task<(List<Review> Items, int TotalCount)> GetAdminReviewsAsync(int page, int pageSize, int? rating, bool? hasReply, string? search);
    Task<Review?> GetByIdAsync(Guid id);
}
