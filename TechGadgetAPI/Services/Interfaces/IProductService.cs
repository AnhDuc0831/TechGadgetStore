using BusinessObjects.DTOs;

namespace Services.Interfaces;

public interface IProductService
{
    Task<PagedResult<ProductListItemDto>> GetProductsAsync(ProductQueryParams query);
    Task<PagedResult<ProductListItemDto>> GetAdminProductsAsync(AdminProductQueryParams query);
    Task<ProductDetailDto?> GetProductByIdAsync(Guid id);
    Task<ProductDetailDto?> GetAdminProductByIdAsync(Guid id);
    Task<ProductDetailDto?> GetProductBySlugAsync(string slug);
    Task<ProductDetailDto> CreateProductAsync(CreateProductRequest request);
    Task<ProductDetailDto> UpdateProductAsync(Guid id, UpdateProductRequest request);
    Task<bool> SoftDeleteProductAsync(Guid id);
    Task<bool> RestoreProductAsync(Guid id);
}
