using BusinessObjects.Models;

namespace Repositories.Interfaces;

public interface IProfileRepository
{
    Task<Profile?> GetByIdAsync(Guid id);
    Task<Profile?> UpdateAsync(Guid id, string? fullName, string? avatarUrl, string? phone);
}
