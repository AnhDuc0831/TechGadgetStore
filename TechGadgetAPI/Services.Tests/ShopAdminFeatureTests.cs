using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using BusinessObjects.Helpers;
using BusinessObjects.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using Repositories.Interfaces;
using Services.Implementations;
using Services.Interfaces;
using Xunit;

namespace Services.Tests;

// =====================================================================
// DANH MỤC & THƯƠNG HIỆU
// =====================================================================

public class SlugHelperTests
{
    [Theory]
    [InlineData("Điện thoại & Máy tính bảng", "dien-thoai-may-tinh-bang")]
    [InlineData("  Phụ kiện  ", "phu-kien")]
    [InlineData("Đồng hồ thông minh", "dong-ho-thong-minh")]
    [InlineData("Laptop Gaming 2026", "laptop-gaming-2026")]
    [InlineData("!!!", "")]
    [InlineData(null, "")]
    public void Generate_RemovesVietnameseDiacritics(string? input, string expected)
    {
        Assert.Equal(expected, SlugHelper.Generate(input));
    }
}

public class CategoryServiceTests
{
    private readonly Mock<ICategoryRepository> _repo = new();
    private readonly Mock<ICloudinaryService> _cloud = new();
    private readonly CategoryService _service;

    public CategoryServiceTests()
    {
        _service = new CategoryService(_repo.Object, _cloud.Object);
    }

    private static IFormFile File(string name, string type, long size = 1000)
    {
        var f = new Mock<IFormFile>();
        f.SetupGet(x => x.FileName).Returns(name);
        f.SetupGet(x => x.ContentType).Returns(type);
        f.SetupGet(x => x.Length).Returns(size);
        return f.Object;
    }

    [Fact]
    public async Task Create_AutoGeneratesSlug_AndUploadsImage()
    {
        _cloud.Setup(c => c.UploadImageAsync(It.IsAny<IFormFile>(), "tech_gadgets/categories")).ReturnsAsync("https://img/c.png");
        Category? saved = null;
        _repo.Setup(r => r.AddAsync(It.IsAny<Category>())).Callback<Category>(c => saved = c).ReturnsAsync((Category c) => c);

        var dto = await _service.CreateCategoryAsync(new SaveCategoryRequest
        {
            Name = "  Đồng hồ thông minh ",
            ImageFile = File("a.png", "image/png")
        });

        Assert.Equal("Đồng hồ thông minh", saved!.Name);
        Assert.Equal("dong-ho-thong-minh", dto.Slug);
        Assert.Equal("https://img/c.png", dto.ImageUrl);
        Assert.Equal(0, dto.ProductCount);
    }

    [Fact]
    public async Task Create_DuplicateName_Throws()
    {
        _repo.Setup(r => r.NameExistsAsync("Laptop", null)).ReturnsAsync(true);
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.CreateCategoryAsync(new SaveCategoryRequest { Name = "Laptop" }));
        Assert.Contains("đã tồn tại", ex.Message);
    }

    [Fact]
    public async Task Create_DuplicateSlug_Throws()
    {
        _repo.Setup(r => r.SlugExistsAsync("laptop", null)).ReturnsAsync(true);
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.CreateCategoryAsync(new SaveCategoryRequest { Name = "Láptop" }));
    }

    [Fact]
    public async Task Create_EmptyName_Throws()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.CreateCategoryAsync(new SaveCategoryRequest { Name = "   " }));
    }

    [Fact]
    public async Task Create_NonImageFile_RejectedBeforeUpload()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.CreateCategoryAsync(new SaveCategoryRequest { Name = "Tai nghe", ImageFile = File("x.exe", "application/octet-stream") }));
        _cloud.Verify(c => c.UploadImageAsync(It.IsAny<IFormFile>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task Update_RemoveImage_ClearsImage_AndKeepsOwnSlugAllowed()
    {
        var id = Guid.NewGuid();
        var cat = new Category { Id = id, Name = "Laptop", Slug = "laptop", ImageUrl = "https://old.png" };
        _repo.Setup(r => r.GetByIdAsync(id)).ReturnsAsync(cat);
        _repo.Setup(r => r.CountProductsAsync(id)).ReturnsAsync(7);

        var dto = await _service.UpdateCategoryAsync(id, new SaveCategoryRequest { Name = "Laptop", RemoveImage = true });

        Assert.Null(dto.ImageUrl);
        Assert.Equal(7, dto.ProductCount);
        _repo.Verify(r => r.SlugExistsAsync("laptop", id), Times.Once); // loại trừ chính nó khi kiểm tra trùng
    }

    [Fact]
    public async Task Delete_WithProducts_IsBlocked()
    {
        var id = Guid.NewGuid();
        _repo.Setup(r => r.GetByIdAsync(id)).ReturnsAsync(new Category { Id = id, Name = "Laptop", Slug = "laptop" });
        _repo.Setup(r => r.CountProductsAsync(id)).ReturnsAsync(3);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => _service.DeleteCategoryAsync(id));
        Assert.Contains("3 sản phẩm", ex.Message);
        _repo.Verify(r => r.DeleteAsync(It.IsAny<Category>()), Times.Never);
    }

    [Fact]
    public async Task Delete_Empty_Succeeds()
    {
        var id = Guid.NewGuid();
        var cat = new Category { Id = id, Name = "Cũ", Slug = "cu" };
        _repo.Setup(r => r.GetByIdAsync(id)).ReturnsAsync(cat);

        await _service.DeleteCategoryAsync(id);
        _repo.Verify(r => r.DeleteAsync(cat), Times.Once);
    }
}

public class BrandServiceTests
{
    private readonly Mock<IBrandRepository> _repo = new();
    private readonly BrandService _service;

    public BrandServiceTests()
    {
        _service = new BrandService(_repo.Object, new Mock<ICloudinaryService>().Object);
    }

    [Fact]
    public async Task Create_DuplicateName_Throws()
    {
        _repo.Setup(r => r.NameExistsAsync("Apple", null)).ReturnsAsync(true);
        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.CreateBrandAsync(new SaveBrandRequest { Name = " Apple " }));
    }

    [Fact]
    public async Task Delete_WithProducts_IsBlocked()
    {
        var id = Guid.NewGuid();
        _repo.Setup(r => r.GetByIdAsync(id)).ReturnsAsync(new Brand { Id = id, Name = "Apple" });
        _repo.Setup(r => r.CountProductsAsync(id)).ReturnsAsync(12);

        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.DeleteBrandAsync(id));
        _repo.Verify(r => r.DeleteAsync(It.IsAny<Brand>()), Times.Never);
    }

    [Fact]
    public async Task Update_NotFound_Throws()
    {
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.UpdateBrandAsync(Guid.NewGuid(), new SaveBrandRequest { Name = "X" }));
    }
}

// =====================================================================
// CẬP NHẬT TRẠNG THÁI HÀNG LOẠT + THÔNG BÁO TỪ ORDER SERVICE
// =====================================================================

public class OrderBulkAndNotificationTests
{
    private readonly Mock<IOrderRepository> _repo = new();
    private readonly Mock<IPayOSService> _payos = new();
    private readonly Mock<INotificationService> _notify = new();
    private readonly OrderService _service;

    public OrderBulkAndNotificationTests()
    {
        _service = new OrderService(_repo.Object, _payos.Object,
            Options.Create(new ShippingOptions { FlatFee = 30000, FreeShippingThreshold = 0 }),
            new Mock<ILogger<OrderService>>().Object,
            _notify.Object);
    }

    private Order Given(OrderStatus status, PaymentMethod method = PaymentMethod.Cod)
    {
        var o = new Order { Id = Guid.NewGuid(), UserId = Guid.NewGuid(), Status = status, PaymentMethod = method, ShippingAddress = "{}" };
        _repo.Setup(r => r.GetOrderByIdAsync(o.Id)).ReturnsAsync(o);
        return o;
    }

    [Fact]
    public async Task Bulk_ProcessesEachOrderIndependently()
    {
        var pending1 = Given(OrderStatus.Pending);
        var pending2 = Given(OrderStatus.Pending);
        var completed = Given(OrderStatus.Completed);
        var missing = Guid.NewGuid();

        var result = await _service.BulkUpdateOrderStatusAsync(
            new[] { pending1.Id, completed.Id, pending2.Id, missing, pending1.Id /* trùng */ },
            CanonicalOrderStatus.Confirmed);

        Assert.Equal(4, result.Total);
        Assert.Equal(2, result.SuccessCount);
        Assert.Equal(2, result.FailedCount);
        Assert.Equal(CanonicalOrderStatus.Confirmed, OrderStatusMapper.ToCanonical(pending1.Status));
        Assert.Equal(CanonicalOrderStatus.Confirmed, OrderStatusMapper.ToCanonical(pending2.Status));
        Assert.Equal(OrderStatus.Completed, completed.Status); // không bị đổi
        Assert.Contains(result.Items, i => i.OrderId == completed.Id && !i.Success && i.Message!.Contains("Không thể chuyển"));
        Assert.Contains(result.Items, i => i.OrderId == missing && !i.Success);

        // Chỉ đơn thành công mới gửi thông báo cho khách
        _notify.Verify(n => n.OnOrderStatusChangedAsync(It.IsAny<Order>(), CanonicalOrderStatus.Confirmed, false), Times.Exactly(2));
    }

    [Fact]
    public async Task Bulk_EmptyOrTooMany_Throws()
    {
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.BulkUpdateOrderStatusAsync(Array.Empty<Guid>(), CanonicalOrderStatus.Confirmed));

        var tooMany = Enumerable.Range(0, OrderService.MaxBulkOrders + 1).Select(_ => Guid.NewGuid());
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.BulkUpdateOrderStatusAsync(tooMany, CanonicalOrderStatus.Confirmed));
    }

    [Fact]
    public async Task Bulk_Cancel_RestoresStockForEachOrder()
    {
        var a = Given(OrderStatus.Pending);
        var b = Given(OrderStatus.Confirmed);

        var result = await _service.BulkUpdateOrderStatusAsync(new[] { a.Id, b.Id }, CanonicalOrderStatus.Cancelled);

        Assert.Equal(2, result.SuccessCount);
        _repo.Verify(r => r.CancelOrderAndRestoreStockAsync(a.Id, It.IsAny<string>()), Times.Once);
        _repo.Verify(r => r.CancelOrderAndRestoreStockAsync(b.Id, It.IsAny<string>()), Times.Once);
    }

    [Fact]
    public async Task CodCheckout_NotifiesAdmins()
    {
        var userId = Guid.NewGuid();
        var request = new CheckoutRequest
        {
            ShippingName = "A", ShippingPhone = "0987654321", ShippingAddress = "HCM",
            PaymentMethod = PaymentMethod.Cod, SelectedCartItemIds = new() { Guid.NewGuid() }
        };
        var created = new Order { Id = Guid.NewGuid(), UserId = userId, PaymentMethod = PaymentMethod.Cod, TotalAmount = 100000, ShippingFee = 30000, ShippingAddress = "{}" };
        _repo.Setup(r => r.CreateOrderWithTransactionAsync(userId, request, 30000m, It.IsAny<long?>(), It.IsAny<string?>(), It.IsAny<string?>()))
            .ReturnsAsync(created);

        await _service.CheckoutAsync(userId, request);

        _notify.Verify(n => n.OnOrderPlacedAsync(created), Times.Once);
    }

    [Fact]
    public async Task CustomerCancel_NotifiesAdmins_WithReason()
    {
        var o = Given(OrderStatus.Pending);
        o.PaymentStatus = PaymentStatus.Unpaid;
        _repo.Setup(r => r.CancelOrderAndRestoreStockAsync(o.Id, It.IsAny<string>())).ReturnsAsync(true);

        await _service.CancelOrderAsync(o.Id, o.UserId!.Value, isAdmin: false, reason: "Đặt nhầm");

        _notify.Verify(n => n.OnOrderCancelledByCustomerAsync(o, "Đặt nhầm"), Times.Once);
    }

    [Fact]
    public async Task ConfirmReceived_NotifiesAdmins()
    {
        var o = Given(OrderStatus.Shipping);
        await _service.ConfirmReceivedAsync(o.Id, o.UserId!.Value);
        _notify.Verify(n => n.OnOrderReceivedAsync(o), Times.Once);
    }
}

public class NotificationServiceTests
{
    private readonly Mock<INotificationRepository> _repo = new();
    private readonly NotificationService _service;

    public NotificationServiceTests()
    {
        _service = new NotificationService(_repo.Object, new Mock<ILogger<NotificationService>>().Object);
    }

    private static Order SampleOrder() => new()
    {
        Id = Guid.NewGuid(), UserId = Guid.NewGuid(), ShippingName = "Nguyễn An", PaymentMethod = PaymentMethod.Cod,
        TotalAmount = 1_250_000m, ShippingAddress = "{}",
        OrderItems = new List<OrderItem> { new() { Quantity = 2 }, new() { Quantity = 1 } }
    };

    [Fact]
    public async Task NewOrder_IsSentToEveryAdmin()
    {
        var admins = new List<Guid> { Guid.NewGuid(), Guid.NewGuid() };
        _repo.Setup(r => r.GetAdminUserIdsAsync()).ReturnsAsync(admins);
        List<AppNotification>? sent = null;
        _repo.Setup(r => r.AddRangeAsync(It.IsAny<IEnumerable<AppNotification>>()))
            .Callback<IEnumerable<AppNotification>>(n => sent = n.ToList())
            .Returns(Task.CompletedTask);

        var order = SampleOrder();
        await _service.OnOrderPlacedAsync(order);

        Assert.Equal(2, sent!.Count);
        Assert.All(sent, n => Assert.Equal(NotificationTypes.NewOrder, n.Type));
        Assert.Equal(admins, sent.Select(n => n.UserId));
        Assert.Contains("Nguyễn An vừa đặt 3 sản phẩm · 1.250.000đ · COD", sent[0].Message);
        Assert.Equal(order.Id, sent[0].OrderId);
    }

    [Fact]
    public async Task StatusChange_IsSentToCustomer()
    {
        AppNotification? sent = null;
        _repo.Setup(r => r.AddRangeAsync(It.IsAny<IEnumerable<AppNotification>>()))
            .Callback<IEnumerable<AppNotification>>(n => sent = n.Single())
            .Returns(Task.CompletedTask);

        var order = SampleOrder();
        await _service.OnOrderStatusChangedAsync(order, CanonicalOrderStatus.Shipping);

        Assert.Equal(order.UserId, sent!.UserId);
        Assert.Contains("đang được giao", sent.Title);
    }

    [Fact]
    public async Task DatabaseFailure_NeverBreaksOrderFlow()
    {
        _repo.Setup(r => r.GetAdminUserIdsAsync()).ThrowsAsync(new Exception("relation \"notifications\" does not exist"));
        _repo.Setup(r => r.AddRangeAsync(It.IsAny<IEnumerable<AppNotification>>())).ThrowsAsync(new Exception("db down"));

        var order = SampleOrder();
        await _service.OnOrderPlacedAsync(order);            // không ném lỗi
        await _service.OnOrderPaidAsync(order);
        await _service.OnOrderStatusChangedAsync(order, CanonicalOrderStatus.Completed);
    }

    [Fact]
    public async Task MarkAsRead_SomeoneElsesNotification_NotFound()
    {
        _repo.Setup(r => r.ExistsForUserAsync(It.IsAny<Guid>(), It.IsAny<Guid>())).ReturnsAsync(false);
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.MarkAsReadAsync(Guid.NewGuid(), Guid.NewGuid()));
        _repo.Verify(r => r.MarkAsReadAsync(It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public void Code_UsesPayOSCodeOrShortId()
    {
        Assert.Equal("#123456", NotificationService.Code(new Order { PayOSOrderCode = 123456, ShippingAddress = "{}" }));
        var id = Guid.Parse("abcdef12-3456-7890-abcd-ef1234567890");
        Assert.Equal("#ABCDEF12", NotificationService.Code(new Order { Id = id, ShippingAddress = "{}" }));
    }
}
