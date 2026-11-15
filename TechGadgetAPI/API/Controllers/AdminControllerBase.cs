using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;
using System.Security.Claims;

namespace API.Controllers;

/// <summary>
/// Lớp cơ sở cho các controller Admin: kiểm tra quyền Admin (role trong bảng profiles)
/// và chuyển exception nghiệp vụ thành HTTP status thống nhất.
/// </summary>
[ApiController]
[Authorize]
public abstract class AdminControllerBase : ControllerBase
{
    protected readonly IProfileService ProfileService;
    protected readonly ILogger Logger;

    protected AdminControllerBase(IProfileService profileService, ILogger logger)
    {
        ProfileService = profileService;
        Logger = logger;
    }

    protected Guid? CurrentUserId
    {
        get
        {
            var sub = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
            return Guid.TryParse(sub, out var id) ? id : null;
        }
    }

    /// <summary>Trả về null nếu là Admin, ngược lại trả về 401/403.</summary>
    protected async Task<IActionResult?> EnsureAdminAsync()
    {
        if (CurrentUserId is not { } userId)
        {
            return Unauthorized();
        }

        var profile = await ProfileService.GetProfileByIdAsync(userId);
        if (profile == null || !string.Equals(profile.Role, "admin", StringComparison.OrdinalIgnoreCase))
        {
            return StatusCode(StatusCodes.Status403Forbidden, new
            {
                message = "Chỉ tài khoản Quản trị viên (Admin) mới có quyền thực hiện thao tác này."
            });
        }

        return null;
    }

    /// <summary>Kiểm tra quyền Admin rồi chạy action, map exception → 400/404/500.</summary>
    protected async Task<IActionResult> AdminActionAsync<T>(Func<Task<T>> action, string errorLogMessage)
    {
        var denied = await EnsureAdminAsync();
        if (denied != null) return denied;

        try
        {
            return Ok(await action());
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            Logger.LogError(ex, "{Message}", errorLogMessage);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = errorLogMessage });
        }
    }
}
