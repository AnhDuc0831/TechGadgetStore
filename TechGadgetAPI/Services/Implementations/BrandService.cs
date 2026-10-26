using BusinessObjects.DTOs;
using Repositories.Interfaces;
using Services.Interfaces;

namespace Services.Implementations;

public class BrandService : IBrandService
{
    private readonly IBrandRepository _brandRepository;

    public BrandService(IBrandRepository brandRepository)
    {
        _brandRepository = brandRepository;
    }

    public async Task<List<BrandDto>> GetAllBrandsAsync()
    {
        var brands = await _brandRepository.GetAllAsync();
        return brands.Select(b => new BrandDto
        {
            Id = b.Id,
            Name = b.Name,
            LogoUrl = b.LogoUrl
        }).ToList();
    }
}
