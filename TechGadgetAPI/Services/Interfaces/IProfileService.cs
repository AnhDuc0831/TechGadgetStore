using BusinessObjects.DTOs;

namespace Services.Interfaces;

public interface IProfileService
{
    Task<ProfileResponseDto?> GetProfileByIdAsync(Guid id);
    Task<ProfileResponseDto?> UpdateProfileAsync(Guid id, UpdateProfileRequestDto request);
}
