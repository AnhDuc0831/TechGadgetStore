using BusinessObjects.DTOs;
using BusinessObjects.Helpers;
using BusinessObjects.Models;
using Microsoft.AspNetCore.Http;
using Moq;
using Repositories.Interfaces;
using Services.Implementations;
using Services.Interfaces;
using Xunit;

namespace Services.Tests;

public class ReviewContentFilterTests
{
    [Theory]
    [InlineData("Máy dùng tốt, liên hệ mình 0912345678 nhé")]
    [InlineData("Zalo 0912 345 678")]
    [InlineData("gọi +84 912.345.678")]
    public void Rejects_PhoneNumbers(string comment)
    {
        Assert.Contains("số điện thoại", ReviewContentFilter.Validate(comment));
    }

    [Fact]
    public void Rejects_EmailAndLinks()
    {
        Assert.Contains("email", ReviewContentFilter.Validate("mail mình abc.def@gmail.com"));
        Assert.Contains("link", ReviewContentFilter.Validate("mua rẻ hơn tại https://abc.xyz"));
        Assert.Contains("link", ReviewContentFilter.Validate("vào shopre.vn mà mua"));
    }

    [Theory]
    [InlineData("Shop làm ăn vcl")]
    [InlineData("ĐM giao chậm")]
    [InlineData("what the fuck")]
    public void Rejects_Profanity_CaseInsensitive(string comment)
    {
        Assert.Contains("không phù hợp", ReviewContentFilter.Validate(comment));
    }

    [Theory]
    [InlineData("Máy đẹp, pin 5000mAh, giá 15.000.000đ rất đáng tiền")]
    [InlineData("Màn hình lớn, loa to, đĩa CD kèm theo")]
    [InlineData("Đóng gói kỹ, giao nhanh trong 2 ngày. 10/10!")]
    [InlineData("Cấu hình 16GB/512GB chạy mượt")]
    [InlineData(null)]
    [InlineData("   ")]
    public void Accepts_NormalReviews_WithoutFalsePositives(string? comment)
    {
        Assert.Null(ReviewContentFilter.Validate(comment));
    }

    [Fact]
    public void Rejects_SpamAndTooLong()
    {
        Assert.Contains("spam", ReviewContentFilter.Validate("tốtttttttttttttt"));
        Assert.Contains("1000", ReviewContentFilter.Validate(new string('a', 500) + " " + new string('b', 501)));
    }

    [Theory]
    [InlineData("Nguyễn Văn An", "Nguyễn V***")]
    [InlineData("an", "A***")]
    [InlineData("  Trần   thị  ", "Trần T***")]
    [InlineData(null, "Khách hàng")]
    [InlineData("", "Khách hàng")]
    public void MaskName_HidesFullName(string? input, string expected)
    {
        Assert.Equal(expected, ReviewContentFilter.MaskName(input));
    }
}

public class ReviewServiceTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 15, 3, 0, 0, TimeSpan.Zero);
    private readonly Mock<IReviewRepository> _repo = new();
    private readonly Mock<ICloudinaryService> _cloudinary = new();
    private readonly ReviewService _service;
    private readonly Guid _userId = Guid.NewGuid();
    private readonly Guid _productId = Guid.NewGuid();
    private readonly Guid _orderId = Guid.NewGuid();

    public ReviewServiceTests()
    {
        _repo.Setup(r => r.ProductExistsAsync(_productId)).ReturnsAsync(true);
        _repo.Setup(r => r.CountRecentSubmissionsAsync(_userId, It.IsAny<DateTimeOffset>())).ReturnsAsync(0);
        _service = new ReviewService(_repo.Object, _cloudinary.Object, new FixedTimeProvider(Now));
    }

    private void GivenPurchased() =>
        _repo.Setup(r => r.GetCompletedPurchaseAsync(_productId, _userId)).ReturnsAsync((_orderId, "IP15-256"));

    private static IFormFile Image(string name = "a.jpg", long size = 1000, string type = "image/jpeg")
    {
        var f = new Mock<IFormFile>();
        f.SetupGet(x => x.FileName).Returns(name);
        f.SetupGet(x => x.Length).Returns(size);
        f.SetupGet(x => x.ContentType).Returns(type);
        return f.Object;
    }

    // ---------------- QUYỀN ĐÁNH GIÁ ----------------

    [Fact]
    public async Task Submit_NotPurchased_IsRejected()
    {
        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.SubmitReviewAsync(_productId, _userId, new SubmitReviewRequest { Rating = 5 }));

        Assert.Contains("đã mua", ex.Message);
        _repo.Verify(r => r.AddAsync(It.IsAny<Review>()), Times.Never);
    }

    [Fact]
    public async Task Submit_OrderStillShipping_TellsCustomerToWait()
    {
        _repo.Setup(r => r.HasInProgressPurchaseAsync(_productId, _userId)).ReturnsAsync(true);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.SubmitReviewAsync(_productId, _userId, new SubmitReviewRequest { Rating = 5 }));

        Assert.Contains("giao thành công", ex.Message);
    }

    [Fact]
    public async Task Status_NotPurchased_CannotReview()
    {
        var status = await _service.GetMyReviewStatusAsync(_productId, _userId);
        Assert.False(status.CanReview);
        Assert.NotNull(status.Reason);
    }

    // ---------------- VALIDATION ----------------

    [Theory]
    [InlineData(0)]
    [InlineData(6)]
    public async Task Submit_InvalidRating_IsRejected(int rating)
    {
        GivenPurchased();
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.SubmitReviewAsync(_productId, _userId, new SubmitReviewRequest { Rating = rating }));
    }

    [Fact]
    public async Task Submit_ViolatingContent_IsRejected_BeforeUploadingImages()
    {
        GivenPurchased();
        var req = new SubmitReviewRequest { Rating = 1, Comment = "Gọi 0912345678", Images = new() { Image() } };

        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.SubmitReviewAsync(_productId, _userId, req));
        _cloudinary.Verify(c => c.UploadImagesAsync(It.IsAny<IEnumerable<IFormFile>>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task Submit_TooManyImages_IsRejected()
    {
        GivenPurchased();
        var req = new SubmitReviewRequest { Rating = 5, Images = Enumerable.Range(0, 6).Select(_ => Image()).ToList() };

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() => _service.SubmitReviewAsync(_productId, _userId, req));
        Assert.Contains("tối đa 5 ảnh", ex.Message);
    }

    [Theory]
    [InlineData("doc.pdf", 1000, "application/pdf")]
    [InlineData("big.jpg", 6 * 1024 * 1024, "image/jpeg")]
    [InlineData("virus.exe", 1000, "application/octet-stream")]
    public async Task Submit_InvalidImageFile_IsRejected(string name, long size, string type)
    {
        GivenPurchased();
        var req = new SubmitReviewRequest { Rating = 5, Images = new() { Image(name, size, type) } };
        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.SubmitReviewAsync(_productId, _userId, req));
    }

    [Fact]
    public async Task Submit_TooFrequent_IsRateLimited()
    {
        GivenPurchased();
        _repo.Setup(r => r.CountRecentSubmissionsAsync(_userId, Now - ReviewService.RateLimitWindow)).ReturnsAsync(5);

        var ex = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.SubmitReviewAsync(_productId, _userId, new SubmitReviewRequest { Rating = 5 }));
        Assert.Contains("quá nhanh", ex.Message);
    }

    // ---------------- TẠO & SỬA ----------------

    [Fact]
    public async Task Submit_FirstTime_CreatesVerifiedReview_WithUploadedImages()
    {
        GivenPurchased();
        _cloudinary.Setup(c => c.UploadImagesAsync(It.IsAny<IEnumerable<IFormFile>>(), "tech_gadgets/reviews"))
            .ReturnsAsync(new List<string> { "https://img/1.jpg" });
        Review? added = null;
        _repo.Setup(r => r.AddAsync(It.IsAny<Review>())).Callback<Review>(r => added = r).ReturnsAsync((Review r) => r);

        var dto = await _service.SubmitReviewAsync(_productId, _userId, new SubmitReviewRequest
        {
            Rating = 4, Comment = "  Máy tốt  ", Images = new() { Image() }
        });

        Assert.NotNull(added);
        Assert.Equal(_orderId, added!.OrderId);
        Assert.Equal("IP15-256", added.VariantSku);
        Assert.Equal("Máy tốt", added.Comment);
        Assert.Equal(new[] { "https://img/1.jpg" }, added.Images);
        Assert.True(dto.IsVerifiedPurchase);
        Assert.True(dto.IsMine);
        Assert.Null(dto.EditedAt);
    }

    [Fact]
    public async Task Submit_Again_UpdatesExisting_KeepsOnlyOwnImages_AndMarksEdited()
    {
        GivenPurchased();
        var existing = new Review
        {
            Id = Guid.NewGuid(), ProductId = _productId, UserId = _userId, Rating = 2, Comment = "Tạm",
            Images = new() { "https://img/old1.jpg", "https://img/old2.jpg" }, OrderId = _orderId, CreatedAt = Now.AddDays(-3)
        };
        _repo.Setup(r => r.GetUserReviewAsync(_productId, _userId)).ReturnsAsync(existing);

        var dto = await _service.SubmitReviewAsync(_productId, _userId, new SubmitReviewRequest
        {
            Rating = 5,
            Comment = "Dùng lâu thấy rất ổn",
            KeepImageUrls = new() { "https://img/old2.jpg", "https://evil.com/injected.jpg" }
        });

        Assert.Equal(5, existing.Rating);
        Assert.Equal(new[] { "https://img/old2.jpg" }, existing.Images); // ảnh lạ không thuộc đánh giá bị bỏ
        Assert.Equal(Now, existing.EditedAt);
        Assert.NotNull(dto.EditedAt);
        _repo.Verify(r => r.UpdateAsync(existing), Times.Once);
        _repo.Verify(r => r.AddAsync(It.IsAny<Review>()), Times.Never);
    }

    // ---------------- PUBLIC & ADMIN ----------------

    [Fact]
    public async Task ProductReviews_SummaryCountsEveryReview()
    {
        _repo.Setup(r => r.GetProductReviewsAsync(_productId, 1, 10, null, false))
            .ReturnsAsync((new List<Review>(), 0));
        _repo.Setup(r => r.GetSummaryAsync(_productId))
            .ReturnsAsync((new Dictionary<int, int> { [5] = 3, [1] = 1 }, 2));

        var result = await _service.GetProductReviewsAsync(_productId, new ReviewQueryParams(), null);

        Assert.Equal(4, result.Summary.TotalCount);
        Assert.Equal(4.0, result.Summary.AverageRating);       // (5*3 + 1) / 4 – đánh giá 1★ vẫn được tính
        Assert.Equal(new[] { "5", "4", "3", "2", "1" }, result.Summary.RatingCounts.Keys);
        Assert.Equal(1, result.Summary.RatingCounts["1"]);
        Assert.Equal(0, result.Summary.RatingCounts["3"]);
    }

    [Fact]
    public async Task AdminReply_OnlyChangesReply_NeverCustomerContent()
    {
        var review = new Review { Id = Guid.NewGuid(), ProductId = _productId, UserId = _userId, Rating = 1, Comment = "Tệ" };
        _repo.Setup(r => r.GetByIdAsync(review.Id)).ReturnsAsync(review);

        var dto = await _service.ReplyAsync(review.Id, "  Shop xin lỗi bạn  ");

        Assert.Equal("Shop xin lỗi bạn", dto.AdminReply);
        Assert.Equal(Now, review.RepliedAt);
        Assert.Equal(1, review.Rating);
        Assert.Equal("Tệ", review.Comment);

        await _service.ReplyAsync(review.Id, "   ");
        Assert.Null(review.AdminReply);
        Assert.Null(review.RepliedAt);
    }

    // ---------------- ẨN NỘI DUNG KHIẾM NHÃ ----------------

    private Review OffensiveReview() => new()
    {
        Id = Guid.NewGuid(), ProductId = _productId, UserId = _userId, Rating = 1,
        Comment = "Nội dung khiếm nhã", Images = new() { "https://img/bad.jpg" }, CreatedAt = Now.AddDays(-1)
    };

    [Fact]
    public async Task AdminHide_KeepsRatingAndOriginalContent_RecordsReason()
    {
        var review = OffensiveReview();
        _repo.Setup(r => r.GetByIdAsync(review.Id)).ReturnsAsync(review);

        var dto = await _service.SetContentHiddenAsync(review.Id, true, "  Ngôn từ khiếm nhã  ");

        Assert.True(review.ContentHidden);
        Assert.Equal("Ngôn từ khiếm nhã", review.HiddenReason);
        Assert.Equal(Now, review.HiddenAt);
        Assert.Equal(1, review.Rating);                       // số sao giữ nguyên
        Assert.Equal("Nội dung khiếm nhã", review.Comment);   // không xóa nội dung gốc
        Assert.Single(review.Images);
        // Admin vẫn xem được nội dung gốc + lý do
        Assert.True(dto.IsContentHidden);
        Assert.Equal("Nội dung khiếm nhã", dto.Comment);
        Assert.Equal("Ngôn từ khiếm nhã", dto.HiddenReason);
        _repo.Verify(r => r.UpdateAsync(review), Times.Once);
    }

    [Fact]
    public async Task AdminUnhide_ClearsReasonAndTimestamp()
    {
        var review = OffensiveReview();
        review.ContentHidden = true;
        review.HiddenReason = "Spam";
        review.HiddenAt = Now.AddHours(-1);
        _repo.Setup(r => r.GetByIdAsync(review.Id)).ReturnsAsync(review);

        var dto = await _service.SetContentHiddenAsync(review.Id, false, "bỏ qua");

        Assert.False(review.ContentHidden);
        Assert.Null(review.HiddenReason);
        Assert.Null(review.HiddenAt);
        Assert.False(dto.IsContentHidden);
    }

    [Fact]
    public async Task AdminHide_ReasonTooLong_IsRejected()
    {
        var review = OffensiveReview();
        _repo.Setup(r => r.GetByIdAsync(review.Id)).ReturnsAsync(review);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _service.SetContentHiddenAsync(review.Id, true, new string('x', ReviewService.MaxHiddenReasonLength + 1)));
        Assert.False(review.ContentHidden);
    }

    [Fact]
    public async Task AdminHide_UnknownReview_Throws()
    {
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.SetContentHiddenAsync(Guid.NewGuid(), true, null));
    }

    [Fact]
    public async Task ProductReviews_HiddenContent_IsMaskedForPublic_ButVisibleToAuthor()
    {
        var review = OffensiveReview();
        review.ContentHidden = true;
        review.HiddenReason = "Ngôn từ khiếm nhã";
        _repo.Setup(r => r.GetProductReviewsAsync(_productId, 1, 10, null, false))
            .ReturnsAsync((new List<Review> { review }, 1));
        _repo.Setup(r => r.GetSummaryAsync(_productId))
            .ReturnsAsync((new Dictionary<int, int> { [1] = 1 }, 0));

        // Người xem khác: không nhận được nội dung, ảnh hay lý do – nhưng vẫn thấy số sao
        var publicView = (await _service.GetProductReviewsAsync(_productId, new ReviewQueryParams(), Guid.NewGuid())).Reviews.Items.Single();
        Assert.True(publicView.IsContentHidden);
        Assert.Null(publicView.Comment);
        Assert.Empty(publicView.Images);
        Assert.Null(publicView.HiddenReason);
        Assert.Equal(1, publicView.Rating);

        // Khách chưa đăng nhập cũng vậy
        var anonymous = (await _service.GetProductReviewsAsync(_productId, new ReviewQueryParams(), null)).Reviews.Items.Single();
        Assert.Null(anonymous.Comment);

        // Chính người viết: thấy nội dung gốc + lý do để sửa lại
        var authorView = (await _service.GetProductReviewsAsync(_productId, new ReviewQueryParams(), _userId)).Reviews.Items.Single();
        Assert.Equal("Nội dung khiếm nhã", authorView.Comment);
        Assert.Equal("Ngôn từ khiếm nhã", authorView.HiddenReason);
    }

    [Fact]
    public async Task ProductReviews_HiddenReview_StillCountsInAverage()
    {
        _repo.Setup(r => r.GetProductReviewsAsync(_productId, 1, 10, null, false))
            .ReturnsAsync((new List<Review>(), 0));
        // Summary lấy theo mọi đánh giá, không lọc ContentHidden → 1★ bị ẩn nội dung vẫn kéo điểm xuống
        _repo.Setup(r => r.GetSummaryAsync(_productId))
            .ReturnsAsync((new Dictionary<int, int> { [5] = 1, [1] = 1 }, 0));

        var result = await _service.GetProductReviewsAsync(_productId, new ReviewQueryParams(), null);

        Assert.Equal(2, result.Summary.TotalCount);
        Assert.Equal(3.0, result.Summary.AverageRating);
    }

    [Fact]
    public async Task CustomerEdit_OfHiddenReview_UnhidesAutomatically()
    {
        GivenPurchased();
        var review = OffensiveReview();
        review.ContentHidden = true;
        review.HiddenReason = "Ngôn từ khiếm nhã";
        review.HiddenAt = Now.AddHours(-2);
        _repo.Setup(r => r.GetUserReviewAsync(_productId, _userId)).ReturnsAsync(review);

        var dto = await _service.SubmitReviewAsync(_productId, _userId,
            new SubmitReviewRequest { Rating = 2, Comment = "Sản phẩm chưa tốt như mong đợi" });

        Assert.False(review.ContentHidden);
        Assert.Null(review.HiddenReason);
        Assert.Null(review.HiddenAt);
        Assert.False(dto.IsContentHidden);
    }
}

public class ReviewImageFromMobileTests
{
    [Fact]
    public async Task Submit_OctetStreamWithImageExtension_IsAccepted()
    {
        var repo = new Mock<IReviewRepository>();
        var cloud = new Mock<ICloudinaryService>();
        var userId = Guid.NewGuid();
        var productId = Guid.NewGuid();
        repo.Setup(r => r.ProductExistsAsync(productId)).ReturnsAsync(true);
        repo.Setup(r => r.GetCompletedPurchaseAsync(productId, userId)).ReturnsAsync((Guid.NewGuid(), "SKU"));
        repo.Setup(r => r.AddAsync(It.IsAny<Review>())).ReturnsAsync((Review r) => r);
        cloud.Setup(c => c.UploadImagesAsync(It.IsAny<IEnumerable<IFormFile>>(), It.IsAny<string>()))
            .ReturnsAsync(new List<string> { "https://img/x.jpg" });

        var file = new Mock<IFormFile>();
        file.SetupGet(x => x.FileName).Returns("IMG_001.JPG");
        file.SetupGet(x => x.Length).Returns(2000);
        file.SetupGet(x => x.ContentType).Returns("application/octet-stream");

        var service = new ReviewService(repo.Object, cloud.Object);
        var dto = await service.SubmitReviewAsync(productId, userId, new SubmitReviewRequest { Rating = 5, Images = new() { file.Object } });

        Assert.Single(dto.Images);
    }
}
