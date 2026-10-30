using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using BusinessObjects.Models;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace DataAccessObjects;

public class OrderDAO
{
    private readonly TechGadgetDbContext _context;

    public OrderDAO(TechGadgetDbContext context)
    {
        _context = context;
    }

    public async Task<Order> CreateOrderWithTransactionAsync(
        Guid userId,
        CheckoutRequest request,
        decimal shippingFee,
        long? payosOrderCode = null,
        string? paymentLinkId = null,
        string? checkoutUrl = null)
    {
        using var transaction = await _context.Database.BeginTransactionAsync();

        // 1. Validate Cart
        var cart = await _context.ShoppingCarts
            .Include(c => c.CartItems)
                .ThenInclude(i => i.ProductVariant)
                    .ThenInclude(v => v.Product)
            .FirstOrDefaultAsync(c => c.UserId == userId);

        if (cart == null || cart.CartItems.Count == 0)
        {
            throw new InvalidOperationException("Giỏ hàng của bạn đang trống.");
        }

        var selectedItems = cart.CartItems
            .Where(i => request.SelectedCartItemIds.Contains(i.Id))
            .ToList();

        if (selectedItems.Count == 0)
        {
            throw new InvalidOperationException("Vui lòng chọn ít nhất một sản phẩm từ giỏ hàng để thanh toán.");
        }

        // 2. Validate Stock and calculate prices strictly from database
        decimal subtotal = 0;
        var orderItems = new List<OrderItem>();
        var orderId = Guid.NewGuid();
        var now = DateTimeOffset.UtcNow;

        foreach (var item in selectedItems)
        {
            var variant = item.ProductVariant;
            var product = variant.Product;

            if (variant.StockQuantity < item.Quantity)
            {
                throw new InvalidOperationException(
                    $"Sản phẩm '{product.Name} ({variant.Sku})' không đủ số lượng tồn kho (còn {variant.StockQuantity}, yêu cầu {item.Quantity}).");
            }

            // Deduct stock
            variant.StockQuantity -= item.Quantity;
            variant.UpdatedAt = now;

            // Recompute unit price from DB (base_price + price_adjustment)
            var unitPrice = Math.Max(0, product.BasePrice + variant.PriceAdjustment);
            var costPrice = variant.CostPrice;

            subtotal += unitPrice * item.Quantity;

            orderItems.Add(new OrderItem
            {
                Id = Guid.NewGuid(),
                OrderId = orderId,
                ProductVariantId = variant.Id,
                ProductName = $"{product.Name} - {variant.Sku}",
                Sku = variant.Sku,
                UnitPrice = unitPrice,
                CostPrice = costPrice,
                Quantity = item.Quantity,
                CreatedAt = now,
                UpdatedAt = now
            });
        }

        var totalAmount = subtotal + shippingFee;

        // Ensure ShippingAddress is valid JSON (column is jsonb)
        string shippingAddressJson;
        try
        {
            using var doc = JsonDocument.Parse(request.ShippingAddress);
            shippingAddressJson = request.ShippingAddress;
        }
        catch
        {
            shippingAddressJson = JsonSerializer.Serialize(new
            {
                recipient_name = request.ShippingName,
                phone = request.ShippingPhone,
                address = request.ShippingAddress
            });
        }

        var order = new Order
        {
            Id = orderId,
            UserId = userId,
            Status = OrderStatus.Pending,
            ShippingFee = shippingFee,
            TotalAmount = totalAmount,
            ShippingAddress = shippingAddressJson,
            ShippingName = request.ShippingName,
            ShippingPhone = request.ShippingPhone,
            PaymentMethod = request.PaymentMethod,
            PaymentStatus = PaymentStatus.Unpaid,
            PayOSOrderCode = payosOrderCode,
            PaymentLinkId = paymentLinkId,
            CheckoutUrl = checkoutUrl,
            Note = request.Note,
            CreatedAt = now,
            UpdatedAt = now,
            OrderItems = orderItems
        };

        _context.Orders.Add(order);

        // Remove purchased items from cart
        _context.CartItems.RemoveRange(selectedItems);

        await _context.SaveChangesAsync();
        await transaction.CommitAsync();

        return order;
    }

    public async Task<Order?> GetOrderByIdAsync(Guid orderId)
    {
        return await _context.Orders
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.ProductVariant)
            .Include(o => o.User)
            .FirstOrDefaultAsync(o => o.Id == orderId);
    }

    public async Task<Order?> GetOrderByOrderCodeAsync(long orderCode)
    {
        return await _context.Orders
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.ProductVariant)
            .Include(o => o.User)
            .FirstOrDefaultAsync(o => o.PayOSOrderCode == orderCode);
    }

    public async Task<List<Order>> GetOrdersByUserIdAsync(Guid userId)
    {
        return await _context.Orders
            .AsNoTracking()
            .Include(o => o.OrderItems)
            .Where(o => o.UserId == userId)
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync();
    }

    public async Task<(List<Order> Orders, int TotalCount)> GetAllOrdersAsync(int page, int pageSize, OrderStatus? status)
    {
        var query = _context.Orders
            .AsNoTracking()
            .Include(o => o.OrderItems)
            .Include(o => o.User)
            .AsQueryable();

        if (status.HasValue)
        {
            query = query.Where(o => o.Status == status.Value);
        }

        var totalCount = await query.CountAsync();
        var orders = await query
            .OrderByDescending(o => o.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return (orders, totalCount);
    }

    public async Task UpdateOrderAsync(Order order)
    {
        order.UpdatedAt = DateTimeOffset.UtcNow;
        _context.Orders.Update(order);
        await _context.SaveChangesAsync();
    }

    public async Task<bool> CancelOrderAndRestoreStockAsync(Guid orderId, string cancellationReason)
    {
        using var transaction = await _context.Database.BeginTransactionAsync();

        var order = await _context.Orders
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.ProductVariant)
            .FirstOrDefaultAsync(o => o.Id == orderId);

        if (order == null) return false;

        // Restore stock
        foreach (var item in order.OrderItems)
        {
            if (item.ProductVariant != null)
            {
                item.ProductVariant.StockQuantity += item.Quantity;
                item.ProductVariant.UpdatedAt = DateTimeOffset.UtcNow;
            }
        }

        order.Status = OrderStatus.Cancelled;
        order.PaymentStatus = PaymentStatus.Cancelled;
        order.Note = string.IsNullOrEmpty(order.Note)
            ? $"Hủy đơn: {cancellationReason}"
            : $"{order.Note} | Hủy đơn: {cancellationReason}";
        order.UpdatedAt = DateTimeOffset.UtcNow;

        await _context.SaveChangesAsync();
        await transaction.CommitAsync();

        return true;
    }

    public async Task<List<Order>> GetExpiredUnpaidPayOSOrdersAsync(DateTimeOffset threshold)
    {
        return await _context.Orders
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.ProductVariant)
            .Where(o => o.PaymentMethod == PaymentMethod.PayOS
                     && (o.PaymentStatus == PaymentStatus.Unpaid || o.PaymentStatus == PaymentStatus.Pending)
                     && o.Status != OrderStatus.Cancelled
                     && o.CreatedAt < threshold)
            .ToListAsync();
    }

    public static string ExtractAddressText(string? rawJsonOrText)
    {
        if (string.IsNullOrWhiteSpace(rawJsonOrText)) return string.Empty;
        try
        {
            using var doc = JsonDocument.Parse(rawJsonOrText);
            if (doc.RootElement.ValueKind == JsonValueKind.String)
            {
                return doc.RootElement.GetString() ?? string.Empty;
            }
            if (doc.RootElement.ValueKind == JsonValueKind.Object)
            {
                if (doc.RootElement.TryGetProperty("address", out var addr))
                {
                    return addr.GetString() ?? string.Empty;
                }
            }
            return rawJsonOrText;
        }
        catch
        {
            return rawJsonOrText;
        }
    }
}
