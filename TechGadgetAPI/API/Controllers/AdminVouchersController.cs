using BusinessObjects.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;
using System.Security.Claims;

namespace API.Controllers;

/// <summary>
/// Admin: Quản lý voucher (tạo, sửa, bật/tắt, xóa).
/// </summary>
[ApiController]
[Authorize]
[Route("api/admin/vouchers")]
public class AdminVouchersController : ControllerBase
{
    private readonly IVoucherService _voucherService;
    private readonly IProfileService _profileService;
    private readonly ILogger<AdminVouchersController> _logger;

    public AdminVouchersController(
        IVoucherService voucherService,
        IProfileService profileService,
        ILogger<AdminVouchersController> logger)
    {
        _voucherService = voucherService;
        _profileService = profileService;
        _logger = logger;
    }

    private async Task<(bool IsAdmin, IActionResult? ErrorResult)> VerifyAdminAsync()
    {
        var userIdClaim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (!Guid.TryParse(userIdClaim, out var userId))
        {
            return (false, Unauthorized());
        }

        var profile = await _profileService.GetProfileByIdAsync(userId);
        if (profile == null || !string.Equals(profile.Role, "admin", StringComparison.OrdinalIgnoreCase))
        {
            return (false, StatusCode(StatusCodes.Status403Forbidden, new
            {
                message = "Chỉ tài khoản Quản trị viên (Admin) mới có quyền quản lý voucher."
            }));
        }

        return (true, null);
    }

    /// <summary>
    /// Admin: Danh sách voucher có phân trang, tìm theo mã/tên, lọc theo trạng thái (running | upcoming | expired | disabled).
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<AdminVoucherDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetVouchers([FromQuery] AdminVoucherQueryParams query)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        return Ok(await _voucherService.GetAdminVouchersAsync(query));
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(AdminVoucherDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetVoucher(Guid id)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        return await ExecuteAsync(() => _voucherService.GetAdminVoucherByIdAsync(id));
    }

    /// <summary>
    /// Admin: Tạo và đăng voucher mới.
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(AdminVoucherDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> CreateVoucher([FromBody] CreateVoucherRequest request)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;
        if (!ModelState.IsValid) return BadRequest(ModelState);

        return await ExecuteAsync(() => _voucherService.CreateVoucherAsync(request));
    }

    /// <summary>
    /// Admin: Cập nhật voucher. Nếu đã có khách lưu, chỉ được sửa tên, mô tả, thời gian, số lượng, trạng thái.
    /// </summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(AdminVoucherDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateVoucher(Guid id, [FromBody] UpdateVoucherRequest request)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;
        if (!ModelState.IsValid) return BadRequest(ModelState);

        return await ExecuteAsync(() => _voucherService.UpdateVoucherAsync(id, request));
    }

    /// <summary>
    /// Admin: Bật / tắt voucher.
    /// </summary>
    [HttpPatch("{id:guid}/toggle")]
    [ProducesResponseType(typeof(AdminVoucherDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ToggleVoucher(Guid id)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        return await ExecuteAsync(() => _voucherService.ToggleVoucherAsync(id));
    }

    /// <summary>
    /// Admin: Xóa voucher (chỉ khi chưa có khách nào lưu).
    /// </summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteVoucher(Guid id)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        return await ExecuteAsync(async () =>
        {
            await _voucherService.DeleteVoucherAsync(id);
            return new { message = "Đã xóa voucher." };
        });
    }

    private async Task<IActionResult> ExecuteAsync<T>(Func<Task<T>> action)
    {
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
            _logger.LogError(ex, "Lỗi khi xử lý voucher (admin)");
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "Đã xảy ra lỗi khi xử lý voucher." });
        }
    }
}
