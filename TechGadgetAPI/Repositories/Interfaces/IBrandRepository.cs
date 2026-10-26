using BusinessObjects.Models;

namespace Repositories.Interfaces;

public interface IBrandRepository
{
    Task<List<Brand>> GetAllAsync();
}
