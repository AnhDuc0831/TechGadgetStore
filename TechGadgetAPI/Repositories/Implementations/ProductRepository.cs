using BusinessObjects.DTOs;
using BusinessObjects.Models;
using DataAccessObjects;
using Repositories.Interfaces;

namespace Repositories.Implementations;

public class ProductRepository : IProductRepository
{
    private readonly ProductDAO _productDAO;

    public ProductRepository(ProductDAO productDAO)
    {
        _productDAO = productDAO;
    }

    public async Task<PagedResult<ProductListItemDto>> GetPagedAsync(ProductQueryParams query)
    {
        return await _productDAO.GetPagedAsync(query);
    }

    public async Task<PagedResult<ProductListItemDto>> GetAdminPagedAsync(AdminProductQueryParams query)
    {
        return await _productDAO.GetAdminPagedAsync(query);
    }

    public async Task<Product?> GetActiveByIdAsync(Guid id)
    {
        return await _productDAO.GetActiveByIdAsync(id);
    }

    public async Task<Product?> GetByIdWithDetailsAsync(Guid id, bool includeInactive = true)
    {
        return await _productDAO.GetByIdWithDetailsAsync(id, includeInactive);
    }

    public async Task<Product?> GetActiveBySlugAsync(string slug)
    {
        return await _productDAO.GetActiveBySlugAsync(slug);
    }

    public async Task<Product> CreateAsync(Product product, ProductVariant defaultVariant)
    {
        return await _productDAO.CreateAsync(product, defaultVariant);
    }

    public async Task UpdateAsync(Product product, ProductVariant? defaultVariant = null)
    {
        await _productDAO.UpdateAsync(product, defaultVariant);
    }

    public async Task<bool> SoftDeleteAsync(Guid id)
    {
        return await _productDAO.SoftDeleteAsync(id);
    }

    public async Task<bool> RestoreAsync(Guid id)
    {
        return await _productDAO.RestoreAsync(id);
    }

    public async Task<(double AverageRating, int ReviewCount)> GetRatingSummaryAsync(Guid productId)
    {
        return await _productDAO.GetRatingSummaryAsync(productId);
    }
}
