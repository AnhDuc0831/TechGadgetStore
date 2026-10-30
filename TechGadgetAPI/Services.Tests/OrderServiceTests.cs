using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using BusinessObjects.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using PayOS.Models.V2.PaymentRequests;
using PayOS.Models.Webhooks;
using Repositories.Interfaces;
using Services.Implementations;
using Services.Interfaces;
using System.Text.Json;
using System.Text.Json.Serialization;
using Xunit;

namespace Services.Tests;

public class OrderServiceTests
{
    private readonly Mock<IOrderRepository> _orderRepoMock;
    private readonly Mock<IPayOSService> _payOSServiceMock;
    private readonly Mock<ILogger<OrderService>> _loggerMock;
    private readonly IOptions<ShippingOptions> _shippingOptions;
    private readonly OrderService _orderService;

    public OrderServiceTests()
    {
        _orderRepoMock = new Mock<IOrderRepository>();
        _payOSServiceMock = new Mock<IPayOSService>();
        _loggerMock = new Mock<ILogger<OrderService>>();
        _shippingOptions = Options.Create(new ShippingOptions
        {
            FlatFee = 30000,
            FreeShippingThreshold = 500000
        });

        _orderService = new OrderService(
            _orderRepoMock.Object,
            _payOSServiceMock.Object,
            _shippingOptions,
            _loggerMock.Object);
    }

    // --- TEST ITEM 1: SECURITY - CUSTOMER DTO EXCLUDES COST PRICE, INTERNAL NOTE & NEEDS REVIEW ---

    [Fact]
    public void CustomerFacingDto_ContainsNoCostPrice_NorInternalNote_NorNeedsReview()
    {
        var itemDto = new OrderItemDto
        {
            Id = Guid.NewGuid(),
            ProductVariantId = Guid.NewGuid(),
            ProductName = "iPhone 15 Pro Max",
            Sku = "IP15PM",
            UnitPrice = 25000000m,
            Quantity = 1
        };

        var orderDto = new OrderDto
        {
            Id = Guid.NewGuid(),
            Status = CanonicalOrderStatus.Cancelled,
            PaymentMethod = PaymentMethod.PayOS,
            PaymentStatus = CanonicalPaymentStatus.Paid,
            TotalAmount = 25000000m,
            Note = "Giao gio hanh chinh",
            Items = new List<OrderItemDto> { itemDto }
        };

        var options = new JsonSerializerOptions();
        options.Converters.Add(new JsonStringEnumConverter());
        var json = JsonSerializer.Serialize(orderDto, options);

        // Security assertion 1: costPrice must NOT exist anywhere in customer-facing JSON
        Assert.DoesNotContain("costPrice", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("CostPrice", json);

        // Security assertion 2: internalNote must NOT exist in customer-facing JSON
        Assert.DoesNotContain("internalNote", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("InternalNote", json);

        // Security assertion 3: needsReview must NOT exist in customer-facing JSON
        Assert.DoesNotContain("needsReview", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("NeedsReview", json);
    }

    [Fact]
    public async Task CustomerOrderQuery_EvenWhenAdminCancelledAfterPayment_ContainsNeitherInternalNoteNorNeedsReview()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var orderId = Guid.NewGuid();
        var order = new Order
        {
            Id = orderId,
            UserId = userId,
            PaymentMethod = PaymentMethod.PayOS,
            PaymentStatus = PaymentStatus.Paid,
            Status = OrderStatus.Cancelled, // Admin cancelled after payment
            Note = "Khach hang ghi chu",
            InternalNote = "admin cancelled paid order - manual refund required",
            TotalAmount = 1000000m
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);

        // Act: Customer queries their own order
        var result = await _orderService.GetOrderByIdAsync(orderId, userId, isAdmin: false);

        // Assert: result is pure OrderDto
        Assert.NotNull(result);
        Assert.IsType<OrderDto>(result);

        var options = new JsonSerializerOptions();
        options.Converters.Add(new JsonStringEnumConverter());
        var json = JsonSerializer.Serialize(result, options);

        Assert.DoesNotContain("internalNote", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("needsReview", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("manual refund required", json);
    }

    [Fact]
    public async Task AdminOrderQuery_ContainsInternalNoteAndNeedsReview()
    {
        // Arrange
        var customerId = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        var orderId = Guid.NewGuid();
        var order = new Order
        {
            Id = orderId,
            UserId = customerId,
            PaymentMethod = PaymentMethod.PayOS,
            PaymentStatus = PaymentStatus.Paid,
            Status = OrderStatus.Cancelled, // Admin cancelled after payment
            Note = "Khach hang ghi chu",
            InternalNote = "admin cancelled paid order - manual refund required",
            TotalAmount = 1000000m
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);

        // Act: Admin queries order
        var result = await _orderService.GetOrderByIdAsync(orderId, adminId, isAdmin: true);

        // Assert: result is AdminOrderDto
        Assert.NotNull(result);
        var adminDto = Assert.IsType<AdminOrderDto>(result);
        Assert.True(adminDto.NeedsReview);
        Assert.Contains("manual refund required", adminDto.InternalNote);

        var options = new JsonSerializerOptions();
        options.Converters.Add(new JsonStringEnumConverter());
        var json = JsonSerializer.Serialize(adminDto, options);

        Assert.Contains("\"InternalNote\":", json);
        Assert.Contains("\"NeedsReview\":true", json);
    }

    [Fact]
    public async Task GetOrderById_CalledByAdmin_OnOwnOrder_ReturnsCustomerDtoWithoutInternalNoteOrNeedsReview()
    {
        // Arrange: Admin queries their OWN order as a customer
        var adminUserId = Guid.NewGuid();
        var orderId = Guid.NewGuid();
        var order = new Order
        {
            Id = orderId,
            UserId = adminUserId, // Same as caller
            PaymentMethod = PaymentMethod.PayOS,
            PaymentStatus = PaymentStatus.Paid,
            Status = OrderStatus.Cancelled,
            InternalNote = "admin cancelled paid order - manual refund required",
            TotalAmount = 500000m
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);

        // Act: Admin is owner
        var result = await _orderService.GetOrderByIdAsync(orderId, adminUserId, isAdmin: true);

        // Assert: for the owner, return the customer DTO
        Assert.NotNull(result);
        Assert.IsNotType<AdminOrderDto>(result);
        Assert.IsType<OrderDto>(result);

        var options = new JsonSerializerOptions();
        options.Converters.Add(new JsonStringEnumConverter());
        var json = JsonSerializer.Serialize(result, options);

        Assert.DoesNotContain("internalNote", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("needsReview", json, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void CustomerFacingResponses_CheckoutAndPaymentStatus_NeverContainInternalNoteOrNeedsReview()
    {
        // Arrange: CheckoutResponse & PaymentStatusResponse
        var checkoutResponse = new CheckoutResponse
        {
            OrderId = Guid.NewGuid(),
            OrderCode = 123456L,
            TotalAmount = 200000m,
            ShippingFee = 30000m,
            PaymentMethod = PaymentMethod.PayOS,
            PaymentStatus = CanonicalPaymentStatus.Pending,
            OrderStatus = CanonicalOrderStatus.Pending,
            CheckoutUrl = "https://pay.payos.vn/web/test",
            Order = new OrderDto
            {
                Id = Guid.NewGuid(),
                Status = CanonicalOrderStatus.Pending,
                PaymentMethod = PaymentMethod.PayOS,
                PaymentStatus = CanonicalPaymentStatus.Pending,
                TotalAmount = 200000m
            }
        };

        var paymentStatusResponse = new PaymentStatusResponse
        {
            OrderId = Guid.NewGuid(),
            OrderCode = 123456L,
            PaymentStatus = CanonicalPaymentStatus.Paid,
            OrderStatus = CanonicalOrderStatus.Confirmed,
            TotalAmount = 200000m,
            PaidAt = DateTimeOffset.UtcNow,
            PayOSStatus = "PAID"
        };

        var options = new JsonSerializerOptions();
        options.Converters.Add(new JsonStringEnumConverter());

        var checkoutJson = JsonSerializer.Serialize(checkoutResponse, options);
        var paymentStatusJson = JsonSerializer.Serialize(paymentStatusResponse, options);

        // Assert
        Assert.DoesNotContain("internalNote", checkoutJson, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("needsReview", checkoutJson, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("internalNote", paymentStatusJson, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("needsReview", paymentStatusJson, StringComparison.OrdinalIgnoreCase);
    }

    // --- TEST ITEM 2: Admin Status Transitions Validation ---

    [Theory]
    [InlineData(OrderStatus.Pending, CanonicalOrderStatus.Confirmed)]
    [InlineData(OrderStatus.Pending, CanonicalOrderStatus.Cancelled)]
    [InlineData(OrderStatus.Processing, CanonicalOrderStatus.Shipping)]
    [InlineData(OrderStatus.Processing, CanonicalOrderStatus.Cancelled)]
    [InlineData(OrderStatus.Shipped, CanonicalOrderStatus.Completed)]
    public async Task AdminStatusTransitions_AllowedTransitions_Succeed(OrderStatus initialDbStatus, CanonicalOrderStatus targetStatus)
    {
        // Arrange
        var orderId = Guid.NewGuid();
        var order = new Order
        {
            Id = orderId,
            Status = initialDbStatus,
            PaymentStatus = PaymentStatus.Unpaid,
            PaymentMethod = PaymentMethod.Cod
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);
        _orderRepoMock.Setup(r => r.CancelOrderAndRestoreStockAsync(orderId, It.IsAny<string>())).ReturnsAsync(true);
        _orderRepoMock.Setup(r => r.UpdateOrderAsync(It.IsAny<Order>())).Returns(Task.CompletedTask);

        // Act
        var result = await _orderService.UpdateOrderStatusAsync(orderId, targetStatus);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(targetStatus, result.Status);
    }

    [Theory]
    [InlineData(OrderStatus.Pending, CanonicalOrderStatus.Shipping)]
    [InlineData(OrderStatus.Pending, CanonicalOrderStatus.Completed)]
    [InlineData(OrderStatus.Processing, CanonicalOrderStatus.Pending)]
    [InlineData(OrderStatus.Processing, CanonicalOrderStatus.Completed)]
    [InlineData(OrderStatus.Shipped, CanonicalOrderStatus.Pending)]
    [InlineData(OrderStatus.Shipped, CanonicalOrderStatus.Confirmed)]
    [InlineData(OrderStatus.Shipped, CanonicalOrderStatus.Cancelled)] // Cannot cancel once shipping!
    [InlineData(OrderStatus.Delivered, CanonicalOrderStatus.Cancelled)] // Final state!
    [InlineData(OrderStatus.Delivered, CanonicalOrderStatus.Shipping)]  // Final state!
    [InlineData(OrderStatus.Cancelled, CanonicalOrderStatus.Confirmed)] // Final state!
    [InlineData(OrderStatus.Cancelled, CanonicalOrderStatus.Pending)]   // Final state!
    public async Task AdminStatusTransitions_InvalidTransitions_RejectedWith400(OrderStatus initialDbStatus, CanonicalOrderStatus targetStatus)
    {
        // Arrange
        var orderId = Guid.NewGuid();
        var order = new Order
        {
            Id = orderId,
            Status = initialDbStatus,
            PaymentStatus = PaymentStatus.Unpaid
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);

        // Act & Assert
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _orderService.UpdateOrderStatusAsync(orderId, targetStatus));

        Assert.Contains("Không thể chuyển trạng thái đơn hàng", ex.Message);
        // Stock restoration must NEVER be called on invalid transitions
        _orderRepoMock.Verify(r => r.CancelOrderAndRestoreStockAsync(It.IsAny<Guid>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task AdminUpdateStatus_ToCancelled_FromConfirmed_RestoresStockOnce()
    {
        // Arrange
        var orderId = Guid.NewGuid();
        var order = new Order
        {
            Id = orderId,
            PaymentMethod = PaymentMethod.PayOS,
            PaymentStatus = PaymentStatus.Unpaid,
            Status = OrderStatus.Processing, // Confirmed
            PayOSOrderCode = 123456L
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);
        _orderRepoMock.Setup(r => r.CancelOrderAndRestoreStockAsync(orderId, It.IsAny<string>())).ReturnsAsync(true);
        _payOSServiceMock.Setup(p => p.CancelPaymentLinkAsync(123456L, It.IsAny<string>())).ReturnsAsync(new PaymentLink());

        // Act
        var result = await _orderService.UpdateOrderStatusAsync(orderId, CanonicalOrderStatus.Cancelled);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(CanonicalOrderStatus.Cancelled, result.Status);
        _orderRepoMock.Verify(r => r.CancelOrderAndRestoreStockAsync(orderId, "Admin cancelled order"), Times.Once);
        _payOSServiceMock.Verify(p => p.CancelPaymentLinkAsync(123456L, "Admin cancelled order"), Times.Once);
    }

    [Fact]
    public async Task AdminUpdateStatus_ToCancelled_PaidOrder_RestoresStockAndSetsNeedsReview()
    {
        // Arrange
        var orderId = Guid.NewGuid();
        var order = new Order
        {
            Id = orderId,
            PaymentMethod = PaymentMethod.PayOS,
            PaymentStatus = PaymentStatus.Paid, // Already paid!
            Status = OrderStatus.Processing,   // Confirmed
            PayOSOrderCode = 654321L
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);
        _orderRepoMock.Setup(r => r.CancelOrderAndRestoreStockAsync(orderId, It.IsAny<string>())).ReturnsAsync(true);
        _orderRepoMock.Setup(r => r.UpdateOrderAsync(It.IsAny<Order>())).Returns(Task.CompletedTask);

        // Act
        var result = await _orderService.UpdateOrderStatusAsync(orderId, CanonicalOrderStatus.Cancelled);

        // Assert
        Assert.NotNull(result);
        Assert.True(result.NeedsReview); // Visible in admin orders list
        Assert.Contains("manual refund required", result.InternalNote);
        _orderRepoMock.Verify(r => r.CancelOrderAndRestoreStockAsync(orderId, "Admin cancelled paid order"), Times.Once);
    }

    [Fact]
    public async Task AdminUpdateStatus_ToCancelled_FromPending_RestoresStockOnce()
    {
        // Arrange
        var orderId = Guid.NewGuid();
        var order = new Order
        {
            Id = orderId,
            PaymentMethod = PaymentMethod.Cod,
            PaymentStatus = PaymentStatus.Unpaid,
            Status = OrderStatus.Pending
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);
        _orderRepoMock.Setup(r => r.CancelOrderAndRestoreStockAsync(orderId, It.IsAny<string>())).ReturnsAsync(true);

        // Act
        var result = await _orderService.UpdateOrderStatusAsync(orderId, CanonicalOrderStatus.Cancelled);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(CanonicalOrderStatus.Cancelled, result.Status);
        _orderRepoMock.Verify(r => r.CancelOrderAndRestoreStockAsync(orderId, "Admin cancelled order"), Times.Once);
    }

    [Fact]
    public async Task AdminUpdateStatus_ToCancelled_WhenAlreadyCancelled_ReturnsUnchangedAndNeverRestoresStock()
    {
        // Arrange: order already cancelled
        var orderId = Guid.NewGuid();
        var order = new Order
        {
            Id = orderId,
            PaymentMethod = PaymentMethod.Cod,
            PaymentStatus = PaymentStatus.Cancelled,
            Status = OrderStatus.Cancelled
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);

        // Act
        var result = await _orderService.UpdateOrderStatusAsync(orderId, CanonicalOrderStatus.Cancelled);

        // Assert: Unchanged, never double-restores stock
        Assert.NotNull(result);
        Assert.Equal(CanonicalOrderStatus.Cancelled, result.Status);
        _orderRepoMock.Verify(r => r.CancelOrderAndRestoreStockAsync(It.IsAny<Guid>(), It.IsAny<string>()), Times.Never);
    }

    // --- TEST ITEM 3: Payment Status Sync Shares Same Code Path as Webhook ---

    [Fact]
    public async Task GetPaymentStatus_WhenPayOSReportsPaid_MarksOrderPaidWithAmountValidation()
    {
        // Arrange
        var orderId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var orderCode = 1730000008888L;

        var order = new Order
        {
            Id = orderId,
            UserId = userId,
            PayOSOrderCode = orderCode,
            PaymentMethod = PaymentMethod.PayOS,
            PaymentStatus = PaymentStatus.Unpaid,
            Status = OrderStatus.Pending,
            TotalAmount = 500000m
        };

        var payLink = new PaymentLink
        {
            Id = "pl_8888",
            Status = PaymentLinkStatus.Paid,
            Amount = 500000,
            AmountPaid = 500000
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);
        _payOSServiceMock.Setup(p => p.GetPaymentLinkAsync(orderCode)).ReturnsAsync(payLink);

        // Act
        var result = await _orderService.GetPaymentStatusAsync(orderId, userId, isAdmin: false);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(CanonicalPaymentStatus.Paid, result.PaymentStatus);
        Assert.Equal(CanonicalOrderStatus.Confirmed, result.OrderStatus);
        Assert.Equal(PaymentStatus.Paid, order.PaymentStatus);
        Assert.NotNull(order.PaidAt);
        Assert.Contains("Thanh toán PayOS thành công qua payment_status_api", order.InternalNote);
        _orderRepoMock.Verify(r => r.UpdateOrderAsync(order), Times.Once);
    }

    // --- TEST ITEM 4: Server-side Shipping Fee Calculation & Price Recomputation ---

    [Fact]
    public async Task Checkout_ServerComputesShippingFee_IgnoresClientValue()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var cartItemId = Guid.NewGuid();
        var request = new CheckoutRequest
        {
            ShippingName = "Nguyen Van A",
            ShippingPhone = "0901234567",
            ShippingAddress = "123 Le Loi, Q1, HCM",
            PaymentMethod = PaymentMethod.Cod,
            SelectedCartItemIds = new List<Guid> { cartItemId },
            ShippingFee = 999999 // Client tries to spoof shipping fee
        };

        // Server computes flat fee 30,000 for subtotal 200,000 (total = 230,000)
        var createdOrder = new Order
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TotalAmount = 230000m,
            ShippingFee = 30000m,
            PaymentMethod = PaymentMethod.Cod,
            PaymentStatus = PaymentStatus.Unpaid,
            Status = OrderStatus.Pending,
            OrderItems = new List<OrderItem>
            {
                new OrderItem
                {
                    Id = Guid.NewGuid(),
                    ProductName = "Tai nghe Bluetooth",
                    Sku = "TN-BT-01",
                    UnitPrice = 200000m,
                    CostPrice = 150000m,
                    Quantity = 1
                }
            }
        };

        _orderRepoMock
            .Setup(r => r.CreateOrderWithTransactionAsync(
                userId,
                request,
                30000m,
                It.IsAny<long?>(),
                It.IsAny<string?>(),
                It.IsAny<string?>()))
            .ReturnsAsync(createdOrder);

        // Act
        var result = await _orderService.CheckoutAsync(userId, request);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(30000m, result.ShippingFee);
        Assert.Equal(230000m, result.TotalAmount);
        _orderRepoMock.Verify(r => r.CreateOrderWithTransactionAsync(
            userId,
            request,
            30000m,
            null,
            null,
            null), Times.Once);
    }

    [Fact]
    public async Task Checkout_PriceRecomputed_FromDatabaseNotClient()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var cartItemId = Guid.NewGuid();
        var request = new CheckoutRequest
        {
            ShippingName = "Nguyen Van A",
            ShippingPhone = "0901234567",
            ShippingAddress = "123 Le Loi, Q1, HCM",
            PaymentMethod = PaymentMethod.Cod,
            SelectedCartItemIds = new List<Guid> { cartItemId }
        };

        var expectedTotal = 25000000m;
        var createdOrder = new Order
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TotalAmount = 25030000m,
            ShippingFee = 30000m,
            PaymentMethod = PaymentMethod.Cod,
            PaymentStatus = PaymentStatus.Unpaid,
            Status = OrderStatus.Pending,
            OrderItems = new List<OrderItem>
            {
                new OrderItem
                {
                    Id = Guid.NewGuid(),
                    ProductName = "iPhone 15 Pro Max",
                    Sku = "IP15PM-256",
                    UnitPrice = 25000000m,
                    CostPrice = 20000000m,
                    Quantity = 1
                }
            }
        };

        _orderRepoMock
            .Setup(r => r.CreateOrderWithTransactionAsync(
                userId,
                request,
                It.IsAny<decimal>(),
                It.IsAny<long?>(),
                It.IsAny<string?>(),
                It.IsAny<string?>()))
            .ReturnsAsync(createdOrder);

        // Act
        var result = await _orderService.CheckoutAsync(userId, request);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(expectedTotal, result.TotalAmount);
        Assert.Equal(CanonicalPaymentStatus.Pending, result.PaymentStatus);
        Assert.Equal(CanonicalOrderStatus.Pending, result.OrderStatus);
    }

    [Fact]
    public async Task Checkout_InsufficientStock_ThrowsInvalidOperationException()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var request = new CheckoutRequest
        {
            ShippingName = "Nguyen Van B",
            ShippingPhone = "0909999999",
            ShippingAddress = "456 Tran Phu, Da Nang",
            PaymentMethod = PaymentMethod.Cod,
            SelectedCartItemIds = new List<Guid> { Guid.NewGuid() }
        };

        _orderRepoMock
            .Setup(r => r.CreateOrderWithTransactionAsync(
                userId,
                request,
                It.IsAny<decimal>(),
                It.IsAny<long?>(),
                It.IsAny<string?>(),
                It.IsAny<string?>()))
            .ThrowsAsync(new InvalidOperationException("Sản phẩm 'iPhone 15 Pro Max' không đủ số lượng tồn kho (còn 0, yêu cầu 1)."));

        // Act & Assert
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _orderService.CheckoutAsync(userId, request));

        Assert.Contains("không đủ số lượng tồn kho", ex.Message);
    }

    [Fact]
    public async Task Webhook_OrderAlreadyCancelled_RecordsPaidInInternalNote_CustomerNotePure()
    {
        // Arrange
        var orderCode = 1730000000999L;
        var webhook = new Webhook();
        var webhookData = new WebhookData
        {
            OrderCode = orderCode,
            Amount = 500000,
            Code = "00",
            Reference = "REF_LATE_PAYMENT"
        };

        const string customerNote = "Giao buổi chiều sau 17h";
        var cancelledOrder = new Order
        {
            Id = Guid.NewGuid(),
            PayOSOrderCode = orderCode,
            TotalAmount = 500000m,
            PaymentStatus = PaymentStatus.Cancelled,
            Status = OrderStatus.Cancelled,
            Note = customerNote,
            OrderItems = new List<OrderItem>()
        };

        _payOSServiceMock
            .Setup(p => p.VerifyWebhookDataAsync(webhook))
            .ReturnsAsync(webhookData);

        _orderRepoMock
            .Setup(r => r.GetOrderByOrderCodeAsync(orderCode))
            .ReturnsAsync(cancelledOrder);

        // Act
        var result = await _orderService.ProcessPayOSWebhookAsync(webhook);

        // Assert
        Assert.True(result);
        Assert.Equal(PaymentStatus.Paid, cancelledOrder.PaymentStatus);
        Assert.NotNull(cancelledOrder.PaidAt);
        Assert.Equal(customerNote, cancelledOrder.Note);
        Assert.Contains("paid after cancellation - needs manual refund/review", cancelledOrder.InternalNote);
        _orderRepoMock.Verify(r => r.UpdateOrderAsync(cancelledOrder), Times.Once);
    }

    [Fact]
    public async Task Webhook_Idempotent_AlreadyPaid_DoesNotDoubleProcess()
    {
        // Arrange
        var orderCode = 1730000000123L;
        var webhook = new Webhook();
        var webhookData = new WebhookData
        {
            OrderCode = orderCode,
            Amount = 500000,
            Code = "00",
            Reference = "REF123"
        };

        var existingOrder = new Order
        {
            Id = Guid.NewGuid(),
            PayOSOrderCode = orderCode,
            TotalAmount = 500000m,
            PaymentStatus = PaymentStatus.Paid,
            Status = OrderStatus.Processing
        };

        _payOSServiceMock
            .Setup(p => p.VerifyWebhookDataAsync(webhook))
            .ReturnsAsync(webhookData);

        _orderRepoMock
            .Setup(r => r.GetOrderByOrderCodeAsync(orderCode))
            .ReturnsAsync(existingOrder);

        // Act
        var result = await _orderService.ProcessPayOSWebhookAsync(webhook);

        // Assert
        Assert.True(result);
        _orderRepoMock.Verify(r => r.UpdateOrderAsync(It.IsAny<Order>()), Times.Never);
    }

    [Fact]
    public async Task Webhook_WrongAmount_RejectedAndMarkedFailed()
    {
        // Arrange
        var orderCode = 1730000000456L;
        var webhook = new Webhook();
        var webhookData = new WebhookData
        {
            OrderCode = orderCode,
            Amount = 100000,
            Code = "00",
            Reference = "REF456"
        };

        var existingOrder = new Order
        {
            Id = Guid.NewGuid(),
            PayOSOrderCode = orderCode,
            TotalAmount = 500000m,
            PaymentStatus = PaymentStatus.Unpaid,
            Status = OrderStatus.Pending
        };

        _payOSServiceMock
            .Setup(p => p.VerifyWebhookDataAsync(webhook))
            .ReturnsAsync(webhookData);

        _orderRepoMock
            .Setup(r => r.GetOrderByOrderCodeAsync(orderCode))
            .ReturnsAsync(existingOrder);

        // Act & Assert
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _orderService.ProcessPayOSWebhookAsync(webhook));

        Assert.Contains("không khớp với giá trị đơn hàng", ex.Message);
        Assert.Equal(PaymentStatus.Failed, existingOrder.PaymentStatus);
        _orderRepoMock.Verify(r => r.UpdateOrderAsync(existingOrder), Times.Once);
    }

    [Fact]
    public async Task CancelOrder_RestoresStock_WhenUnpaid()
    {
        // Arrange
        var orderId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var orderCode = 1730000000789L;

        var order = new Order
        {
            Id = orderId,
            UserId = userId,
            PayOSOrderCode = orderCode,
            PaymentMethod = PaymentMethod.PayOS,
            PaymentStatus = PaymentStatus.Unpaid,
            Status = OrderStatus.Pending,
            TotalAmount = 1000000m
        };

        _orderRepoMock
            .Setup(r => r.GetOrderByIdAsync(orderId))
            .ReturnsAsync(order);

        _orderRepoMock
            .Setup(r => r.CancelOrderAndRestoreStockAsync(orderId, It.IsAny<string>()))
            .ReturnsAsync(true);

        _payOSServiceMock
            .Setup(p => p.CancelPaymentLinkAsync(orderCode, It.IsAny<string>()))
            .ReturnsAsync(new PaymentLink());

        // Act
        var result = await _orderService.CancelOrderAsync(orderId, userId, isAdmin: false, reason: "Đổi ý");

        // Assert
        Assert.True(result);
        _payOSServiceMock.Verify(p => p.CancelPaymentLinkAsync(orderCode, "Đổi ý"), Times.Once);
        _orderRepoMock.Verify(r => r.CancelOrderAndRestoreStockAsync(orderId, "Đổi ý"), Times.Once);
    }

    [Fact]
    public async Task Webhook_EmptyBody_ReturnsTrue_DoesNotModifyOrder()
    {
        // Act: Empty body / ping from payOS
        var result = await _orderService.ProcessPayOSWebhookAsync(null);

        // Assert: 200 OK (true) and no order modified
        Assert.True(result);
        _payOSServiceMock.Verify(p => p.VerifyWebhookDataAsync(It.IsAny<Webhook>()), Times.Never);
        _orderRepoMock.Verify(r => r.UpdateOrderAsync(It.IsAny<Order>()), Times.Never);
    }

    [Fact]
    public async Task Webhook_InvalidSignature_ReturnsTrue_DoesNotModifyOrder()
    {
        // Arrange: webhook with invalid signature
        var webhook = new Webhook();
        _payOSServiceMock
            .Setup(p => p.VerifyWebhookDataAsync(webhook))
            .ThrowsAsync(new Exception("Invalid signature"));

        // Act
        var result = await _orderService.ProcessPayOSWebhookAsync(webhook);

        // Assert: 200 OK (true) and no order modified
        Assert.True(result);
        _orderRepoMock.Verify(r => r.GetOrderByOrderCodeAsync(It.IsAny<long>()), Times.Never);
        _orderRepoMock.Verify(r => r.UpdateOrderAsync(It.IsAny<Order>()), Times.Never);
    }

    [Fact]
    public async Task Webhook_UnknownOrderCode_LogsWarning_ReturnsTrue_DoesNotModifyOrder()
    {
        // Arrange: payOS validation ping with dummy orderCode (e.g. 123)
        var webhook = new Webhook();
        var webhookData = new WebhookData
        {
            OrderCode = 123L,
            Amount = 10000,
            Code = "00",
            Reference = "REF_VALIDATION_123"
        };

        _payOSServiceMock
            .Setup(p => p.VerifyWebhookDataAsync(webhook))
            .ReturnsAsync(webhookData);

        _orderRepoMock
            .Setup(r => r.GetOrderByOrderCodeAsync(123L))
            .ReturnsAsync((Order?)null);

        // Act
        var result = await _orderService.ProcessPayOSWebhookAsync(webhook);

        // Assert: returns true (200 OK) without modifying any order
        Assert.True(result);
        _orderRepoMock.Verify(r => r.UpdateOrderAsync(It.IsAny<Order>()), Times.Never);
    }

    [Fact]
    public async Task Webhook_ValidPayload_ExistingOrder_ProcessesSuccessfully()
    {
        // Arrange: valid signature and order exists
        var orderCode = 1730000005555L;
        var webhook = new Webhook();
        var webhookData = new WebhookData
        {
            OrderCode = orderCode,
            Amount = 750000,
            Code = "00",
            Reference = "REF_SUCCESS_555"
        };

        var order = new Order
        {
            Id = Guid.NewGuid(),
            PayOSOrderCode = orderCode,
            TotalAmount = 750000m,
            PaymentStatus = PaymentStatus.Unpaid,
            Status = OrderStatus.Pending
        };

        _payOSServiceMock
            .Setup(p => p.VerifyWebhookDataAsync(webhook))
            .ReturnsAsync(webhookData);

        _orderRepoMock
            .Setup(r => r.GetOrderByOrderCodeAsync(orderCode))
            .ReturnsAsync(order);

        // Act
        var result = await _orderService.ProcessPayOSWebhookAsync(webhook);

        // Assert: payment processed, order marked Paid and Confirmed (Processing)
        Assert.True(result);
        Assert.Equal(PaymentStatus.Paid, order.PaymentStatus);
        Assert.Equal(OrderStatus.Processing, order.Status);
        Assert.NotNull(order.PaidAt);
        _orderRepoMock.Verify(r => r.UpdateOrderAsync(order), Times.Once);
    }

    [Fact]
    public async Task CustomerCancel_CodOrderInShipping_ThrowsInvalidOperationException_NeverRestoresStock()
    {
        // Arrange: COD order already shipped
        var orderId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var order = new Order
        {
            Id = orderId,
            UserId = userId,
            PaymentMethod = PaymentMethod.Cod,
            PaymentStatus = PaymentStatus.Unpaid,
            Status = OrderStatus.Shipped, // In shipping
            TotalAmount = 500000m
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);

        // Act & Assert
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _orderService.CancelOrderAsync(orderId, userId, isAdmin: false));

        Assert.Contains("Không thể hủy đơn hàng đang trong quá trình giao hàng", ex.Message);
        _orderRepoMock.Verify(r => r.CancelOrderAndRestoreStockAsync(It.IsAny<Guid>(), It.IsAny<string>()), Times.Never);
    }

    [Theory]
    [InlineData(OrderStatus.Processing, "Không thể hủy đơn hàng đã được xác nhận")]
    [InlineData(OrderStatus.Delivered, "Không thể hủy đơn hàng đã hoàn thành")]
    [InlineData(OrderStatus.Cancelled, "Đơn hàng này đã bị hủy trước đó")]
    public async Task CustomerCancel_DisallowedOrderStatuses_ThrowsWithClearVietnameseMessage(OrderStatus status, string expectedMessagePart)
    {
        // Arrange
        var orderId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var order = new Order
        {
            Id = orderId,
            UserId = userId,
            PaymentMethod = PaymentMethod.PayOS,
            PaymentStatus = PaymentStatus.Unpaid,
            Status = status
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);

        // Act & Assert
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _orderService.CancelOrderAsync(orderId, userId, isAdmin: false));

        Assert.Contains(expectedMessagePart, ex.Message);
        _orderRepoMock.Verify(r => r.CancelOrderAndRestoreStockAsync(It.IsAny<Guid>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task CustomerCancel_PaidOrder_ThrowsWithClearVietnameseMessage()
    {
        // Arrange
        var orderId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var order = new Order
        {
            Id = orderId,
            UserId = userId,
            PaymentMethod = PaymentMethod.PayOS,
            PaymentStatus = PaymentStatus.Paid,
            Status = OrderStatus.Pending
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);

        // Act & Assert
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _orderService.CancelOrderAsync(orderId, userId, isAdmin: false));

        Assert.Contains("Không thể hủy đơn hàng đã thanh toán thành công", ex.Message);
        _orderRepoMock.Verify(r => r.CancelOrderAndRestoreStockAsync(It.IsAny<Guid>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task Webhook_FailureBranch_AlreadyPaidOrder_LeavesItPaid_NeverDowngrades()
    {
        // Arrange: webhook reports failure (code != "00") for an order that is already Paid
        var orderCode = 1730000009999L;
        var webhook = new Webhook();
        var webhookData = new WebhookData
        {
            OrderCode = orderCode,
            Amount = 500000,
            Code = "01", // Failure code
            Reference = "REF_FAIL"
        };

        var alreadyPaidOrder = new Order
        {
            Id = Guid.NewGuid(),
            PayOSOrderCode = orderCode,
            TotalAmount = 500000m,
            PaymentStatus = PaymentStatus.Paid, // Already paid!
            Status = OrderStatus.Processing
        };

        _payOSServiceMock
            .Setup(p => p.VerifyWebhookDataAsync(webhook))
            .ReturnsAsync(webhookData);

        _orderRepoMock
            .Setup(r => r.GetOrderByOrderCodeAsync(orderCode))
            .ReturnsAsync(alreadyPaidOrder);

        // Act
        var result = await _orderService.ProcessPayOSWebhookAsync(webhook);

        // Assert: returns true, order status is NOT downgraded, update is never called
        Assert.True(result);
        Assert.Equal(PaymentStatus.Paid, alreadyPaidOrder.PaymentStatus);
        _orderRepoMock.Verify(r => r.UpdateOrderAsync(It.IsAny<Order>()), Times.Never);
    }

    [Fact]
    public async Task AdminUpdateStatus_CodOrder_ToCompleted_SetsPaymentStatusPaidAndPaidAtNow()
    {
        // Arrange: COD order in Shipping
        var orderId = Guid.NewGuid();
        var order = new Order
        {
            Id = orderId,
            PaymentMethod = PaymentMethod.Cod,
            PaymentStatus = PaymentStatus.Unpaid,
            Status = OrderStatus.Shipped // Shipping
        };

        _orderRepoMock.Setup(r => r.GetOrderByIdAsync(orderId)).ReturnsAsync(order);
        _orderRepoMock.Setup(r => r.UpdateOrderAsync(It.IsAny<Order>())).Returns(Task.CompletedTask);

        // Act: Admin marks Completed
        var result = await _orderService.UpdateOrderStatusAsync(orderId, CanonicalOrderStatus.Completed);

        // Assert: PaymentStatus is Paid, PaidAt is now
        Assert.NotNull(result);
        Assert.Equal(CanonicalOrderStatus.Completed, result.Status);
        Assert.Equal(CanonicalPaymentStatus.Paid, result.PaymentStatus);
        Assert.NotNull(result.PaidAt);
        Assert.Equal(PaymentStatus.Paid, order.PaymentStatus);
        Assert.NotNull(order.PaidAt);
        _orderRepoMock.Verify(r => r.UpdateOrderAsync(order), Times.Once);
    }
}
