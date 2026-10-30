using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;
using System.Security.Claims;

namespace API.Controllers;

[ApiController]
[Authorize]
[Route("api/admin/orders")]
public class AdminOrdersController : ControllerBase
{
    private readonly IOrderService _orderService;
    private readonly IProfileService _profileService;
    private readonly ILogger<AdminOrdersController> _logger;

    public AdminOrdersController(
        IOrderService orderService,
        IProfileService profileService,
        ILogger<AdminOrdersController> logger)
    {
        _orderService = orderService;
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
                message = "Chỉ tài khoản Quản trị viên (Admin) mới có quyền truy cập."
            }));
        }

        return (true, null);
    }

    /// <summary>
    /// Admin: Xem toàn bộ danh sách đơn hàng có phân trang và lọc theo trạng thái.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<AdminOrderDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetOrders(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] CanonicalOrderStatus? status = null)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        var result = await _orderService.GetAdminOrdersAsync(page, pageSize, status);
        return Ok(result);
    }

    /// <summary>
    /// Admin: Cập nhật trạng thái đơn hàng (Confirmed, Shipping, Completed, Cancelled...).
    /// </summary>
    [HttpPut("{id:guid}/status")]
    [ProducesResponseType(typeof(AdminOrderDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateOrderStatus(Guid id, [FromBody] UpdateOrderStatusRequest request)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        try
        {
            var updatedOrder = await _orderService.UpdateOrderStatusAsync(id, request.Status);
            return Ok(updatedOrder);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi cập nhật trạng thái đơn hàng {OrderId}", id);
            return BadRequest(new { message = ex.Message });
        }
    }
}
