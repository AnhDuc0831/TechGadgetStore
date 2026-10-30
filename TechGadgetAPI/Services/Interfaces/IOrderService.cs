using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using PayOS.Models.Webhooks;

namespace Services.Interfaces;

public interface IOrderService
{
    Task<CheckoutResponse> CheckoutAsync(Guid userId, CheckoutRequest request);
    Task<List<OrderDto>> GetUserOrdersAsync(Guid userId);
    Task<OrderDto> GetOrderByIdAsync(Guid orderId, Guid userId, bool isAdmin);
    Task<PaymentStatusResponse> GetPaymentStatusAsync(Guid orderId, Guid userId, bool isAdmin);
    Task<bool> CancelOrderAsync(Guid orderId, Guid userId, bool isAdmin, string? reason = null);
    Task<bool> ProcessPayOSWebhookAsync(Webhook? webhook);
    Task<PagedResult<AdminOrderDto>> GetAdminOrdersAsync(int page, int pageSize, CanonicalOrderStatus? status);
    Task<AdminOrderDto> UpdateOrderStatusAsync(Guid orderId, CanonicalOrderStatus newStatus);
    Task<int> CancelExpiredPayOSOrdersAsync(int olderThanMinutes = 15);
}
