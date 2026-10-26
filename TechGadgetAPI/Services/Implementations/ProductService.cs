using System.Text.Json;
using BusinessObjects.DTOs;
using BusinessObjects.Models;
using Repositories.Interfaces;
using Services.Interfaces;

namespace Services.Implementations;

public class ProductService : IProductService
{
    private readonly IProductRepository _productRepository;

    public ProductService(IProductRepository productRepository)
    {
        _productRepository = productRepository;
    }

    public async Task<PagedResult<ProductListItemDto>> GetProductsAsync(ProductQueryParams query)
    {
        var result = await _productRepository.GetPagedAsync(query);
        foreach (var item in result.Items)
        {
            item.AverageRating = Math.Round(item.AverageRating, 1);
        }

        return result;
    }

    public async Task<ProductDetailDto?> GetProductByIdAsync(Guid id)
    {
        var product = await _productRepository.GetActiveByIdAsync(id);
        return product == null ? null : await MapToDetailDtoAsync(product);
    }

    public async Task<ProductDetailDto?> GetProductBySlugAsync(string slug)
    {
        var product = await _productRepository.GetActiveBySlugAsync(slug.Trim().ToLowerInvariant());
        return product == null ? null : await MapToDetailDtoAsync(product);
    }

    private async Task<ProductDetailDto> MapToDetailDtoAsync(Product product)
    {
        var (averageRating, reviewCount) = await _productRepository.GetRatingSummaryAsync(product.Id);
        var variants = product.ProductVariants.Select(v => MapToVariantDto(v, product.BasePrice)).ToList();

        return new ProductDetailDto
        {
            Id = product.Id,
            Name = product.Name,
            Slug = product.Slug,
            Description = product.Description,
            ThumbnailUrl = product.ThumbnailUrl,
            BasePrice = product.BasePrice,
            MinPrice = variants.Count > 0 ? variants.Min(v => v.FinalPrice) : product.BasePrice,
            MaxPrice = variants.Count > 0 ? variants.Max(v => v.FinalPrice) : product.BasePrice,
            InStock = variants.Any(v => v.InStock),
            Category = new CategorySummaryDto
            {
                Id = product.Category.Id,
                Name = product.Category.Name,
                Slug = product.Category.Slug
            },
            Brand = new BrandDto
            {
                Id = product.Brand.Id,
                Name = product.Brand.Name,
                LogoUrl = product.Brand.LogoUrl
            },
            AverageRating = Math.Round(averageRating, 1),
            ReviewCount = reviewCount,
            CreatedAt = product.CreatedAt,
            UpdatedAt = product.UpdatedAt,
            Variants = variants
        };
    }

    private static ProductVariantDto MapToVariantDto(ProductVariant variant, decimal basePrice)
    {
        using var attributes = JsonDocument.Parse(variant.Attributes);

        return new ProductVariantDto
        {
            Id = variant.Id,
            Sku = variant.Sku,
            Attributes = attributes.RootElement.Clone(),
            PriceAdjustment = variant.PriceAdjustment,
            FinalPrice = basePrice + variant.PriceAdjustment,
            StockQuantity = variant.StockQuantity,
            InStock = variant.StockQuantity > 0
        };
    }
}
