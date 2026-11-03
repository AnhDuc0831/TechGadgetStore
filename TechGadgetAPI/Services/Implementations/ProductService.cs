using System.Text.Json;
using System.Text.RegularExpressions;
using BusinessObjects.DTOs;
using BusinessObjects.Models;
using Repositories.Interfaces;
using Services.Interfaces;

namespace Services.Implementations;

public class ProductService : IProductService
{
    private readonly IProductRepository _productRepository;
    private readonly ICloudinaryService _cloudinaryService;

    public ProductService(
        IProductRepository productRepository,
        ICloudinaryService cloudinaryService)
    {
        _productRepository = productRepository;
        _cloudinaryService = cloudinaryService;
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

    public async Task<PagedResult<ProductListItemDto>> GetAdminProductsAsync(AdminProductQueryParams query)
    {
        var result = await _productRepository.GetAdminPagedAsync(query);
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

    public async Task<ProductDetailDto?> GetAdminProductByIdAsync(Guid id)
    {
        var product = await _productRepository.GetByIdWithDetailsAsync(id, includeInactive: true);
        return product == null ? null : await MapToDetailDtoAsync(product);
    }

    public async Task<ProductDetailDto?> GetProductBySlugAsync(string slug)
    {
        var product = await _productRepository.GetActiveBySlugAsync(slug.Trim().ToLowerInvariant());
        return product == null ? null : await MapToDetailDtoAsync(product);
    }

    public async Task<ProductDetailDto> CreateProductAsync(CreateProductRequest request)
    {
        var uploadedUrls = new List<string>();

        // 1. Upload ảnh lên Cloudinary nếu có files
        if (request.ImageFiles != null && request.ImageFiles.Count > 0)
        {
            var validFiles = request.ImageFiles.Where(f => f.Length > 0);
            var cloudinaryUrls = await _cloudinaryService.UploadImagesAsync(validFiles);
            uploadedUrls.AddRange(cloudinaryUrls);
        }

        // 2. Thêm các URL ảnh truyền trực tiếp nếu có
        if (request.ImageUrls != null && request.ImageUrls.Count > 0)
        {
            uploadedUrls.AddRange(request.ImageUrls.Where(u => !string.IsNullOrWhiteSpace(u)));
        }

        // 3. Tự sinh Slug thân thiện từ Tên sản phẩm
        var cleanName = Regex.Replace(request.Name.ToLowerInvariant().Trim(), @"[^a-z0-9\s-]", "");
        cleanName = Regex.Replace(cleanName, @"\s+", "-").Trim('-');
        var uniqueSlug = $"{cleanName}-{Guid.NewGuid().ToString()[..8]}";

        var product = new Product
        {
            Id = Guid.NewGuid(),
            CategoryId = request.CategoryId,
            BrandId = request.BrandId,
            Name = request.Name.Trim(),
            Slug = uniqueSlug,
            Description = request.Description?.Trim(),
            BasePrice = request.BasePrice,
            DiscountPrice = request.DiscountPrice,
            ThumbnailUrl = uploadedUrls.FirstOrDefault(),
            Images = uploadedUrls,
            Specifications = string.IsNullOrWhiteSpace(request.Specifications) ? "{}" : request.Specifications.Trim(),
            IsActive = request.IsActive,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        };

        var variant = new ProductVariant
        {
            Id = Guid.NewGuid(),
            ProductId = product.Id,
            Sku = string.IsNullOrWhiteSpace(request.Sku)
                ? $"SKU-{Guid.NewGuid().ToString()[..6].ToUpper()}"
                : request.Sku.Trim(),
            Attributes = "{}",
            StockQuantity = request.StockQuantity,
            PriceAdjustment = 0,
            CostPrice = request.BasePrice,
            IsActive = true,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        };

        await _productRepository.CreateAsync(product, variant);

        var created = await _productRepository.GetByIdWithDetailsAsync(product.Id, includeInactive: true);
        return await MapToDetailDtoAsync(created ?? product);
    }

    public async Task<ProductDetailDto> UpdateProductAsync(Guid id, UpdateProductRequest request)
    {
        var product = await _productRepository.GetByIdWithDetailsAsync(id, includeInactive: true);
        if (product == null)
        {
            throw new KeyNotFoundException($"Không tìm thấy sản phẩm có mã {id}.");
        }

        var finalImages = new List<string>();

        // 1. Giữ lại các ảnh cũ được gửi lên
        if (request.ExistingImages != null && request.ExistingImages.Count > 0)
        {
            finalImages.AddRange(request.ExistingImages.Where(u => !string.IsNullOrWhiteSpace(u)));
        }

        // 2. Upload các file ảnh mới nếu có
        if (request.NewImageFiles != null && request.NewImageFiles.Count > 0)
        {
            var validFiles = request.NewImageFiles.Where(f => f.Length > 0);
            var cloudinaryUrls = await _cloudinaryService.UploadImagesAsync(validFiles);
            finalImages.AddRange(cloudinaryUrls);
        }

        // Nếu người dùng không gửi ExistingImages và cũng không gửi NewImageFiles, giữ nguyên ảnh hiện tại
        if (finalImages.Count == 0 && product.Images != null && product.Images.Count > 0)
        {
            finalImages = product.Images;
        }

        product.Name = request.Name.Trim();
        product.CategoryId = request.CategoryId;
        product.BrandId = request.BrandId;
        product.Description = request.Description?.Trim();
        product.BasePrice = request.BasePrice;
        product.DiscountPrice = request.DiscountPrice;
        product.Specifications = string.IsNullOrWhiteSpace(request.Specifications) ? "{}" : request.Specifications.Trim();
        product.IsActive = request.IsActive;
        product.Images = finalImages;
        product.ThumbnailUrl = finalImages.FirstOrDefault() ?? product.ThumbnailUrl;
        product.UpdatedAt = DateTimeOffset.UtcNow;

        // Cập nhật variant mặc định
        ProductVariant? defaultVariant = product.ProductVariants.FirstOrDefault();
        if (defaultVariant != null)
        {
            defaultVariant.StockQuantity = request.StockQuantity;
            if (!string.IsNullOrWhiteSpace(request.Sku))
            {
                defaultVariant.Sku = request.Sku.Trim();
            }
            defaultVariant.CostPrice = request.BasePrice;
            defaultVariant.IsActive = request.IsActive;
            defaultVariant.UpdatedAt = DateTimeOffset.UtcNow;
        }
        else
        {
            defaultVariant = new ProductVariant
            {
                Id = Guid.NewGuid(),
                ProductId = product.Id,
                Sku = string.IsNullOrWhiteSpace(request.Sku)
                    ? $"SKU-{Guid.NewGuid().ToString()[..6].ToUpper()}"
                    : request.Sku.Trim(),
                Attributes = "{}",
                StockQuantity = request.StockQuantity,
                PriceAdjustment = 0,
                CostPrice = request.BasePrice,
                IsActive = request.IsActive,
                CreatedAt = DateTimeOffset.UtcNow,
                UpdatedAt = DateTimeOffset.UtcNow
            };
            product.ProductVariants.Add(defaultVariant);
        }

        await _productRepository.UpdateAsync(product, defaultVariant);

        var updated = await _productRepository.GetByIdWithDetailsAsync(product.Id, includeInactive: true);
        return await MapToDetailDtoAsync(updated ?? product);
    }

    public async Task<bool> SoftDeleteProductAsync(Guid id)
    {
        return await _productRepository.SoftDeleteAsync(id);
    }

    public async Task<bool> RestoreProductAsync(Guid id)
    {
        return await _productRepository.RestoreAsync(id);
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
            Images = product.Images ?? new List<string>(),
            DiscountPrice = product.DiscountPrice,
            Specifications = product.Specifications ?? "{}",
            BasePrice = product.BasePrice,
            MinPrice = variants.Count > 0 ? variants.Min(v => v.FinalPrice) : product.BasePrice,
            MaxPrice = variants.Count > 0 ? variants.Max(v => v.FinalPrice) : product.BasePrice,
            InStock = variants.Any(v => v.InStock),
            Category = product.Category != null ? new CategorySummaryDto
            {
                Id = product.Category.Id,
                Name = product.Category.Name,
                Slug = product.Category.Slug
            } : new CategorySummaryDto { Id = product.CategoryId, Name = string.Empty, Slug = string.Empty },
            Brand = product.Brand != null ? new BrandDto
            {
                Id = product.Brand.Id,
                Name = product.Brand.Name,
                LogoUrl = product.Brand.LogoUrl
            } : new BrandDto { Id = product.BrandId, Name = string.Empty },
            AverageRating = Math.Round(averageRating, 1),
            ReviewCount = reviewCount,
            CreatedAt = product.CreatedAt,
            UpdatedAt = product.UpdatedAt,
            Variants = variants
        };
    }

    private static ProductVariantDto MapToVariantDto(ProductVariant variant, decimal basePrice)
    {
        using var attributes = JsonDocument.Parse(string.IsNullOrWhiteSpace(variant.Attributes) ? "{}" : variant.Attributes);

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
