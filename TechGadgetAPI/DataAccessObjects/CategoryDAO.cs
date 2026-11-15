using BusinessObjects.Models;
using Microsoft.EntityFrameworkCore;

namespace DataAccessObjects;

public class CategoryDAO
{
    private readonly TechGadgetDbContext _context;

    public CategoryDAO(TechGadgetDbContext context)
    {
        _context = context;
    }

    public Task<List<Category>> GetAllAsync() =>
        _context.Categories.AsNoTracking().ToListAsync();

    /// <summary>Danh sách danh mục kèm số sản phẩm (cho Admin).</summary>
    public async Task<List<(Category Category, int ProductCount)>> GetAllWithProductCountAsync()
    {
        var rows = await _context.Categories
            .AsNoTracking()
            .OrderBy(c => c.Name)
            .Select(c => new { Category = c, Count = c.Products.Count() })
            .ToListAsync();
        return rows.Select(r => (r.Category, r.Count)).ToList();
    }

    public Task<Category?> GetByIdAsync(Guid id) =>
        _context.Categories.FirstOrDefaultAsync(c => c.Id == id);

    public Task<int> CountProductsAsync(Guid categoryId) =>
        _context.Products.CountAsync(p => p.CategoryId == categoryId);

    public Task<bool> SlugExistsAsync(string slug, Guid? excludeId = null) =>
        _context.Categories.AnyAsync(c => c.Slug == slug && (excludeId == null || c.Id != excludeId));

    public Task<bool> NameExistsAsync(string name, Guid? excludeId = null) =>
        _context.Categories.AnyAsync(c => c.Name.ToLower() == name.ToLower() && (excludeId == null || c.Id != excludeId));

    public async Task<Category> AddAsync(Category category)
    {
        _context.Categories.Add(category);
        await _context.SaveChangesAsync();
        return category;
    }

    public async Task UpdateAsync(Category category)
    {
        category.UpdatedAt = DateTimeOffset.UtcNow;
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Category category)
    {
        _context.Categories.Remove(category);
        await _context.SaveChangesAsync();
    }
}
