using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using BusinessObjects.Models;
using DataAccessObjects;
using Repositories.Interfaces;

namespace Repositories.Implementations;

public class OrderRepository : IOrderRepository
{
    private readonly OrderDAO _orderDao;

    public OrderRepository(OrderDAO orderDao)
    {
        _orderDao = orderDao;
    }

    public Task<Order> CreateOrderWithTransactionAsync(
        Guid userId,
        CheckoutRequest request,
        decimal shippingFee,
        long? payosOrderCode = null,
        string? paymentLinkId = null,
        string? checkoutUrl = null)
    {
        return _orderDao.CreateOrderWithTransactionAsync(userId, request, shippingFee, payosOrderCode, paymentLinkId, checkoutUrl);
    }

    public Task<Order?> GetOrderByIdAsync(Guid orderId) => _orderDao.GetOrderByIdAsync(orderId);

    public Task<Order?> GetOrderByOrderCodeAsync(long orderCode) => _orderDao.GetOrderByOrderCodeAsync(orderCode);

    public Task<List<Order>> GetOrdersByUserIdAsync(Guid userId) => _orderDao.GetOrdersByUserIdAsync(userId);

    public Task<(List<Order> Orders, int TotalCount)> GetAllOrdersAsync(int page, int pageSize, OrderStatus? status) =>
        _orderDao.GetAllOrdersAsync(page, pageSize, status);

    public Task UpdateOrderAsync(Order order) => _orderDao.UpdateOrderAsync(order);

    public Task<bool> CancelOrderAndRestoreStockAsync(Guid orderId, string cancellationReason) =>
        _orderDao.CancelOrderAndRestoreStockAsync(orderId, cancellationReason);

    public Task<List<Order>> GetExpiredUnpaidPayOSOrdersAsync(DateTimeOffset threshold) =>
        _orderDao.GetExpiredUnpaidPayOSOrdersAsync(threshold);
}
