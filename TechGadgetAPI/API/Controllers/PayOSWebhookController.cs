using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PayOS.Models.Webhooks;
using Services.Interfaces;
using System.Security.Claims;

namespace API.Controllers;

[ApiController]
[Route("api/payos")]
public class PayOSWebhookController : ControllerBase
{
    private readonly IOrderService _orderService;
    private readonly IPayOSService _payOSService;
    private readonly IProfileService _profileService;
    private readonly ILogger<PayOSWebhookController> _logger;

    public PayOSWebhookController(
        IOrderService orderService,
        IPayOSService payOSService,
        IProfileService profileService,
        ILogger<PayOSWebhookController> logger)
    {
        _orderService = orderService;
        _payOSService = payOSService;
        _profileService = profileService;
        _logger = logger;
    }

    /// <summary>
    /// Nhận Webhook từ cổng thanh toán PayOS khi khách hàng thanh toán thành công hoặc khi PayOS kiểm tra/xác thực webhook URL.
    /// Đối với yêu cầu xác thực/test từ payOS (orderCode không tồn tại, chữ ký không hợp lệ, dữ liệu mẫu/trống):
    /// Trả về HTTP 200 với { "success": true } và không sửa đổi bất kỳ đơn hàng nào.
    /// Chỉ khi chữ ký hợp lệ VÀ đơn hàng tồn tại mới thực hiện xử lý thanh toán thực tế.
    /// Lỗi xử lý thực tế trên đơn hàng khớp hợp lệ có thể trả về 500 để payOS gửi lại.
    /// </summary>
    [HttpPost("webhook")]
    [AllowAnonymous]
    public async Task<IActionResult> HandleWebhook([FromBody(EmptyBodyBehavior = Microsoft.AspNetCore.Mvc.ModelBinding.EmptyBodyBehavior.Allow)] Webhook? webhook)
    {
        try
        {
            _logger.LogInformation("Nhận webhook PayOS...");
            await _orderService.ProcessPayOSWebhookAsync(webhook);
            return Ok(new { success = true });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi xử lý webhook PayOS cho đơn hàng hợp lệ");
            return StatusCode(StatusCodes.Status500InternalServerError, new { success = false, message = "Internal error" });
        }
    }

    /// <summary>
    /// Admin endpoint để xác thực và đăng ký Webhook URL với PayOS (gọi ConfirmAsync).
    /// </summary>
    [HttpPost("confirm-webhook")]
    [Authorize]
    public async Task<IActionResult> ConfirmWebhook([FromBody] ConfirmWebhookPayload payload)
    {
        var userIdClaim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (Guid.TryParse(userIdClaim, out var userId))
        {
            var profile = await _profileService.GetProfileByIdAsync(userId);
            if (profile == null || !string.Equals(profile.Role, "admin", StringComparison.OrdinalIgnoreCase))
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = "Chỉ Quản trị viên mới có quyền đăng ký webhook." });
            }
        }
        else
        {
            return Unauthorized();
        }

        if (string.IsNullOrWhiteSpace(payload.WebhookUrl))
        {
            return BadRequest(new { message = "Vui lòng cung cấp webhookUrl." });
        }

        try
        {
            var result = await _payOSService.ConfirmWebhookAsync(payload.WebhookUrl);
            return Ok(new { success = true, result });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi đăng ký webhook URL với PayOS: {Url}", payload.WebhookUrl);
            return BadRequest(new { success = false, message = ex.Message });
        }
    }
}

public class ConfirmWebhookPayload
{
    public string WebhookUrl { get; set; } = string.Empty;
}
