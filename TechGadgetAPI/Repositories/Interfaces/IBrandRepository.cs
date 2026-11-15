using BusinessObjects.Models;

namespace Repositories.Interfaces;

public interface IBrandRepository
{
    Task<List<Brand>> GetAllAsync();

    // Admin
    Task<List<(Brand Brand, int ProductCount)>> GetAllWithProductCountAsync();
    Task<Brand?> GetByIdAsync(Guid id);
    Task<int> CountProductsAsync(Guid brandId);
    Task<bool> NameExistsAsync(string name, Guid? excludeId = null);
    Task<Brand> AddAsync(Brand brand);
    Task UpdateAsync(Brand brand);
    Task DeleteAsync(Brand brand);
}
