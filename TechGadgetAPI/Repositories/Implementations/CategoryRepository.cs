using BusinessObjects.Models;
using DataAccessObjects;
using Repositories.Interfaces;

namespace Repositories.Implementations;

/// <summary>
/// Repository danh mục – đi qua CategoryDAO (trước đây gọi thẳng DbContext, chưa đúng kiến trúc 5 lớp).
/// </summary>
public class CategoryRepository : ICategoryRepository
{
    private readonly CategoryDAO _categoryDao;

    public CategoryRepository(CategoryDAO categoryDao)
    {
        _categoryDao = categoryDao;
    }

    public Task<List<Category>> GetAllCategoriesAsync() => _categoryDao.GetAllAsync();

    public Task<List<(Category Category, int ProductCount)>> GetAllWithProductCountAsync() =>
        _categoryDao.GetAllWithProductCountAsync();

    public Task<Category?> GetByIdAsync(Guid id) => _categoryDao.GetByIdAsync(id);

    public Task<int> CountProductsAsync(Guid categoryId) => _categoryDao.CountProductsAsync(categoryId);

    public Task<bool> SlugExistsAsync(string slug, Guid? excludeId = null) => _categoryDao.SlugExistsAsync(slug, excludeId);

    public Task<bool> NameExistsAsync(string name, Guid? excludeId = null) => _categoryDao.NameExistsAsync(name, excludeId);

    public Task<Category> AddAsync(Category category) => _categoryDao.AddAsync(category);

    public Task UpdateAsync(Category category) => _categoryDao.UpdateAsync(category);

    public Task DeleteAsync(Category category) => _categoryDao.DeleteAsync(category);
}
