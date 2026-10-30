using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;
using System.Security.Claims;

namespace API.Controllers;

[ApiController]
[Authorize]
[Route("api/orders")]
public class OrdersController : ControllerBase
{
    private readonly IOrderService _orderService;
    private readonly IProfileService _profileService;
    private readonly ILogger<OrdersController> _logger;

    public OrdersController(
        IOrderService orderService,
        IProfileService profileService,
        ILogger<OrdersController> logger)
    {
        _orderService = orderService;
        _profileService = profileService;
        _logger = logger;
    }

    private Guid UserId
    {
        get
        {
            var sub = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
            return Guid.TryParse(sub, out var id) ? id : throw new UnauthorizedAccessException();
        }
    }

    private async Task<bool> IsAdminAsync()
    {
        try
        {
            var profile = await _profileService.GetProfileByIdAsync(UserId);
            return profile != null && string.Equals(profile.Role, "admin", StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// Đặt hàng và thanh toán (COD hoặc tạo liên kết thanh toán PayOS).
    /// Giá sản phẩm luôn được tính lại từ CSDL server.
    /// </summary>
    [HttpPost("checkout")]
    [ProducesResponseType(typeof(CheckoutResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Checkout([FromBody] CheckoutRequest request)
    {
        try
        {
            var response = await _orderService.CheckoutAsync(UserId, request);
            return Ok(response);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi xảy ra trong quá trình Checkout cho UserId {UserId}", UserId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "Lỗi xử lý đơn hàng: " + ex.Message });
        }
    }

    /// <summary>
    /// Lấy danh sách đơn hàng của người dùng đang đăng nhập.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(List<OrderDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetUserOrders()
    {
        try
        {
            var orders = await _orderService.GetUserOrdersAsync(UserId);
            return Ok(orders);
        }
        catch (UnauthorizedAccessException)
        {
            return Unauthorized();
        }
    }

    /// <summary>
    /// Lấy chi tiết đơn hàng theo ID (Chỉ chủ đơn hàng hoặc Admin).
    /// </summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(OrderDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetOrderById(Guid id)
    {
        try
        {
            var isAdmin = await IsAdminAsync();
            var order = await _orderService.GetOrderByIdAsync(id, UserId, isAdmin);
            return Ok(order);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
    }

    /// <summary>
    /// Lấy trạng thái thanh toán của đơn hàng (đồng bộ với PayOS nếu cần).
    /// </summary>
    [HttpGet("{id:guid}/payment-status")]
    [ProducesResponseType(typeof(PaymentStatusResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetPaymentStatus(Guid id)
    {
        try
        {
            var isAdmin = await IsAdminAsync();
            var status = await _orderService.GetPaymentStatusAsync(id, UserId, isAdmin);
            return Ok(status);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
    }

    /// <summary>
    /// Hủy đơn hàng khi chưa thanh toán (hủy link PayOS và hoàn lại số lượng tồn kho).
    /// </summary>
    [HttpPost("{id:guid}/cancel")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CancelOrder(Guid id, [FromQuery] string? reason = null)
    {
        try
        {
            var isAdmin = await IsAdminAsync();
            var success = await _orderService.CancelOrderAsync(id, UserId, isAdmin, reason);
            return Ok(new { success, message = "Đơn hàng đã được hủy thành công và tồn kho đã được hoàn lại." });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
