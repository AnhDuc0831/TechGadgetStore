using BusinessObjects.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;
using System.Security.Claims;

namespace API.Controllers;

/// <summary>
/// Thông báo trong app của người dùng đang đăng nhập (Admin hoặc Khách).
/// </summary>
[ApiController]
[Authorize]
[Route("api/notifications")]
public class NotificationsController : ControllerBase
{
    private readonly INotificationService _notificationService;

    public NotificationsController(INotificationService notificationService)
    {
        _notificationService = notificationService;
    }

    private Guid? CurrentUserId
    {
        get
        {
            var sub = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
            return Guid.TryParse(sub, out var id) ? id : null;
        }
    }

    /// <summary>Danh sách thông báo (mới nhất trước). ?unreadOnly=true để chỉ lấy chưa đọc.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<NotificationDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetNotifications([FromQuery] NotificationQueryParams query)
    {
        if (CurrentUserId is not { } userId) return Unauthorized();
        return Ok(await _notificationService.GetMyNotificationsAsync(userId, query));
    }

    /// <summary>Số thông báo chưa đọc + thời điểm thông báo mới nhất (app gọi định kỳ để hiện badge).</summary>
    [HttpGet("unread-count")]
    [ProducesResponseType(typeof(UnreadCountDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetUnreadCount()
    {
        if (CurrentUserId is not { } userId) return Unauthorized();
        return Ok(await _notificationService.GetUnreadCountAsync(userId));
    }

    /// <summary>Đánh dấu 1 thông báo đã đọc.</summary>
    [HttpPatch("{id:guid}/read")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> MarkAsRead(Guid id)
    {
        if (CurrentUserId is not { } userId) return Unauthorized();
        try
        {
            await _notificationService.MarkAsReadAsync(id, userId);
            return Ok(new { success = true });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    /// <summary>Đánh dấu tất cả đã đọc.</summary>
    [HttpPatch("read-all")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> MarkAllAsRead()
    {
        if (CurrentUserId is not { } userId) return Unauthorized();
        var count = await _notificationService.MarkAllAsReadAsync(userId);
        return Ok(new { success = true, updated = count });
    }
}
