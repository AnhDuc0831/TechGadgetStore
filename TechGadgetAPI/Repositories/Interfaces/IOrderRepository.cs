using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using BusinessObjects.Models;

namespace Repositories.Interfaces;

public interface IOrderRepository
{
    Task<Order> CreateOrderWithTransactionAsync(
        Guid userId,
        CheckoutRequest request,
        decimal shippingFee,
        long? payosOrderCode = null,
        string? paymentLinkId = null,
        string? checkoutUrl = null);

    Task<Order?> GetOrderByIdAsync(Guid orderId);
    Task<Order?> GetOrderByOrderCodeAsync(long orderCode);
    Task<List<Order>> GetOrdersByUserIdAsync(Guid userId);
    Task<(List<Order> Orders, int TotalCount)> GetAllOrdersAsync(int page, int pageSize, OrderStatus? status);
    Task UpdateOrderAsync(Order order);
    Task<bool> CancelOrderAndRestoreStockAsync(Guid orderId, string cancellationReason);
    Task<List<Order>> GetExpiredUnpaidPayOSOrdersAsync(DateTimeOffset threshold);
}
