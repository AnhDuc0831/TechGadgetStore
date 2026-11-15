using BusinessObjects.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;
using System.Security.Claims;

namespace API.Controllers;

/// <summary>
/// Voucher phía khách hàng: Kho voucher, lưu voucher vào ví, xem ví voucher.
/// </summary>
[ApiController]
[Authorize]
[Route("api/vouchers")]
public class VouchersController : ControllerBase
{
    private readonly IVoucherService _voucherService;
    private readonly ILogger<VouchersController> _logger;

    public VouchersController(IVoucherService voucherService, ILogger<VouchersController> logger)
    {
        _voucherService = voucherService;
        _logger = logger;
    }

    private Guid? CurrentUserId
    {
        get
        {
            var sub = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
            return Guid.TryParse(sub, out var id) ? id : null;
        }
    }

    /// <summary>
    /// Kho voucher: danh sách voucher công khai còn hiệu lực, kèm số suất còn lại và trạng thái đã lưu của người dùng.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(List<PublicVoucherDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPublicVouchers()
    {
        if (CurrentUserId is not { } userId) return Unauthorized();
        return Ok(await _voucherService.GetPublicVouchersAsync(userId));
    }

    /// <summary>
    /// Ví voucher của tôi. Truyền ?subtotal=... (tiền hàng) để server tính sẵn voucher nào dùng được và giảm bao nhiêu.
    /// </summary>
    [HttpGet("my")]
    [ProducesResponseType(typeof(List<MyVoucherDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetMyVouchers([FromQuery] decimal? subtotal)
    {
        if (CurrentUserId is not { } userId) return Unauthorized();
        return Ok(await _voucherService.GetMyVouchersAsync(userId, subtotal));
    }

    /// <summary>
    /// Lưu voucher (từ Kho voucher) vào ví.
    /// </summary>
    [HttpPost("{id:guid}/claim")]
    [ProducesResponseType(typeof(MyVoucherDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public Task<IActionResult> Claim(Guid id) =>
        HandleClaimAsync(userId => _voucherService.ClaimVoucherAsync(id, userId));

    /// <summary>
    /// Nhập mã để lưu voucher vào ví (dùng được cả với voucher ẩn, không hiện trong Kho).
    /// </summary>
    [HttpPost("claim-by-code")]
    [ProducesResponseType(typeof(MyVoucherDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public Task<IActionResult> ClaimByCode([FromBody] ClaimVoucherByCodeRequest request) =>
        HandleClaimAsync(userId => _voucherService.ClaimVoucherByCodeAsync(request.Code, userId));

    private async Task<IActionResult> HandleClaimAsync(Func<Guid, Task<MyVoucherDto>> claim)
    {
        if (CurrentUserId is not { } userId) return Unauthorized();

        try
        {
            return Ok(await claim(userId));
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
            _logger.LogError(ex, "Lỗi khi lưu voucher cho UserId {UserId}", userId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "Không thể lưu voucher, vui lòng thử lại." });
        }
    }
}
