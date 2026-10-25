using BusinessObjects.Models;
using DataAccessObjects;
using Microsoft.EntityFrameworkCore;
using Repositories.Interfaces;

namespace Repositories.Implementations;

public class CategoryRepository : ICategoryRepository
{
    private readonly TechGadgetDbContext _context;

    public CategoryRepository(TechGadgetDbContext context)
    {
        _context = context;
    }

    public async Task<List<Category>> GetAllCategoriesAsync()
    {
        return await _context.Categories.AsNoTracking().ToListAsync();
    }
}
