using BusinessObjects.DTOs;
using BusinessObjects.Models;
using Microsoft.EntityFrameworkCore;

namespace DataAccessObjects;

public class ProductDAO
{
    private readonly TechGadgetDbContext _context;

    public ProductDAO(TechGadgetDbContext context)
    {
        _context = context;
    }

    public async Task<PagedResult<ProductListItemDto>> GetPagedAsync(ProductQueryParams query)
    {
        var products = _context.Products
            .AsNoTracking()
            .Where(p => p.IsActive);

        if (query.CategoryIds is { Count: > 0 })
        {
            products = products.Where(p => query.CategoryIds.Contains(p.CategoryId));
        }

        if (query.BrandIds is { Count: > 0 })
        {
            products = products.Where(p => query.BrandIds.Contains(p.BrandId));
        }

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var pattern = $"%{EscapeLikePattern(query.Search.Trim())}%";
            products = products.Where(p => EF.Functions.ILike(p.Name, pattern, @"\"));
        }

        if (query.MinPrice.HasValue)
        {
            var minPrice = query.MinPrice.Value;
            products = products.Where(p =>
                p.BasePrice + (p.ProductVariants.Where(v => v.IsActive).Min(v => (decimal?)v.PriceAdjustment) ?? 0) >= minPrice);
        }

        if (query.MaxPrice.HasValue)
        {
            var maxPrice = query.MaxPrice.Value;
            products = products.Where(p =>
                p.BasePrice + (p.ProductVariants.Where(v => v.IsActive).Min(v => (decimal?)v.PriceAdjustment) ?? 0) <= maxPrice);
        }

        var totalCount = await products.CountAsync();

        products = query.SortBy switch
        {
            "price_asc" => products
                .OrderBy(p => p.BasePrice + (p.ProductVariants.Where(v => v.IsActive).Min(v => (decimal?)v.PriceAdjustment) ?? 0))
                .ThenBy(p => p.Id),
            "price_desc" => products
                .OrderByDescending(p => p.BasePrice + (p.ProductVariants.Where(v => v.IsActive).Min(v => (decimal?)v.PriceAdjustment) ?? 0))
                .ThenBy(p => p.Id),
            "name" => products.OrderBy(p => p.Name).ThenBy(p => p.Id),
            _ => products.OrderByDescending(p => p.CreatedAt).ThenBy(p => p.Id)
        };

        var items = await products
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .Select(p => new ProductListItemDto
            {
                Id = p.Id,
                Name = p.Name,
                Slug = p.Slug,
                ThumbnailUrl = p.ThumbnailUrl,
                BasePrice = p.BasePrice,
                DiscountPrice = p.DiscountPrice,
                MinPrice = p.BasePrice + (p.ProductVariants.Where(v => v.IsActive).Min(v => (decimal?)v.PriceAdjustment) ?? 0),
                MaxPrice = p.BasePrice + (p.ProductVariants.Where(v => v.IsActive).Max(v => (decimal?)v.PriceAdjustment) ?? 0),
                InStock = p.ProductVariants.Any(v => v.IsActive && v.StockQuantity > 0),
                TotalStockQuantity = p.ProductVariants.Where(v => v.IsActive).Sum(v => v.StockQuantity),
                IsActive = p.IsActive,
                CreatedAt = p.CreatedAt,
                Category = new CategorySummaryDto
                {
                    Id = p.Category.Id,
                    Name = p.Category.Name,
                    Slug = p.Category.Slug
                },
                Brand = new BrandDto
                {
                    Id = p.Brand.Id,
                    Name = p.Brand.Name,
                    LogoUrl = p.Brand.LogoUrl
                },
                AverageRating = p.Reviews.Average(r => (double?)r.Rating) ?? 0,
                ReviewCount = p.Reviews.Count()
            })
            .ToListAsync();

        return new PagedResult<ProductListItemDto>
        {
            Items = items,
            Page = query.Page,
            PageSize = query.PageSize,
            TotalCount = totalCount
        };
    }

    public async Task<PagedResult<ProductListItemDto>> GetAdminPagedAsync(AdminProductQueryParams query)
    {
        var products = _context.Products
            .AsNoTracking()
            .AsQueryable();

        if (query.IsActive.HasValue)
        {
            products = products.Where(p => p.IsActive == query.IsActive.Value);
        }

        if (query.CategoryId.HasValue && query.CategoryId.Value != Guid.Empty)
        {
            products = products.Where(p => p.CategoryId == query.CategoryId.Value);
        }

        if (query.BrandId.HasValue && query.BrandId.Value != Guid.Empty)
        {
            products = products.Where(p => p.BrandId == query.BrandId.Value);
        }

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var pattern = $"%{EscapeLikePattern(query.Search.Trim())}%";
            products = products.Where(p => EF.Functions.ILike(p.Name, pattern, @"\") || EF.Functions.ILike(p.Slug, pattern, @"\"));
        }

        var totalCount = await products.CountAsync();

        products = query.SortBy switch
        {
            "price_asc" => products.OrderBy(p => p.BasePrice).ThenBy(p => p.Id),
            "price_desc" => products.OrderByDescending(p => p.BasePrice).ThenBy(p => p.Id),
            "name" => products.OrderBy(p => p.Name).ThenBy(p => p.Id),
            _ => products.OrderByDescending(p => p.CreatedAt).ThenBy(p => p.Id)
        };

        var items = await products
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .Select(p => new ProductListItemDto
            {
                Id = p.Id,
                Name = p.Name,
                Slug = p.Slug,
                ThumbnailUrl = p.ThumbnailUrl,
                BasePrice = p.BasePrice,
                DiscountPrice = p.DiscountPrice,
                MinPrice = p.BasePrice + (p.ProductVariants.Min(v => (decimal?)v.PriceAdjustment) ?? 0),
                MaxPrice = p.BasePrice + (p.ProductVariants.Max(v => (decimal?)v.PriceAdjustment) ?? 0),
                InStock = p.ProductVariants.Any(v => v.StockQuantity > 0),
                TotalStockQuantity = p.ProductVariants.Sum(v => v.StockQuantity),
                IsActive = p.IsActive,
                CreatedAt = p.CreatedAt,
                Category = new CategorySummaryDto
                {
                    Id = p.Category.Id,
                    Name = p.Category.Name,
                    Slug = p.Category.Slug
                },
                Brand = new BrandDto
                {
                    Id = p.Brand.Id,
                    Name = p.Brand.Name,
                    LogoUrl = p.Brand.LogoUrl
                },
                AverageRating = p.Reviews.Average(r => (double?)r.Rating) ?? 0,
                ReviewCount = p.Reviews.Count()
            })
            .ToListAsync();

        return new PagedResult<ProductListItemDto>
        {
            Items = items,
            Page = query.Page,
            PageSize = query.PageSize,
            TotalCount = totalCount
        };
    }

    public async Task<Product> CreateAsync(Product product, ProductVariant defaultVariant)
    {
        _context.Products.Add(product);
        _context.ProductVariants.Add(defaultVariant);
        await _context.SaveChangesAsync();
        return product;
    }

    public async Task<Product?> GetActiveByIdAsync(Guid id)
    {
        return await QueryActiveWithDetails().FirstOrDefaultAsync(p => p.Id == id);
    }

    public async Task<Product?> GetByIdWithDetailsAsync(Guid id, bool includeInactive = true)
    {
        var query = _context.Products
            .Include(p => p.Category)
            .Include(p => p.Brand)
            .Include(p => p.ProductVariants)
            .AsQueryable();

        if (!includeInactive)
        {
            query = query.Where(p => p.IsActive);
        }

        return await query.FirstOrDefaultAsync(p => p.Id == id);
    }

    public async Task<Product?> GetActiveBySlugAsync(string slug)
    {
        return await QueryActiveWithDetails().FirstOrDefaultAsync(p => p.Slug == slug);
    }

    public async Task UpdateAsync(Product product, ProductVariant? defaultVariant = null)
    {
        _context.Products.Update(product);
        if (defaultVariant != null)
        {
            if (_context.Entry(defaultVariant).State == EntityState.Detached)
            {
                _context.ProductVariants.Update(defaultVariant);
            }
        }
        await _context.SaveChangesAsync();
    }

    public async Task<bool> SoftDeleteAsync(Guid id)
    {
        var product = await _context.Products.Include(p => p.ProductVariants).FirstOrDefaultAsync(p => p.Id == id);
        if (product == null) return false;

        product.IsActive = false;
        product.UpdatedAt = DateTimeOffset.UtcNow;
        foreach (var variant in product.ProductVariants)
        {
            variant.IsActive = false;
            variant.UpdatedAt = DateTimeOffset.UtcNow;
        }

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> RestoreAsync(Guid id)
    {
        var product = await _context.Products.Include(p => p.ProductVariants).FirstOrDefaultAsync(p => p.Id == id);
        if (product == null) return false;

        product.IsActive = true;
        product.UpdatedAt = DateTimeOffset.UtcNow;
        foreach (var variant in product.ProductVariants)
        {
            variant.IsActive = true;
            variant.UpdatedAt = DateTimeOffset.UtcNow;
        }

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<(double AverageRating, int ReviewCount)> GetRatingSummaryAsync(Guid productId)
    {
        var summary = await _context.Reviews
            .AsNoTracking()
            .Where(r => r.ProductId == productId)
            .GroupBy(r => r.ProductId)
            .Select(g => new { Average = g.Average(r => (double)r.Rating), Count = g.Count() })
            .FirstOrDefaultAsync();

        return summary == null ? (0, 0) : (summary.Average, summary.Count);
    }

    private IQueryable<Product> QueryActiveWithDetails()
    {
        return _context.Products
            .AsNoTracking()
            .Include(p => p.Category)
            .Include(p => p.Brand)
            .Include(p => p.ProductVariants
                .Where(v => v.IsActive)
                .OrderBy(v => v.PriceAdjustment)
                .ThenBy(v => v.Sku))
            .Where(p => p.IsActive);
    }

    private static string EscapeLikePattern(string value)
    {
        return value
            .Replace(@"\", @"\\")
            .Replace("%", @"\%")
            .Replace("_", @"\_");
    }
}
