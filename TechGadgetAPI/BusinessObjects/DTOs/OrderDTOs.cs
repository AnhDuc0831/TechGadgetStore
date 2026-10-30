using BusinessObjects.Enums;
using System.Text.Json.Serialization;

namespace BusinessObjects.DTOs;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CanonicalOrderStatus
{
    Pending,
    Confirmed,
    Shipping,
    Completed,
    Cancelled
}

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CanonicalPaymentStatus
{
    Pending,
    Paid,
    Failed,
    Cancelled,
    Expired,
    Refunded
}

public static class OrderStatusMapper
{
    public static CanonicalOrderStatus ToCanonical(OrderStatus status) => status switch
    {
        OrderStatus.Processing => CanonicalOrderStatus.Confirmed,
        OrderStatus.Confirmed => CanonicalOrderStatus.Confirmed,
        OrderStatus.Shipped => CanonicalOrderStatus.Shipping,
        OrderStatus.Shipping => CanonicalOrderStatus.Shipping,
        OrderStatus.Delivered => CanonicalOrderStatus.Completed,
        OrderStatus.Completed => CanonicalOrderStatus.Completed,
        OrderStatus.Cancelled => CanonicalOrderStatus.Cancelled,
        _ => CanonicalOrderStatus.Pending
    };

    public static OrderStatus ToDbStatus(CanonicalOrderStatus canonical) => canonical switch
    {
        CanonicalOrderStatus.Confirmed => OrderStatus.Processing,
        CanonicalOrderStatus.Shipping => OrderStatus.Shipped,
        CanonicalOrderStatus.Completed => OrderStatus.Delivered,
        CanonicalOrderStatus.Cancelled => OrderStatus.Cancelled,
        _ => OrderStatus.Pending
    };

    public static CanonicalPaymentStatus ToCanonical(PaymentStatus status) => status switch
    {
        PaymentStatus.Unpaid => CanonicalPaymentStatus.Pending,
        PaymentStatus.Pending => CanonicalPaymentStatus.Pending,
        PaymentStatus.Paid => CanonicalPaymentStatus.Paid,
        PaymentStatus.Failed => CanonicalPaymentStatus.Failed,
        PaymentStatus.Cancelled => CanonicalPaymentStatus.Cancelled,
        PaymentStatus.Expired => CanonicalPaymentStatus.Expired,
        PaymentStatus.Refunded => CanonicalPaymentStatus.Refunded,
        _ => CanonicalPaymentStatus.Pending
    };

    public static PaymentStatus ToDbStatus(CanonicalPaymentStatus canonical) => canonical switch
    {
        CanonicalPaymentStatus.Pending => PaymentStatus.Unpaid,
        CanonicalPaymentStatus.Paid => PaymentStatus.Paid,
        CanonicalPaymentStatus.Failed => PaymentStatus.Failed,
        CanonicalPaymentStatus.Cancelled => PaymentStatus.Cancelled,
        CanonicalPaymentStatus.Expired => PaymentStatus.Expired,
        CanonicalPaymentStatus.Refunded => PaymentStatus.Refunded,
        _ => PaymentStatus.Unpaid
    };
}

public class CheckoutRequest
{
    public string ShippingName { get; set; } = string.Empty;
    public string ShippingPhone { get; set; } = string.Empty;
    public string ShippingAddress { get; set; } = string.Empty;
    public string? Note { get; set; }
    // Client-sent shippingFee is intentionally ignored and recomputed server-side
    public decimal? ShippingFee { get; set; }
    public PaymentMethod PaymentMethod { get; set; } = PaymentMethod.Cod;
    public List<Guid> SelectedCartItemIds { get; set; } = new();
}

public class CheckoutResponse
{
    public Guid OrderId { get; set; }
    public long? OrderCode { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal ShippingFee { get; set; }
    public PaymentMethod PaymentMethod { get; set; }
    public CanonicalPaymentStatus PaymentStatus { get; set; }
    public CanonicalOrderStatus OrderStatus { get; set; }
    public string? CheckoutUrl { get; set; }
    public string? QrCode { get; set; }
    public string? PaymentLinkId { get; set; }
    public OrderDto? Order { get; set; }
}

public class OrderDto
{
    public Guid Id { get; set; }
    public CanonicalOrderStatus Status { get; set; }
    public PaymentMethod PaymentMethod { get; set; }
    public CanonicalPaymentStatus PaymentStatus { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal ShippingFee { get; set; }
    public string? ShippingName { get; set; }
    public string? ShippingPhone { get; set; }
    public string ShippingAddress { get; set; } = string.Empty;
    public string? Note { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? PaidAt { get; set; }
    public List<OrderItemDto> Items { get; set; } = new();

    // CheckoutUrl is populated ONLY for unpaid PayOS orders so app can reopen payment
    public string? CheckoutUrl { get; set; }
}

public class AdminOrderDto : OrderDto
{
    public Guid? UserId { get; set; }
    public long? PayOSOrderCode { get; set; }
    public string? PaymentLinkId { get; set; }
    public string? InternalNote { get; set; }
    public bool NeedsReview { get; set; }
}

public class OrderItemDto
{
    public Guid Id { get; set; }
    public Guid ProductVariantId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string Sku { get; set; } = string.Empty;
    public decimal UnitPrice { get; set; }
    public int Quantity { get; set; }
    public decimal TotalPrice => UnitPrice * Quantity;
}

public class PaymentStatusResponse
{
    public Guid OrderId { get; set; }
    public long? OrderCode { get; set; }
    public CanonicalPaymentStatus PaymentStatus { get; set; }
    public CanonicalOrderStatus OrderStatus { get; set; }
    public decimal TotalAmount { get; set; }
    public DateTimeOffset? PaidAt { get; set; }
    public string? PayOSStatus { get; set; }
    public string? CheckoutUrl { get; set; }
}

public class UpdateOrderStatusRequest
{
    public CanonicalOrderStatus Status { get; set; }
}
