using BusinessObjects.DTOs;
using BusinessObjects.Models;

namespace Repositories.Interfaces;

public interface IProductRepository
{
    Task<PagedResult<ProductListItemDto>> GetPagedAsync(ProductQueryParams query);
    Task<PagedResult<ProductListItemDto>> GetAdminPagedAsync(AdminProductQueryParams query);
    Task<Product?> GetActiveByIdAsync(Guid id);
    Task<Product?> GetByIdWithDetailsAsync(Guid id, bool includeInactive = true);
    Task<Product?> GetActiveBySlugAsync(string slug);
    Task<Product> CreateAsync(Product product, ProductVariant defaultVariant);
    Task UpdateAsync(Product product, ProductVariant? defaultVariant = null);
    Task<bool> SoftDeleteAsync(Guid id);
    Task<bool> RestoreAsync(Guid id);
    Task<(double AverageRating, int ReviewCount)> GetRatingSummaryAsync(Guid productId);
}
