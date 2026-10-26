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
}
