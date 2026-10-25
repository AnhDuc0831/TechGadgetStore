using BusinessObjects.Models;
using Microsoft.EntityFrameworkCore;

namespace DataAccessObjects;

public class ProfileDAO
{
    private readonly TechGadgetDbContext _context;

    public ProfileDAO(TechGadgetDbContext context)
    {
        _context = context;
    }

    public async Task<Profile?> GetByIdAsync(Guid id)
    {
        return await _context.Profiles
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == id);
    }

    public async Task<Profile?> UpdateAsync(Guid id, string? fullName, string? avatarUrl, string? phone)
    {
        var profile = await _context.Profiles.FirstOrDefaultAsync(p => p.Id == id);
        if (profile == null)
        {
            return null;
        }

        if (fullName != null) profile.FullName = fullName;
        if (avatarUrl != null) profile.AvatarUrl = avatarUrl;
        if (phone != null) profile.Phone = phone;
        profile.UpdatedAt = DateTimeOffset.UtcNow;

        await _context.SaveChangesAsync();
        return profile;
    }
}
