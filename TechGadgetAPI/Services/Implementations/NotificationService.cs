using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using BusinessObjects.Models;
using Microsoft.Extensions.Logging;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Globalization;

namespace Services.Implementations;

public class NotificationService : INotificationService
{
    private readonly INotificationRepository _repo;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(INotificationRepository repo, ILogger<NotificationService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    // =====================================================================
    // SỰ KIỆN ĐƠN HÀNG
    // =====================================================================

    public Task OnOrderPlacedAsync(Order order) => SafeAsync(nameof(OnOrderPlacedAsync), order, () =>
        NotifyAdminsAsync(
            NotificationTypes.NewOrder,
            $"🛒 Đơn hàng mới {Code(order)}",
            $"{CustomerName(order)} vừa đặt {ItemCount(order)} sản phẩm · {Money(order.TotalAmount)} · {PaymentLabel(order)}",
            order.Id));

    public Task OnOrderPaidAsync(Order order) => SafeAsync(nameof(OnOrderPaidAsync), order, async () =>
    {
        await NotifyAdminsAsync(
            NotificationTypes.OrderPaid,
            $"💰 Đơn {Code(order)} đã thanh toán",
            $"{CustomerName(order)} đã thanh toán {Money(order.TotalAmount)} qua PayOS. Vui lòng xác nhận đơn.",
            order.Id);

        await NotifyCustomerAsync(order,
            NotificationTypes.OrderStatus,
            "Thanh toán thành công",
            $"Đơn hàng {Code(order)} đã được thanh toán {Money(order.TotalAmount)}. Shop sẽ sớm xác nhận đơn của bạn.");
    });

    public Task OnOrderStatusChangedAsync(Order order, CanonicalOrderStatus newStatus, bool refundRequired = false) =>
        SafeAsync(nameof(OnOrderStatusChangedAsync), order, () =>
        {
            var (type, title, message) = newStatus switch
            {
                CanonicalOrderStatus.Confirmed => (NotificationTypes.OrderStatus,
                    "Đơn hàng đã được xác nhận",
                    $"Shop đã xác nhận đơn {Code(order)} và đang chuẩn bị hàng."),
                CanonicalOrderStatus.Shipping => (NotificationTypes.OrderStatus,
                    "Đơn hàng đang được giao 🚚",
                    $"Đơn {Code(order)} đang trên đường giao tới bạn. Vui lòng để ý điện thoại nhé!"),
                CanonicalOrderStatus.Completed => (NotificationTypes.OrderStatus,
                    "Giao hàng thành công ✅",
                    $"Đơn {Code(order)} đã được giao. Hãy đánh giá sản phẩm để giúp người mua khác nhé!"),
                CanonicalOrderStatus.Cancelled => (NotificationTypes.OrderCancelled,
                    "Đơn hàng đã bị hủy",
                    refundRequired
                        ? $"Shop đã hủy đơn {Code(order)}. Số tiền {Money(order.TotalAmount)} sẽ được hoàn lại cho bạn."
                        : $"Shop đã hủy đơn {Code(order)}. Voucher (nếu có) đã được hoàn về ví của bạn."),
                _ => (string.Empty, string.Empty, string.Empty)
            };

            return type.Length == 0 ? Task.CompletedTask : NotifyCustomerAsync(order, type, title, message);
        });

    public Task OnOrderCancelledByCustomerAsync(Order order, string? reason) =>
        SafeAsync(nameof(OnOrderCancelledByCustomerAsync), order, () =>
            NotifyAdminsAsync(
                NotificationTypes.OrderCancelled,
                $"Khách đã hủy đơn {Code(order)}",
                string.IsNullOrWhiteSpace(reason)
                    ? $"{CustomerName(order)} đã hủy đơn {Money(order.TotalAmount)}."
                    : $"{CustomerName(order)} đã hủy đơn {Money(order.TotalAmount)}. Lý do: {reason.Trim()}",
                order.Id));

    public Task OnOrderExpiredAsync(Order order) => SafeAsync(nameof(OnOrderExpiredAsync), order, () =>
        NotifyCustomerAsync(order,
            NotificationTypes.OrderCancelled,
            "Đơn hàng hết hạn thanh toán",
            $"Đơn {Code(order)} đã tự hủy vì quá 15 phút chưa thanh toán. Bạn có thể đặt lại bất cứ lúc nào."));

    public Task OnOrderReceivedAsync(Order order) => SafeAsync(nameof(OnOrderReceivedAsync), order, () =>
        NotifyAdminsAsync(
            NotificationTypes.OrderReceived,
            $"📦 Khách đã nhận đơn {Code(order)}",
            $"{CustomerName(order)} đã xác nhận nhận hàng thành công.",
            order.Id));

    // =====================================================================
    // API NGƯỜI DÙNG
    // =====================================================================

    public async Task<PagedResult<NotificationDto>> GetMyNotificationsAsync(Guid userId, NotificationQueryParams query)
    {
        var page = Math.Max(1, query.Page);
        var pageSize = Math.Clamp(query.PageSize, 1, 50);
        var (items, total) = await _repo.GetPagedAsync(userId, page, pageSize, query.UnreadOnly);

        return new PagedResult<NotificationDto>
        {
            Items = items.Select(n => new NotificationDto
            {
                Id = n.Id,
                Type = n.Type,
                Title = n.Title,
                Message = n.Message,
                OrderId = n.OrderId,
                IsRead = n.IsRead,
                CreatedAt = n.CreatedAt
            }).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = total
        };
    }

    public async Task<UnreadCountDto> GetUnreadCountAsync(Guid userId) => new()
    {
        UnreadCount = await _repo.CountUnreadAsync(userId),
        LatestAt = await _repo.GetLatestCreatedAtAsync(userId)
    };

    public async Task MarkAsReadAsync(Guid id, Guid userId)
    {
        if (!await _repo.ExistsForUserAsync(id, userId))
        {
            throw new KeyNotFoundException("Không tìm thấy thông báo.");
        }
        await _repo.MarkAsReadAsync(id, userId);
    }

    public Task<int> MarkAllAsReadAsync(Guid userId) => _repo.MarkAllAsReadAsync(userId);

    // =====================================================================
    // HELPERS
    // =====================================================================

    private async Task NotifyAdminsAsync(string type, string title, string message, Guid orderId)
    {
        var adminIds = await _repo.GetAdminUserIdsAsync();
        var now = DateTimeOffset.UtcNow;
        await _repo.AddRangeAsync(adminIds.Select(id => new AppNotification
        {
            Id = Guid.NewGuid(),
            UserId = id,
            Type = type,
            Title = title,
            Message = message,
            OrderId = orderId,
            CreatedAt = now
        }));
    }

    private Task NotifyCustomerAsync(Order order, string type, string title, string message)
    {
        if (order.UserId is not { } userId) return Task.CompletedTask;

        return _repo.AddRangeAsync(new[]
        {
            new AppNotification
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Type = type,
                Title = title,
                Message = message,
                OrderId = order.Id,
                CreatedAt = DateTimeOffset.UtcNow
            }
        });
    }

    /// <summary>Chạy việc gửi thông báo, nuốt mọi lỗi (chỉ log) để không ảnh hưởng nghiệp vụ đơn hàng.</summary>
    private async Task SafeAsync(string eventName, Order order, Func<Task> action)
    {
        try
        {
            await action();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Không gửi được thông báo {Event} cho đơn {OrderId}", eventName, order.Id);
        }
    }

    /// <summary>Mã đơn hiển thị: mã PayOS nếu có, ngược lại 8 ký tự đầu của Id.</summary>
    public static string Code(Order order) =>
        order.PayOSOrderCode.HasValue
            ? $"#{order.PayOSOrderCode.Value}"
            : $"#{order.Id.ToString("N")[..8].ToUpperInvariant()}";

    private static string CustomerName(Order order) =>
        !string.IsNullOrWhiteSpace(order.ShippingName) ? order.ShippingName!.Trim()
        : !string.IsNullOrWhiteSpace(order.User?.FullName) ? order.User!.FullName!.Trim()
        : "Khách hàng";

    private static int ItemCount(Order order) => order.OrderItems.Sum(i => i.Quantity);

    private static string Money(decimal amount) =>
        amount.ToString("N0", CultureInfo.InvariantCulture).Replace(",", ".") + "đ";

    private static string PaymentLabel(Order order) =>
        order.PaymentMethod == PaymentMethod.PayOS ? "PayOS" : "COD";
}
