using BusinessObjects.DTOs;

namespace Services.Interfaces;

public interface ICategoryService
{
    Task<List<CategoryDto>> GetAllCategoriesAsync();

    // Admin
    Task<List<AdminCategoryDto>> GetAdminCategoriesAsync();
    Task<AdminCategoryDto> CreateCategoryAsync(SaveCategoryRequest request);
    Task<AdminCategoryDto> UpdateCategoryAsync(Guid id, SaveCategoryRequest request);
    Task DeleteCategoryAsync(Guid id);
}
