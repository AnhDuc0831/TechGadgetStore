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

    public static (string? Name, string? Phone, string Address) ExtractShippingInfo(string? rawJsonOrText, string? existingName, string? existingPhone)
    {
        string? name = string.IsNullOrWhiteSpace(existingName) ? null : existingName;
        string? phone = string.IsNullOrWhiteSpace(existingPhone) ? null : existingPhone;
        string address = rawJsonOrText ?? string.Empty;

        if (!string.IsNullOrWhiteSpace(rawJsonOrText))
        {
            try
            {
                using var doc = JsonDocument.Parse(rawJsonOrText);
                if (doc.RootElement.ValueKind == JsonValueKind.String)
                {
                    address = doc.RootElement.GetString() ?? string.Empty;
                }
                else if (doc.RootElement.ValueKind == JsonValueKind.Object)
                {
                    if (string.IsNullOrWhiteSpace(name))
                    {
                        if (doc.RootElement.TryGetProperty("recipient_name", out var n) ||
                            doc.RootElement.TryGetProperty("name", out n) ||
                            doc.RootElement.TryGetProperty("shipping_name", out n) ||
                            doc.RootElement.TryGetProperty("shippingName", out n))
                        {
                            name = n.GetString();
                        }
                    }
                    if (string.IsNullOrWhiteSpace(phone))
                    {
                        if (doc.RootElement.TryGetProperty("phone", out var p) ||
                            doc.RootElement.TryGetProperty("shipping_phone", out p) ||
                            doc.RootElement.TryGetProperty("shippingPhone", out p) ||
                            doc.RootElement.TryGetProperty("phoneNumber", out p))
                        {
                            phone = p.GetString();
                        }
                    }
                    string? street = null;
                    if (doc.RootElement.TryGetProperty("address", out var a))
                    {
                        if (a.ValueKind == JsonValueKind.String)
                        {
                            street = a.GetString();
                        }
                        else if (a.ValueKind == JsonValueKind.Object)
                        {
                            var (_, _, nestedAddr) = ExtractShippingInfo(a.GetRawText(), null, null);
                            street = nestedAddr;
                        }
                    }
                    if (string.IsNullOrWhiteSpace(street) || street.Trim().StartsWith("{"))
                    {
                        if (doc.RootElement.TryGetProperty("street", out var s) ||
                            doc.RootElement.TryGetProperty("street_address", out s) ||
                            doc.RootElement.TryGetProperty("detail", out s) ||
                            doc.RootElement.TryGetProperty("detail_address", out s) ||
                            doc.RootElement.TryGetProperty("dia_chi", out s) ||
                            doc.RootElement.TryGetProperty("line1", out s) ||
                            doc.RootElement.TryGetProperty("address_line1", out s) ||
                            doc.RootElement.TryGetProperty("full_address", out s))
                        {
                            street = s.GetString();
                        }
                    }

                    string? ward = null;
                    if (doc.RootElement.TryGetProperty("ward", out var w) ||
                        doc.RootElement.TryGetProperty("phuong", out w) ||
                        doc.RootElement.TryGetProperty("xa", out w))
                    {
                        ward = w.GetString();
                    }

                    string? district = null;
                    if (doc.RootElement.TryGetProperty("district", out var d) ||
                        doc.RootElement.TryGetProperty("quan", out d) ||
                        doc.RootElement.TryGetProperty("huyen", out d))
                    {
                        district = d.GetString();
                    }

                    string? city = null;
                    if (doc.RootElement.TryGetProperty("city", out var c) ||
                        doc.RootElement.TryGetProperty("province", out c) ||
                        doc.RootElement.TryGetProperty("tinh", out c) ||
                        doc.RootElement.TryGetProperty("thanh_pho", out c))
                    {
                        city = c.GetString();
                    }

                    var parts = new List<string>();
                    if (!string.IsNullOrWhiteSpace(street) && !street.Trim().StartsWith("{")) parts.Add(street.Trim());
                    if (!string.IsNullOrWhiteSpace(ward) && !parts.Any(p => p.Contains(ward, StringComparison.OrdinalIgnoreCase))) parts.Add(ward.Trim());
                    if (!string.IsNullOrWhiteSpace(district) && !parts.Any(p => p.Contains(district, StringComparison.OrdinalIgnoreCase))) parts.Add(district.Trim());
                    if (!string.IsNullOrWhiteSpace(city) && !parts.Any(p => p.Contains(city, StringComparison.OrdinalIgnoreCase))) parts.Add(city.Trim());

                    if (parts.Count > 0)
                    {
                        address = string.Join(", ", parts);
                    }
                    else
                    {
                        var metaKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
                        {
                            "recipient_name", "recipientname", "name", "full_name", "fullname",
                            "shipping_name", "shippingname", "phone", "phonenumber", "phone_number",
                            "sdt", "mobile", "shipping_phone", "shippingphone", "id", "status", "note"
                        };
                        var fallbackParts = new List<string>();
                        foreach (var prop in doc.RootElement.EnumerateObject())
                        {
                            if (!metaKeys.Contains(prop.Name))
                            {
                                if (prop.Value.ValueKind == JsonValueKind.String)
                                {
                                    var val = prop.Value.GetString();
                                    if (!string.IsNullOrWhiteSpace(val) && !val.Trim().StartsWith("{")) fallbackParts.Add(val.Trim());
                                }
                            }
                        }
                        if (fallbackParts.Count > 0)
                        {
                            address = string.Join(", ", fallbackParts);
                        }
                    }
                }
            }
            catch
            {
                // raw text
            }
        }

        return (name, phone, address);
    }

    public static string ExtractAddressText(string? rawJsonOrText)
    {
        var (_, _, address) = ExtractShippingInfo(rawJsonOrText, null, null);
        return address;
    }
}
