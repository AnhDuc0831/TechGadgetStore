using BusinessObjects.Models;
using DataAccessObjects;
using Repositories.Interfaces;

namespace Repositories.Implementations;

public class ReviewRepository : IReviewRepository
{
    private readonly ReviewDAO _reviewDao;

    public ReviewRepository(ReviewDAO reviewDao)
    {
        _reviewDao = reviewDao;
    }

    public Task<(List<Review> Items, int TotalCount)> GetProductReviewsAsync(Guid productId, int page, int pageSize, int? rating, bool hasImages) =>
        _reviewDao.GetProductReviewsAsync(productId, page, pageSize, rating, hasImages);

    public Task<(Dictionary<int, int> RatingCounts, int WithImages)> GetSummaryAsync(Guid productId) =>
        _reviewDao.GetSummaryAsync(productId);

    public Task<bool> ProductExistsAsync(Guid productId) => _reviewDao.ProductExistsAsync(productId);

    public Task<Review?> GetUserReviewAsync(Guid productId, Guid userId) => _reviewDao.GetUserReviewAsync(productId, userId);

    public Task<(Guid OrderId, string Sku)?> GetCompletedPurchaseAsync(Guid productId, Guid userId) =>
        _reviewDao.GetCompletedPurchaseAsync(productId, userId);

    public Task<bool> HasInProgressPurchaseAsync(Guid productId, Guid userId) =>
        _reviewDao.HasInProgressPurchaseAsync(productId, userId);

    public Task<int> CountRecentSubmissionsAsync(Guid userId, DateTimeOffset since) =>
        _reviewDao.CountRecentSubmissionsAsync(userId, since);

    public Task<List<(Guid ProductId, string ProductName, string? Thumbnail, string Sku, Guid OrderId, DateTimeOffset PurchasedAt)>> GetPendingReviewsAsync(Guid userId) =>
        _reviewDao.GetPendingReviewsAsync(userId);

    public Task<Review> AddAsync(Review review) => _reviewDao.AddAsync(review);

    public Task UpdateAsync(Review review) => _reviewDao.UpdateAsync(review);

    public Task<(List<Review> Items, int TotalCount)> GetAdminReviewsAsync(int page, int pageSize, int? rating, bool? hasReply, string? search) =>
        _reviewDao.GetAdminReviewsAsync(page, pageSize, rating, hasReply, search);

    public Task<Review?> GetByIdAsync(Guid id) => _reviewDao.GetByIdAsync(id);
}
