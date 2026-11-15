using BusinessObjects.DTOs;
using BusinessObjects.Models;

namespace Services.Interfaces;

/// <summary>
/// Thông báo trong app.
/// Các hàm On... được OrderService gọi sau mỗi sự kiện đơn hàng; chúng KHÔNG BAO GIỜ ném lỗi
/// (lỗi gửi thông báo chỉ được ghi log, không làm hỏng luồng đặt hàng / thanh toán).
/// </summary>
public interface INotificationService
{
    // ---- Sự kiện đơn hàng ----
    Task OnOrderPlacedAsync(Order order);
    Task OnOrderPaidAsync(Order order);
    Task OnOrderStatusChangedAsync(Order order, CanonicalOrderStatus newStatus, bool refundRequired = false);
    Task OnOrderCancelledByCustomerAsync(Order order, string? reason);
    Task OnOrderExpiredAsync(Order order);
    Task OnOrderReceivedAsync(Order order);

    // ---- API người dùng ----
    Task<PagedResult<NotificationDto>> GetMyNotificationsAsync(Guid userId, NotificationQueryParams query);
    Task<UnreadCountDto> GetUnreadCountAsync(Guid userId);
    Task MarkAsReadAsync(Guid id, Guid userId);
    Task<int> MarkAllAsReadAsync(Guid userId);
}
