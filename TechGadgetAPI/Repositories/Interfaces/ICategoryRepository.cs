using BusinessObjects.Models;

namespace Repositories.Interfaces;

public interface ICategoryRepository
{
    Task<List<Category>> GetAllCategoriesAsync();

    // Admin
    Task<List<(Category Category, int ProductCount)>> GetAllWithProductCountAsync();
    Task<Category?> GetByIdAsync(Guid id);
    Task<int> CountProductsAsync(Guid categoryId);
    Task<bool> SlugExistsAsync(string slug, Guid? excludeId = null);
    Task<bool> NameExistsAsync(string name, Guid? excludeId = null);
    Task<Category> AddAsync(Category category);
    Task UpdateAsync(Category category);
    Task DeleteAsync(Category category);
}
