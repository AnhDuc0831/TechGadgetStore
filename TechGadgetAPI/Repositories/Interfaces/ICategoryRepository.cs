using BusinessObjects.Models;

namespace Repositories.Interfaces;

public interface ICategoryRepository
{
    Task<List<Category>> GetAllCategoriesAsync();
}
