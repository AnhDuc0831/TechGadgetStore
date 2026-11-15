using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using BusinessObjects.Helpers;
using BusinessObjects.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using Repositories.Interfaces;
using Services.Implementations;
using Services.Interfaces;
using Xunit;

namespace Services.Tests;

internal sealed class FixedTimeProvider : TimeProvider
{
    private readonly DateTimeOffset _now;
    public FixedTimeProvider(DateTimeOffset now) => _now = now;
    public override DateTimeOffset GetUtcNow() => _now;
}

public class VoucherCalculatorTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 15, 3, 0, 0, TimeSpan.Zero);

    private static Voucher Percent(decimal value, decimal? max = null, decimal min = 0) => new()
    {
        Code = "P", Name = "P", DiscountType = VoucherDiscountType.Percent, DiscountValue = value,
        MaxDiscount = max, MinOrderValue = min, IsActive = true,
        StartsAt = Now.AddDays(-1), EndsAt = Now.AddDays(1), TotalQuantity = 10
    };

    private static Voucher Fixed(decimal value, decimal min = 0) => new()
    {
        Code = "F", Name = "F", DiscountType = VoucherDiscountType.Fixed, DiscountValue = value,
        MinOrderValue = min, IsActive = true,
        StartsAt = Now.AddDays(-1), EndsAt = Now.AddDays(1), TotalQuantity = 10
    };

    [Fact]
    public void Percent_IsCappedByMaxDiscount()
    {
        Assert.Equal(200000m, VoucherCalculator.CalculateDiscount(Percent(10, max: 200000), 5_000_000m));
        Assert.Equal(100000m, VoucherCalculator.CalculateDiscount(Percent(10, max: 200000), 1_000_000m));
    }

    [Fact]
    public void Percent_RoundsDownToWholeDong()
    {
        // 7% * 123.457 = 8.641,99 → 8.641
        Assert.Equal(8641m, VoucherCalculator.CalculateDiscount(Percent(7), 123457m));
    }

    [Fact]
    public void Fixed_NeverExceedsSubtotal()
    {
        Assert.Equal(50000m, VoucherCalculator.CalculateDiscount(Fixed(50000), 1_000_000m));
        Assert.Equal(30000m, VoucherCalculator.CalculateDiscount(Fixed(50000), 30000m));
        Assert.Equal(0m, VoucherCalculator.CalculateDiscount(Fixed(50000), 0m));
    }

    [Fact]
    public void IneligibleReason_CoversAllRules()
    {
        Assert.Null(VoucherCalculator.GetIneligibleReason(Fixed(50000, min: 1_000_000), 1_000_000m, Now));
        Assert.Equal("Mua thêm 200.000đ để dùng voucher này.", VoucherCalculator.GetIneligibleReason(Fixed(50000, min: 1_000_000), 800_000m, Now));

        var expired = Fixed(50000); expired.EndsAt = Now.AddMinutes(-1);
        Assert.Equal("Voucher đã hết hạn.", VoucherCalculator.GetIneligibleReason(expired, 1_000_000m, Now));

        var upcoming = Fixed(50000); upcoming.StartsAt = Now.AddHours(1);
        Assert.StartsWith("Voucher có hiệu lực từ", VoucherCalculator.GetIneligibleReason(upcoming, 1_000_000m, Now));

        var disabled = Fixed(50000); disabled.IsActive = false;
        Assert.Equal("Voucher đã bị ngừng áp dụng.", VoucherCalculator.GetIneligibleReason(disabled, 1_000_000m, Now));
    }

    [Fact]
    public void NormalizeCode_TrimsAndUppercases()
    {
        Assert.Equal("TECH50K", VoucherCalculator.NormalizeCode("  tech50k "));
    }
}

public class VoucherServiceTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 15, 3, 0, 0, TimeSpan.Zero);
    private readonly Mock<IVoucherRepository> _repo = new();
    private readonly VoucherService _service;
    private readonly Guid _userId = Guid.NewGuid();

    public VoucherServiceTests()
    {
        _repo.Setup(r => r.GetUsedCountsAsync(It.IsAny<IEnumerable<Guid>>())).ReturnsAsync(new Dictionary<Guid, int>());
        _service = new VoucherService(_repo.Object, new FixedTimeProvider(Now));
    }

    private static Voucher Running(int total = 10, int claimed = 0) => new()
    {
        Id = Guid.NewGuid(), Code = "TECH50K", Name = "Giảm 50K", DiscountType = VoucherDiscountType.Fixed,
        DiscountValue = 50000, MinOrderValue = 1_000_000, TotalQuantity = total, ClaimedCount = claimed,
        StartsAt = Now.AddDays(-1), EndsAt = Now.AddDays(10), IsActive = true, IsPublic = true
    };

    private static CreateVoucherRequest ValidRequest() => new()
    {
        Code = "tech50k", Name = "Giảm 50K", DiscountType = "fixed", DiscountValue = 50000,
        MinOrderValue = 1_000_000, TotalQuantity = 100, StartsAt = Now, EndsAt = Now.AddDays(30)
    };

    // ---------------- CLAIM ----------------

    [Fact]
    public async Task Claim_Success_ReturnsAvailableWalletItem()
    {
        var v = Running();
        _repo.Setup(r => r.GetByIdAsync(v.Id)).ReturnsAsync(v);
        _repo.Setup(r => r.HasClaimedAsync(v.Id, _userId)).ReturnsAsync(false);
        _repo.Setup(r => r.ClaimAsync(v.Id, _userId, Now)).ReturnsAsync(new UserVoucher
        {
            Id = Guid.NewGuid(), VoucherId = v.Id, UserId = _userId, Status = UserVoucherStatus.Available, ClaimedAt = Now
        });

        var result = await _service.ClaimVoucherAsync(v.Id, _userId);

        Assert.Equal("available", result.Status);
        Assert.Equal("TECH50K", result.Code);
    }

    [Fact]
    public async Task Claim_AlreadyClaimed_Throws()
    {
        var v = Running();
        _repo.Setup(r => r.GetByIdAsync(v.Id)).ReturnsAsync(v);
        _repo.Setup(r => r.HasClaimedAsync(v.Id, _userId)).ReturnsAsync(true);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => _service.ClaimVoucherAsync(v.Id, _userId));
        Assert.Contains("đã lưu", ex.Message);
        _repo.Verify(r => r.ClaimAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<DateTimeOffset>()), Times.Never);
    }

    [Fact]
    public async Task Claim_OutOfStock_Throws()
    {
        var v = Running(total: 5, claimed: 5);
        _repo.Setup(r => r.GetByIdAsync(v.Id)).ReturnsAsync(v);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => _service.ClaimVoucherAsync(v.Id, _userId));
        Assert.Contains("hết lượt", ex.Message);
    }

    [Fact]
    public async Task Claim_LostRaceForLastSlot_Throws()
    {
        var v = Running(total: 5, claimed: 4);
        _repo.Setup(r => r.GetByIdAsync(v.Id)).ReturnsAsync(v);
        _repo.Setup(r => r.ClaimAsync(v.Id, _userId, Now)).ReturnsAsync((UserVoucher?)null);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => _service.ClaimVoucherAsync(v.Id, _userId));
        Assert.Contains("hết lượt", ex.Message);
    }

    [Fact]
    public async Task Claim_Expired_Throws()
    {
        var v = Running(); v.EndsAt = Now.AddSeconds(-1);
        _repo.Setup(r => r.GetByIdAsync(v.Id)).ReturnsAsync(v);

        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.ClaimVoucherAsync(v.Id, _userId));
    }

    [Fact]
    public async Task ClaimByCode_NormalizesCode_AndUnknownCodeIsNotFound()
    {
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.ClaimVoucherByCodeAsync(" nope ", _userId));
        _repo.Verify(r => r.GetByCodeAsync("NOPE"), Times.Once);
    }

    // ---------------- WALLET ----------------

    [Fact]
    public async Task MyVouchers_WithSubtotal_ComputesApplicabilityAndStatus()
    {
        var running = Running();
        var expired = Running(); expired.EndsAt = Now.AddDays(-1);
        var usedOne = Running();

        _repo.Setup(r => r.GetUserVouchersAsync(_userId)).ReturnsAsync(new List<UserVoucher>
        {
            new() { Id = Guid.NewGuid(), Voucher = expired, VoucherId = expired.Id, Status = UserVoucherStatus.Available },
            new() { Id = Guid.NewGuid(), Voucher = usedOne, VoucherId = usedOne.Id, Status = UserVoucherStatus.Used, DiscountAmount = 50000 },
            new() { Id = Guid.NewGuid(), Voucher = running, VoucherId = running.Id, Status = UserVoucherStatus.Available },
        });

        var result = await _service.GetMyVouchersAsync(_userId, subtotal: 1_200_000m);

        Assert.Equal(3, result.Count);
        Assert.Equal("available", result[0].Status);            // dùng được → lên đầu
        Assert.True(result[0].IsApplicable);
        Assert.Equal(50000m, result[0].EstimatedDiscount);
        Assert.Contains(result, x => x.Status == "expired" && x.IsApplicable == false);
        Assert.Contains(result, x => x.Status == "used" && x.UsedDiscountAmount == 50000m);
    }

    [Fact]
    public async Task MyVouchers_BelowMinOrder_NotApplicableWithReason()
    {
        var v = Running();
        _repo.Setup(r => r.GetUserVouchersAsync(_userId)).ReturnsAsync(new List<UserVoucher>
        {
            new() { Id = Guid.NewGuid(), Voucher = v, VoucherId = v.Id, Status = UserVoucherStatus.Available }
        });

        var result = await _service.GetMyVouchersAsync(_userId, subtotal: 800_000m);

        Assert.False(result[0].IsApplicable);
        Assert.Null(result[0].EstimatedDiscount);
        Assert.StartsWith("Mua thêm", result[0].IneligibleReason);
    }

    // ---------------- ADMIN ----------------

    [Fact]
    public async Task Create_NormalizesCode_AndDropsMaxDiscountForFixed()
    {
        var req = ValidRequest(); req.MaxDiscount = 999;
        Voucher? saved = null;
        _repo.Setup(r => r.AddAsync(It.IsAny<Voucher>())).Callback<Voucher>(v => saved = v).ReturnsAsync((Voucher v) => v);

        var dto = await _service.CreateVoucherAsync(req);

        Assert.Equal("TECH50K", dto.Code);
        Assert.Null(saved!.MaxDiscount);
        Assert.Equal("running", dto.DisplayStatus);
    }

    [Fact]
    public async Task Create_DuplicateCode_Throws()
    {
        _repo.Setup(r => r.CodeExistsAsync("TECH50K", null)).ReturnsAsync(true);
        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.CreateVoucherAsync(ValidRequest()));
    }

    [Theory]
    [InlineData("percent", 150, 0)]   // > 100%
    [InlineData("bogus", 10, 0)]      // loại không hợp lệ
    [InlineData("fixed", 10, -1)]     // kết thúc trước bắt đầu
    public async Task Create_InvalidInput_Throws(string type, decimal value, int endOffsetDays)
    {
        var req = ValidRequest();
        req.DiscountType = type;
        req.DiscountValue = value;
        if (endOffsetDays < 0) req.EndsAt = req.StartsAt.AddDays(endOffsetDays);

        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.CreateVoucherAsync(req));
    }

    [Fact]
    public async Task Update_ClaimedVoucher_CannotChangeDiscountValue()
    {
        var v = Running(claimed: 3);
        _repo.Setup(r => r.GetByIdAsync(v.Id)).ReturnsAsync(v);
        var req = new UpdateVoucherRequest
        {
            Code = v.Code, Name = v.Name, DiscountType = v.DiscountType, DiscountValue = 80000,
            MinOrderValue = v.MinOrderValue, TotalQuantity = 10, StartsAt = v.StartsAt, EndsAt = v.EndsAt
        };

        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.UpdateVoucherAsync(v.Id, req));
        _repo.Verify(r => r.UpdateAsync(It.IsAny<Voucher>()), Times.Never);
    }

    [Fact]
    public async Task Update_ClaimedVoucher_CanExtendTimeAndQuantity_ButNotBelowClaimed()
    {
        var v = Running(total: 10, claimed: 3);
        _repo.Setup(r => r.GetByIdAsync(v.Id)).ReturnsAsync(v);
        var req = new UpdateVoucherRequest
        {
            Code = v.Code, Name = "Tên mới", DiscountType = v.DiscountType, DiscountValue = v.DiscountValue,
            MinOrderValue = v.MinOrderValue, TotalQuantity = 50, StartsAt = v.StartsAt, EndsAt = v.EndsAt.AddDays(7)
        };

        var dto = await _service.UpdateVoucherAsync(v.Id, req);
        Assert.Equal(50, dto.TotalQuantity);
        Assert.Equal("Tên mới", dto.Name);

        req.TotalQuantity = 2;
        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.UpdateVoucherAsync(v.Id, req));
    }

    [Fact]
    public async Task Delete_ClaimedVoucher_Throws()
    {
        var v = Running(claimed: 1);
        _repo.Setup(r => r.GetByIdAsync(v.Id)).ReturnsAsync(v);

        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.DeleteVoucherAsync(v.Id));
        _repo.Verify(r => r.DeleteAsync(It.IsAny<Voucher>()), Times.Never);
    }
}

public class OrderServiceVoucherCheckoutTests
{
    [Fact]
    public async Task Checkout_WithVoucher_FreeShippingUsesSubtotalBeforeDiscount()
    {
        // Tiền hàng 520.000 (≥ ngưỡng freeship 500.000), voucher giảm 50.000 → vẫn được freeship
        var repo = new Mock<IOrderRepository>();
        var payos = new Mock<IPayOSService>();
        var service = new OrderService(repo.Object, payos.Object,
            Options.Create(new ShippingOptions { FlatFee = 30000, FreeShippingThreshold = 500000 }),
            new Mock<ILogger<OrderService>>().Object);

        var userId = Guid.NewGuid();
        var request = new CheckoutRequest
        {
            ShippingName = "A", ShippingPhone = "0987654321", ShippingAddress = "HCM",
            PaymentMethod = PaymentMethod.Cod, SelectedCartItemIds = new() { Guid.NewGuid() },
            UserVoucherId = Guid.NewGuid()
        };

        var created = new Order
        {
            Id = Guid.NewGuid(), UserId = userId, PaymentMethod = PaymentMethod.Cod,
            Subtotal = 520000m, DiscountAmount = 50000m, VoucherCode = "TECH50K",
            ShippingFee = 30000m, TotalAmount = 520000m - 50000m + 30000m, ShippingAddress = "{}"
        };

        repo.Setup(r => r.CreateOrderWithTransactionAsync(userId, request, 30000m,
                It.IsAny<long?>(), It.IsAny<string?>(), It.IsAny<string?>()))
            .ReturnsAsync(created);

        var result = await service.CheckoutAsync(userId, request);

        Assert.Equal(0m, result.ShippingFee);
        Assert.Equal(470000m, result.TotalAmount);
        Assert.Equal(50000m, result.DiscountAmount);
        Assert.Equal("TECH50K", result.VoucherCode);
        Assert.Equal(520000m, result.Order!.Subtotal);
    }

    [Fact]
    public async Task Checkout_PayOS_WithVoucher_SendsDiscountedAmount()
    {
        var repo = new Mock<IOrderRepository>();
        var payos = new Mock<IPayOSService>();
        var service = new OrderService(repo.Object, payos.Object,
            Options.Create(new ShippingOptions { FlatFee = 30000, FreeShippingThreshold = 0 }),
            new Mock<ILogger<OrderService>>().Object);

        var userId = Guid.NewGuid();
        var request = new CheckoutRequest
        {
            ShippingName = "A", ShippingPhone = "0987654321", ShippingAddress = "HCM",
            PaymentMethod = PaymentMethod.PayOS, SelectedCartItemIds = new() { Guid.NewGuid() },
            UserVoucherId = Guid.NewGuid()
        };

        var created = new Order
        {
            Id = Guid.NewGuid(), UserId = userId, PaymentMethod = PaymentMethod.PayOS,
            Subtotal = 1_000_000m, DiscountAmount = 100_000m, ShippingFee = 30000m,
            TotalAmount = 930_000m, ShippingAddress = "{}",
            OrderItems = new List<OrderItem> { new() { Id = Guid.NewGuid(), ProductName = "Laptop", Sku = "L1", UnitPrice = 1_000_000m, Quantity = 1 } }
        };

        repo.Setup(r => r.CreateOrderWithTransactionAsync(userId, request, 30000m,
                It.IsAny<long?>(), It.IsAny<string?>(), It.IsAny<string?>()))
            .ReturnsAsync(created);

        await Assert.ThrowsAnyAsync<Exception>(async () =>
        {
            // PayOS mock trả null → service sẽ lỗi sau khi đã gọi CreatePaymentLinkAsync; ta chỉ cần kiểm tra amount
            await service.CheckoutAsync(userId, request);
        });

        payos.Verify(p => p.CreatePaymentLinkAsync(
            It.IsAny<long>(), 930_000, It.IsAny<string>(), It.IsAny<List<PayOS.Models.V2.PaymentRequests.PaymentLinkItem>>(),
            It.IsAny<string?>(), It.IsAny<string?>(), It.IsAny<string?>()), Times.Once);
    }
}
