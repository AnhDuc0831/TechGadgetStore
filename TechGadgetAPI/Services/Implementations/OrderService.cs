using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using BusinessObjects.Models;
using DataAccessObjects;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PayOS.Models.V2.PaymentRequests;
using PayOS.Models.Webhooks;
using Repositories.Interfaces;
using Services.Interfaces;

namespace Services.Implementations;

public class OrderService : IOrderService
{
    private readonly IOrderRepository _orderRepo;
    private readonly IPayOSService _payOSService;
    private readonly ShippingOptions _shippingOptions;
    private readonly ILogger<OrderService> _logger;

    public OrderService(
        IOrderRepository orderRepo,
        IPayOSService payOSService,
        IOptions<ShippingOptions> shippingOptions,
        ILogger<OrderService> logger)
    {
        _orderRepo = orderRepo;
        _payOSService = payOSService;
        _shippingOptions = shippingOptions.Value;
        _logger = logger;
    }

    public async Task<CheckoutResponse> CheckoutAsync(Guid userId, CheckoutRequest request)
    {
        if (request.SelectedCartItemIds == null || request.SelectedCartItemIds.Count == 0)
        {
            throw new InvalidOperationException("Vui lòng chọn ít nhất một sản phẩm để thanh toán.");
        }

        if (string.IsNullOrWhiteSpace(request.ShippingName))
        {
            throw new InvalidOperationException("Vui lòng cung cấp tên người nhận.");
        }

        if (string.IsNullOrWhiteSpace(request.ShippingPhone))
        {
            throw new InvalidOperationException("Vui lòng cung cấp số điện thoại người nhận.");
        }

        if (string.IsNullOrWhiteSpace(request.ShippingAddress))
        {
            throw new InvalidOperationException("Vui lòng cung cấp địa chỉ giao hàng.");
        }

        long? orderCode = null;
        if (request.PaymentMethod == PaymentMethod.PayOS)
        {
            // Server-side generate unique positive integer orderCode
            orderCode = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        }

        // 1. Calculate shipping fee server-side (remove trust in client-sent shippingFee)
        decimal calculatedShippingFee = _shippingOptions.FlatFee;

        // 2. Create order in DB with atomic transaction
        var order = await _orderRepo.CreateOrderWithTransactionAsync(
            userId,
            request,
            calculatedShippingFee,
            orderCode,
            paymentLinkId: null,
            checkoutUrl: null);

        // Re-check if subtotal qualifies for free shipping
        var subtotal = order.TotalAmount - calculatedShippingFee;
        if (_shippingOptions.FreeShippingThreshold > 0 && subtotal >= _shippingOptions.FreeShippingThreshold)
        {
            order.ShippingFee = 0;
            order.TotalAmount = subtotal;
            await _orderRepo.UpdateOrderAsync(order);
        }

        // 3. If COD, return customer-facing DTO
        if (request.PaymentMethod == PaymentMethod.Cod)
        {
            return new CheckoutResponse
            {
                OrderId = order.Id,
                OrderCode = null,
                TotalAmount = order.TotalAmount,
                ShippingFee = order.ShippingFee,
                PaymentMethod = order.PaymentMethod,
                PaymentStatus = OrderStatusMapper.ToCanonical(order.PaymentStatus),
                OrderStatus = OrderStatusMapper.ToCanonical(order.Status),
                Order = MapToCustomerDto(order)
            };
        }

        // 4. If PayOS, create payment link via PayOS SDK
        try
        {
            var paymentItems = order.OrderItems.Select(i => new PaymentLinkItem
            {
                Name = i.ProductName.Length > 50 ? i.ProductName.Substring(0, 50) : i.ProductName,
                Quantity = i.Quantity,
                Price = (int)Math.Round(i.UnitPrice)
            }).ToList();

            var description = $"TGS{orderCode % 100000000}";
            var amount = (int)Math.Round(order.TotalAmount);

            var payResult = await _payOSService.CreatePaymentLinkAsync(
                orderCode!.Value,
                amount,
                description,
                paymentItems,
                buyerName: request.ShippingName,
                buyerPhone: request.ShippingPhone,
                buyerAddress: request.ShippingAddress);

            // Update order with payment link ID and checkout URL
            order.PaymentLinkId = payResult.PaymentLinkId;
            order.CheckoutUrl = payResult.CheckoutUrl;
            await _orderRepo.UpdateOrderAsync(order);

            return new CheckoutResponse
            {
                OrderId = order.Id,
                OrderCode = orderCode,
                TotalAmount = order.TotalAmount,
                ShippingFee = order.ShippingFee,
                PaymentMethod = order.PaymentMethod,
                PaymentStatus = OrderStatusMapper.ToCanonical(order.PaymentStatus),
                OrderStatus = OrderStatusMapper.ToCanonical(order.Status),
                CheckoutUrl = payResult.CheckoutUrl,
                QrCode = payResult.QrCode,
                PaymentLinkId = payResult.PaymentLinkId,
                Order = MapToCustomerDto(order)
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi tạo liên kết thanh toán PayOS cho đơn hàng {OrderId}", order.Id);
            await _orderRepo.CancelOrderAndRestoreStockAsync(order.Id, $"Lỗi cổng thanh toán PayOS: {ex.Message}");
            throw new InvalidOperationException($"Không thể tạo liên kết thanh toán PayOS: {ex.Message}", ex);
        }
    }

    public async Task<List<OrderDto>> GetUserOrdersAsync(Guid userId)
    {
        var orders = await _orderRepo.GetOrdersByUserIdAsync(userId);
        return orders.Select(MapToCustomerDto).ToList();
    }

    public async Task<OrderDto> GetOrderByIdAsync(Guid orderId, Guid userId, bool isAdmin)
    {
        var order = await _orderRepo.GetOrderByIdAsync(orderId);
        if (order == null)
        {
            throw new KeyNotFoundException("Không tìm thấy đơn hàng yêu cầu.");
        }

        if (!isAdmin && order.UserId != userId)
        {
            throw new UnauthorizedAccessException("Bạn không có quyền xem đơn hàng này.");
        }

        // If called by an admin on someone else's order, return the admin DTO; for the owner, return the customer DTO
        if (isAdmin && order.UserId != userId)
        {
            return MapToAdminDto(order);
        }

        return MapToCustomerDto(order);
    }

    public async Task<PaymentStatusResponse> GetPaymentStatusAsync(Guid orderId, Guid userId, bool isAdmin)
    {
        var order = await _orderRepo.GetOrderByIdAsync(orderId);
        if (order == null)
        {
            throw new KeyNotFoundException("Không tìm thấy đơn hàng yêu cầu.");
        }

        if (!isAdmin && order.UserId != userId)
        {
            throw new UnauthorizedAccessException("Bạn không có quyền truy cập trạng thái đơn hàng này.");
        }

        string? payosStatus = null;
        // If PayOS and not yet marked paid locally, sync status with PayOS server
        if (order.PaymentMethod == PaymentMethod.PayOS
            && order.PaymentStatus != PaymentStatus.Paid
            && order.PayOSOrderCode.HasValue)
        {
            try
            {
                var payLink = await _payOSService.GetPaymentLinkAsync(order.PayOSOrderCode.Value);
                if (payLink != null)
                {
                    payosStatus = payLink.Status.ToString();
                    if (string.Equals(payosStatus, "PAID", StringComparison.OrdinalIgnoreCase))
                    {
                        var refCode = payLink.Transactions?.FirstOrDefault()?.Reference ?? payLink.Id ?? "API_SYNC";
                        var paidAmount = payLink.AmountPaid > 0 ? payLink.AmountPaid : payLink.Amount;
                        // Share exact same code path as webhook with amount validation and idempotency
                        await ApplySuccessfulPaymentAsync(order, paidAmount, refCode, source: "payment_status_api");
                    }
                    else if (string.Equals(payosStatus, "CANCELLED", StringComparison.OrdinalIgnoreCase))
                    {
                        await _orderRepo.CancelOrderAndRestoreStockAsync(order.Id, "Đã hủy trên PayOS");
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Không thể đồng bộ trạng thái thanh toán từ PayOS cho OrderId: {OrderId}", orderId);
            }
        }

        var isUnpaidPayOS = order.PaymentMethod == PaymentMethod.PayOS
                            && order.PaymentStatus != PaymentStatus.Paid
                            && order.Status != OrderStatus.Cancelled;

        return new PaymentStatusResponse
        {
            OrderId = order.Id,
            OrderCode = order.PayOSOrderCode,
            PaymentStatus = OrderStatusMapper.ToCanonical(order.PaymentStatus),
            OrderStatus = OrderStatusMapper.ToCanonical(order.Status),
            TotalAmount = order.TotalAmount,
            PaidAt = order.PaidAt,
            PayOSStatus = payosStatus,
            CheckoutUrl = isUnpaidPayOS ? order.CheckoutUrl : null
        };
    }

    public async Task<bool> CancelOrderAsync(Guid orderId, Guid userId, bool isAdmin, string? reason = null)
    {
        var order = await _orderRepo.GetOrderByIdAsync(orderId);
        if (order == null)
        {
            throw new KeyNotFoundException("Không tìm thấy đơn hàng yêu cầu.");
        }

        if (!isAdmin && order.UserId != userId)
        {
            throw new UnauthorizedAccessException("Bạn không có quyền hủy đơn hàng này.");
        }

        if (order.PaymentStatus == PaymentStatus.Paid)
        {
            throw new InvalidOperationException("Không thể hủy đơn hàng đã thanh toán thành công.");
        }

        if (order.Status == OrderStatus.Cancelled)
        {
            return true;
        }

        // Cancel on PayOS if applicable
        if (order.PaymentMethod == PaymentMethod.PayOS && order.PayOSOrderCode.HasValue)
        {
            try
            {
                await _payOSService.CancelPaymentLinkAsync(order.PayOSOrderCode.Value, reason ?? "Khách hàng hủy đơn");
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Lỗi hủy link PayOS cho orderCode {OrderCode}", order.PayOSOrderCode);
            }
        }

        // Restore stock and mark cancelled
        return await _orderRepo.CancelOrderAndRestoreStockAsync(orderId, reason ?? "Khách hàng hủy đơn");
    }

    public async Task<bool> ProcessPayOSWebhookAsync(Webhook? webhook)
    {
        if (webhook == null)
        {
            _logger.LogInformation("Nhận webhook trống từ PayOS (ping/validation request).");
            return true;
        }

        // 1. Verify signature using PayOS SDK
        WebhookData? data;
        try
        {
            data = await _payOSService.VerifyWebhookDataAsync(webhook);
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Chữ ký webhook PayOS không hợp lệ hoặc dữ liệu test/validation: {Message}", ex.Message);
            // Validation/test request with invalid/sample signature: return 200 without modifying any order
            return true;
        }

        if (data == null)
        {
            _logger.LogInformation("Dữ liệu webhook PayOS trống (ping/validation request).");
            return true;
        }

        // 2. Find order by OrderCode
        var order = await _orderRepo.GetOrderByOrderCodeAsync(data.OrderCode);
        if (order == null)
        {
            _logger.LogWarning("Không tìm thấy đơn hàng với PayOS orderCode: {OrderCode} (có thể là test/validation webhook từ payOS)", data.OrderCode);
            // Unknown orderCode: log warning and return true (200 OK) without modifying any order
            return true;
        }

        // 3. Signature is valid AND order exists -> Run real processing
        if (data.Code == "00")
        {
            return await ApplySuccessfulPaymentAsync(order, data.Amount, data.Reference, source: "webhook");
        }
        else
        {
            order.PaymentStatus = PaymentStatus.Failed;
            order.InternalNote = string.IsNullOrEmpty(order.InternalNote)
                ? $"PayOS thanh toán thất bại với mã code: {data.Code}"
                : $"{order.InternalNote} | PayOS thanh toán thất bại với mã code: {data.Code}";
            await _orderRepo.UpdateOrderAsync(order);
            _logger.LogWarning("PayOS báo thanh toán thất bại cho đơn hàng {OrderId} (code: {OrderCode}, status: {Code})", order.Id, data.OrderCode, data.Code);
            return true;
        }
    }

    public async Task<bool> ApplySuccessfulPaymentAsync(Order order, long paidAmount, string reference, string source)
    {
        // 1. Idempotency: if already paid, do not double-process
        if (order.PaymentStatus == PaymentStatus.Paid)
        {
            _logger.LogInformation("Đơn hàng {OrderId} (code: {OrderCode}) đã ở trạng thái Paid, bỏ qua xử lý lặp lại từ {Source}.", order.Id, order.PayOSOrderCode, source);
            return true;
        }

        // 2. Handle arrival for an order that was already Cancelled or Expired
        if (order.Status == OrderStatus.Cancelled || order.PaymentStatus == PaymentStatus.Cancelled || order.PaymentStatus == PaymentStatus.Expired)
        {
            _logger.LogWarning("Nhận thanh toán qua {Source} cho đơn hàng đã bị hủy hoặc hết hạn: OrderId {OrderId}, Code {OrderCode}", source, order.Id, order.PayOSOrderCode);
            order.PaymentStatus = PaymentStatus.Paid;
            order.PaidAt = DateTimeOffset.UtcNow;
            const string reviewNote = "paid after cancellation - needs manual refund/review";
            order.InternalNote = string.IsNullOrEmpty(order.InternalNote)
                ? reviewNote
                : $"{order.InternalNote} | {reviewNote}";

            await _orderRepo.UpdateOrderAsync(order);
            return true;
        }

        // 3. Validate amount matches
        var expectedAmount = (long)Math.Round(order.TotalAmount);
        if (expectedAmount != paidAmount)
        {
            _logger.LogError("Số tiền qua {Source} không khớp: Nhận {PaidAmount} VNĐ nhưng đơn hàng yêu cầu {ExpectedAmount} VNĐ", source, paidAmount, expectedAmount);
            order.PaymentStatus = PaymentStatus.Failed;
            order.InternalNote = $"{order.InternalNote} | Sai số tiền qua {source}: nhận {paidAmount}, cần {expectedAmount}";
            await _orderRepo.UpdateOrderAsync(order);
            throw new InvalidOperationException($"Số tiền thanh toán ({paidAmount}) không khớp với giá trị đơn hàng ({expectedAmount}).");
        }

        // 4. Mark order as Paid and Confirmed
        order.PaymentStatus = PaymentStatus.Paid;
        order.PaidAt = DateTimeOffset.UtcNow;
        order.Status = OrderStatus.Processing; // maps to Confirmed
        order.InternalNote = string.IsNullOrEmpty(order.InternalNote)
            ? $"Thanh toán PayOS thành công qua {source} (ref: {reference})"
            : $"{order.InternalNote} | PayOS ref: {reference} ({source})";

        await _orderRepo.UpdateOrderAsync(order);
        _logger.LogInformation("Thanh toán PayOS thành công qua {Source} cho đơn hàng {OrderId} (code: {OrderCode})", source, order.Id, order.PayOSOrderCode);
        return true;
    }

    public async Task<PagedResult<AdminOrderDto>> GetAdminOrdersAsync(int page, int pageSize, CanonicalOrderStatus? status)
    {
        if (page < 1) page = 1;
        if (pageSize < 1) pageSize = 10;

        OrderStatus? dbStatus = status.HasValue ? OrderStatusMapper.ToDbStatus(status.Value) : null;
        var (orders, totalCount) = await _orderRepo.GetAllOrdersAsync(page, pageSize, dbStatus);
        return new PagedResult<AdminOrderDto>
        {
            Items = orders.Select(MapToAdminDto).ToList(),
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize
        };
    }

    public async Task<AdminOrderDto> UpdateOrderStatusAsync(Guid orderId, CanonicalOrderStatus newStatus)
    {
        var order = await _orderRepo.GetOrderByIdAsync(orderId);
        if (order == null)
        {
            throw new KeyNotFoundException("Không tìm thấy đơn hàng yêu cầu.");
        }

        var currentStatus = OrderStatusMapper.ToCanonical(order.Status);

        // If same status, return unchanged
        if (currentStatus == newStatus)
        {
            return MapToAdminDto(order);
        }

        // Validate allowed state transitions
        var isAllowed = currentStatus switch
        {
            CanonicalOrderStatus.Pending => newStatus == CanonicalOrderStatus.Confirmed || newStatus == CanonicalOrderStatus.Cancelled,
            CanonicalOrderStatus.Confirmed => newStatus == CanonicalOrderStatus.Shipping || newStatus == CanonicalOrderStatus.Cancelled,
            CanonicalOrderStatus.Shipping => newStatus == CanonicalOrderStatus.Completed,
            CanonicalOrderStatus.Completed => false, // Final state
            CanonicalOrderStatus.Cancelled => false, // Final state
            _ => false
        };

        if (!isAllowed)
        {
            var allowedTransitions = currentStatus switch
            {
                CanonicalOrderStatus.Pending => "Confirmed, Cancelled",
                CanonicalOrderStatus.Confirmed => "Shipping, Cancelled",
                CanonicalOrderStatus.Shipping => "Completed",
                CanonicalOrderStatus.Completed => "Không có (Đơn hàng đã hoàn thành - trạng thái cuối)",
                CanonicalOrderStatus.Cancelled => "Không có (Đơn hàng đã hủy - trạng thái cuối)",
                _ => "Không có"
            };

            throw new InvalidOperationException($"Không thể chuyển trạng thái đơn hàng từ '{currentStatus}' sang '{newStatus}'. Các trạng thái hợp lệ tiếp theo: {allowedTransitions}.");
        }

        // When cancelling: restore stock ONLY when cancelling from Pending or Confirmed (never from Shipping/Completed, never twice)
        if (newStatus == CanonicalOrderStatus.Cancelled)
        {
            if (order.PaymentStatus == PaymentStatus.Paid)
            {
                // PayOS order already Paid: cancel link on PayOS, restore stock, flag for manual refund
                if (order.PaymentMethod == PaymentMethod.PayOS && order.PayOSOrderCode.HasValue)
                {
                    try
                    {
                        await _payOSService.CancelPaymentLinkAsync(order.PayOSOrderCode.Value, "Admin cancelled paid order");
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Lỗi hủy link PayOS cho orderCode {OrderCode}", order.PayOSOrderCode);
                    }
                }

                await _orderRepo.CancelOrderAndRestoreStockAsync(orderId, "Admin cancelled paid order");
                order = await _orderRepo.GetOrderByIdAsync(orderId) ?? order;
                order.Status = OrderStatus.Cancelled;
                order.PaymentStatus = PaymentStatus.Paid; // Keep Paid to indicate refund is required
                const string refundNote = "admin cancelled paid order - manual refund required";
                order.InternalNote = string.IsNullOrEmpty(order.InternalNote)
                    ? refundNote
                    : $"{order.InternalNote} | {refundNote}";
                await _orderRepo.UpdateOrderAsync(order);
                return MapToAdminDto(order);
            }
            else
            {
                // Unpaid order: cancel link on PayOS, restore stock once
                if (order.PaymentMethod == PaymentMethod.PayOS && order.PayOSOrderCode.HasValue)
                {
                    try
                    {
                        await _payOSService.CancelPaymentLinkAsync(order.PayOSOrderCode.Value, "Admin cancelled order");
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Lỗi hủy link PayOS cho orderCode {OrderCode}", order.PayOSOrderCode);
                    }
                }

                await _orderRepo.CancelOrderAndRestoreStockAsync(orderId, "Admin cancelled order");
                order = await _orderRepo.GetOrderByIdAsync(orderId) ?? order;
                order.Status = OrderStatus.Cancelled;
                return MapToAdminDto(order);
            }
        }
        else
        {
            order.Status = OrderStatusMapper.ToDbStatus(newStatus);
            await _orderRepo.UpdateOrderAsync(order);
            return MapToAdminDto(order);
        }
    }

    public async Task<int> CancelExpiredPayOSOrdersAsync(int olderThanMinutes = 15)
    {
        var threshold = DateTimeOffset.UtcNow.AddMinutes(-olderThanMinutes);
        var expiredOrders = await _orderRepo.GetExpiredUnpaidPayOSOrdersAsync(threshold);

        int count = 0;
        foreach (var order in expiredOrders)
        {
            try
            {
                if (order.PayOSOrderCode.HasValue)
                {
                    await _payOSService.CancelPaymentLinkAsync(order.PayOSOrderCode.Value, "Hết hạn thanh toán (quá 15 phút)");
                }
                await _orderRepo.CancelOrderAndRestoreStockAsync(order.Id, "Hết hạn thanh toán (quá 15 phút)");
                count++;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Lỗi khi tự động hủy đơn hàng hết hạn: {OrderId}", order.Id);
            }
        }

        return count;
    }

    private static OrderDto MapToCustomerDto(Order o)
    {
        var isUnpaidPayOS = o.PaymentMethod == PaymentMethod.PayOS
                            && o.PaymentStatus != PaymentStatus.Paid
                            && o.Status != OrderStatus.Cancelled;

        return new OrderDto
        {
            Id = o.Id,
            Status = OrderStatusMapper.ToCanonical(o.Status),
            PaymentMethod = o.PaymentMethod,
            PaymentStatus = OrderStatusMapper.ToCanonical(o.PaymentStatus),
            TotalAmount = o.TotalAmount,
            ShippingFee = o.ShippingFee,
            ShippingName = o.ShippingName,
            ShippingPhone = o.ShippingPhone,
            ShippingAddress = OrderDAO.ExtractAddressText(o.ShippingAddress),
            Note = o.Note, // Customer note only!
            CreatedAt = o.CreatedAt,
            PaidAt = o.PaidAt,
            CheckoutUrl = isUnpaidPayOS ? o.CheckoutUrl : null,
            Items = o.OrderItems.Select(i => new OrderItemDto
            {
                Id = i.Id,
                ProductVariantId = i.ProductVariantId,
                ProductName = i.ProductName,
                Sku = i.Sku,
                UnitPrice = i.UnitPrice,
                Quantity = i.Quantity
            }).ToList()
        };
    }

    private static AdminOrderDto MapToAdminDto(Order o)
    {
        var isUnpaidPayOS = o.PaymentMethod == PaymentMethod.PayOS
                            && o.PaymentStatus != PaymentStatus.Paid
                            && o.Status != OrderStatus.Cancelled;

        var isNeedsReview = (o.Status == OrderStatus.Cancelled && o.PaymentStatus == PaymentStatus.Paid)
            || (o.InternalNote != null && o.InternalNote.Contains("manual refund", StringComparison.OrdinalIgnoreCase));

        return new AdminOrderDto
        {
            Id = o.Id,
            UserId = o.UserId,
            PayOSOrderCode = o.PayOSOrderCode,
            PaymentLinkId = o.PaymentLinkId,
            Status = OrderStatusMapper.ToCanonical(o.Status),
            PaymentMethod = o.PaymentMethod,
            PaymentStatus = OrderStatusMapper.ToCanonical(o.PaymentStatus),
            TotalAmount = o.TotalAmount,
            ShippingFee = o.ShippingFee,
            ShippingName = o.ShippingName,
            ShippingPhone = o.ShippingPhone,
            ShippingAddress = OrderDAO.ExtractAddressText(o.ShippingAddress),
            Note = o.Note,
            InternalNote = o.InternalNote,
            NeedsReview = isNeedsReview,
            CreatedAt = o.CreatedAt,
            PaidAt = o.PaidAt,
            CheckoutUrl = isUnpaidPayOS ? o.CheckoutUrl : null,
            Items = o.OrderItems.Select(i => new OrderItemDto
            {
                Id = i.Id,
                ProductVariantId = i.ProductVariantId,
                ProductName = i.ProductName,
                Sku = i.Sku,
                UnitPrice = i.UnitPrice,
                Quantity = i.Quantity
            }).ToList()
        };
    }
}
