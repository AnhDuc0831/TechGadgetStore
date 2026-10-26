using BusinessObjects.DTOs;

namespace Services.Interfaces;

public interface IBrandService
{
    Task<List<BrandDto>> GetAllBrandsAsync();
}
