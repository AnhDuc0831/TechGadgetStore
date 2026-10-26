using BusinessObjects.DTOs;
using BusinessObjects.Models;

namespace Repositories.Interfaces;

public interface IProductRepository
{
    Task<PagedResult<ProductListItemDto>> GetPagedAsync(ProductQueryParams query);
    Task<Product?> GetActiveByIdAsync(Guid id);
    Task<Product?> GetActiveBySlugAsync(string slug);
    Task<(double AverageRating, int ReviewCount)> GetRatingSummaryAsync(Guid productId);
}
