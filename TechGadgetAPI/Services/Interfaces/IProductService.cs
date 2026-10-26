using BusinessObjects.DTOs;

namespace Services.Interfaces;

public interface IProductService
{
    Task<PagedResult<ProductListItemDto>> GetProductsAsync(ProductQueryParams query);
    Task<ProductDetailDto?> GetProductByIdAsync(Guid id);
    Task<ProductDetailDto?> GetProductBySlugAsync(string slug);
}
