using BusinessObjects.Models;
using DataAccessObjects;
using Repositories.Interfaces;

namespace Repositories.Implementations;

public class ProfileRepository : IProfileRepository
{
    private readonly ProfileDAO _profileDAO;

    public ProfileRepository(ProfileDAO profileDAO)
    {
        _profileDAO = profileDAO;
    }

    public async Task<Profile?> GetByIdAsync(Guid id)
    {
        return await _profileDAO.GetByIdAsync(id);
    }

    public async Task<Profile?> UpdateAsync(Guid id, string? fullName, string? avatarUrl, string? phone)
    {
        return await _profileDAO.UpdateAsync(id, fullName, avatarUrl, phone);
    }
}
