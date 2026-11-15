using BusinessObjects.DTOs;

namespace Services.Interfaces;

public interface IBrandService
{
    Task<List<BrandDto>> GetAllBrandsAsync();

    // Admin
    Task<List<AdminBrandDto>> GetAdminBrandsAsync();
    Task<AdminBrandDto> CreateBrandAsync(SaveBrandRequest request);
    Task<AdminBrandDto> UpdateBrandAsync(Guid id, SaveBrandRequest request);
    Task DeleteBrandAsync(Guid id);
}
