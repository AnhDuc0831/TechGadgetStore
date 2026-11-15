using BusinessObjects.Models;
using Microsoft.EntityFrameworkCore;

namespace DataAccessObjects;

public class BrandDAO
{
    private readonly TechGadgetDbContext _context;

    public BrandDAO(TechGadgetDbContext context)
    {
        _context = context;
    }

    public async Task<List<Brand>> GetAllAsync()
    {
        return await _context.Brands
            .AsNoTracking()
            .OrderBy(b => b.Name)
            .ToListAsync();
    }

    /// <summary>Danh sách thương hiệu kèm số sản phẩm (cho Admin).</summary>
    public async Task<List<(Brand Brand, int ProductCount)>> GetAllWithProductCountAsync()
    {
        var rows = await _context.Brands
            .AsNoTracking()
            .OrderBy(b => b.Name)
            .Select(b => new { Brand = b, Count = b.Products.Count() })
            .ToListAsync();
        return rows.Select(r => (r.Brand, r.Count)).ToList();
    }

    public Task<Brand?> GetByIdAsync(Guid id) =>
        _context.Brands.FirstOrDefaultAsync(b => b.Id == id);

    public Task<int> CountProductsAsync(Guid brandId) =>
        _context.Products.CountAsync(p => p.BrandId == brandId);

    public Task<bool> NameExistsAsync(string name, Guid? excludeId = null) =>
        _context.Brands.AnyAsync(b => b.Name.ToLower() == name.ToLower() && (excludeId == null || b.Id != excludeId));

    public async Task<Brand> AddAsync(Brand brand)
    {
        _context.Brands.Add(brand);
        await _context.SaveChangesAsync();
        return brand;
    }

    public async Task UpdateAsync(Brand brand)
    {
        brand.UpdatedAt = DateTimeOffset.UtcNow;
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Brand brand)
    {
        _context.Brands.Remove(brand);
        await _context.SaveChangesAsync();
    }
}
