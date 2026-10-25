using BusinessObjects.DTOs;
using BusinessObjects.Models;
using Repositories.Interfaces;
using Services.Interfaces;

namespace Services.Implementations;

public class ProfileService : IProfileService
{
    private readonly IProfileRepository _profileRepository;

    public ProfileService(IProfileRepository profileRepository)
    {
        _profileRepository = profileRepository;
    }

    public async Task<ProfileResponseDto?> GetProfileByIdAsync(Guid id)
    {
        var profile = await _profileRepository.GetByIdAsync(id);
        return profile == null ? null : MapToDto(profile);
    }

    public async Task<ProfileResponseDto?> UpdateProfileAsync(Guid id, UpdateProfileRequestDto request)
    {
        var updatedProfile = await _profileRepository.UpdateAsync(
            id,
            request.FullName?.Trim(),
            request.AvatarUrl?.Trim(),
            request.Phone?.Trim()
        );

        return updatedProfile == null ? null : MapToDto(updatedProfile);
    }

    private static ProfileResponseDto MapToDto(Profile profile)
    {
        return new ProfileResponseDto
        {
            Id = profile.Id,
            FullName = profile.FullName,
            AvatarUrl = profile.AvatarUrl,
            Phone = profile.Phone,
            Role = profile.Role.ToString().ToLowerInvariant(),
            CreatedAt = profile.CreatedAt,
            UpdatedAt = profile.UpdatedAt
        };
    }
}
