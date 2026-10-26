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

    public async Task<Product?> GetActiveByIdAsync(Guid id)
    {
        return await _productDAO.GetActiveByIdAsync(id);
    }

    public async Task<Product?> GetActiveBySlugAsync(string slug)
    {
        return await _productDAO.GetActiveBySlugAsync(slug);
    }

    public async Task<(double AverageRating, int ReviewCount)> GetRatingSummaryAsync(Guid productId)
    {
        return await _productDAO.GetRatingSummaryAsync(productId);
    }
}
