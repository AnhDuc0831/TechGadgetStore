using System.Security.Claims;
using BusinessObjects.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;

namespace API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ProfilesController : ControllerBase
{
    private readonly IProfileService _profileService;
    private readonly ILogger<ProfilesController> _logger;

    public ProfilesController(IProfileService profileService, ILogger<ProfilesController> logger)
    {
        _profileService = profileService;
        _logger = logger;
    }

    /// <summary>
    /// Lấy thông tin Profile của người dùng hiện tại đang đăng nhập qua JWT Token.
    /// </summary>
    [HttpGet("me")]
    [ProducesResponseType(typeof(ProfileResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetMyProfile()
    {
        var userId = GetCurrentUserId();
        if (userId == null)
        {
            return Unauthorized(new { message = "Invalid user token: Subject (sub) claim is missing or invalid." });
        }

        var profile = await _profileService.GetProfileByIdAsync(userId.Value);
        if (profile == null)
        {
            return NotFound(new { message = $"Profile for user ID {userId} was not found." });
        }

        return Ok(profile);
    }

    /// <summary>
    /// Cập nhật thông tin Profile (họ tên, ảnh đại diện, số điện thoại) của người dùng hiện tại.
    /// </summary>
    [HttpPut("me")]
    [ProducesResponseType(typeof(ProfileResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateMyProfile([FromBody] UpdateProfileRequestDto request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var userId = GetCurrentUserId();
        if (userId == null)
        {
            return Unauthorized(new { message = "Invalid user token: Subject (sub) claim is missing or invalid." });
        }

        var updatedProfile = await _profileService.UpdateProfileAsync(userId.Value, request);
        if (updatedProfile == null)
        {
            return NotFound(new { message = $"Profile for user ID {userId} was not found." });
        }

        _logger.LogInformation("Profile updated for user {UserId}", userId);
        return Ok(updatedProfile);
    }

    /// <summary>
    /// Lấy thông tin Profile theo User ID (Guid).
    /// </summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(ProfileResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetProfileById(Guid id)
    {
        var profile = await _profileService.GetProfileByIdAsync(id);
        if (profile == null)
        {
            return NotFound(new { message = $"Profile with ID {id} was not found." });
        }

        return Ok(profile);
    }

    private Guid? GetCurrentUserId()
    {
        var claimValue = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                      ?? User.FindFirst("sub")?.Value;

        return Guid.TryParse(claimValue, out var guid) ? guid : null;
    }
}
