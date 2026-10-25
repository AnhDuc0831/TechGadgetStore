using BusinessObjects.Models;

namespace Services.Interfaces;

public interface ICategoryService
{
    Task<List<Category>> GetAllCategoriesAsync();
}
