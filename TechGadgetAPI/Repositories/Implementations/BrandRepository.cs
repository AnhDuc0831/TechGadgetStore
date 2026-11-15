using BusinessObjects.Models;
using DataAccessObjects;
using Repositories.Interfaces;

namespace Repositories.Implementations;

public class BrandRepository : IBrandRepository
{
    private readonly BrandDAO _brandDAO;

    public BrandRepository(BrandDAO brandDAO)
    {
        _brandDAO = brandDAO;
    }

    public async Task<List<Brand>> GetAllAsync()
    {
        return await _brandDAO.GetAllAsync();
    }

    public Task<List<(Brand Brand, int ProductCount)>> GetAllWithProductCountAsync() =>
        _brandDAO.GetAllWithProductCountAsync();

    public Task<Brand?> GetByIdAsync(Guid id) => _brandDAO.GetByIdAsync(id);

    public Task<int> CountProductsAsync(Guid brandId) => _brandDAO.CountProductsAsync(brandId);

    public Task<bool> NameExistsAsync(string name, Guid? excludeId = null) => _brandDAO.NameExistsAsync(name, excludeId);

    public Task<Brand> AddAsync(Brand brand) => _brandDAO.AddAsync(brand);

    public Task UpdateAsync(Brand brand) => _brandDAO.UpdateAsync(brand);

    public Task DeleteAsync(Brand brand) => _brandDAO.DeleteAsync(brand);
}
