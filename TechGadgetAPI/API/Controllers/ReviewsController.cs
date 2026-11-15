using BusinessObjects.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;
using System.Security.Claims;

namespace API.Controllers;

/// <summary>
/// Đánh giá sản phẩm (phía khách hàng).
/// Shop không có API ẩn/xóa đánh giá – chỉ có API phản hồi công khai (AdminReviewsController).
/// </summary>
[ApiController]
public class ReviewsController : ControllerBase
{
    private readonly IReviewService _reviewService;
    private readonly ILogger<ReviewsController> _logger;

    public ReviewsController(IReviewService reviewService, ILogger<ReviewsController> logger)
    {
        _reviewService = reviewService;
        _logger = logger;
    }

    private Guid? CurrentUserId
    {
        get
        {
            var sub = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
            return Guid.TryParse(sub, out var id) ? id : null;
        }
    }

    /// <summary>
    /// Công khai: danh sách đánh giá của sản phẩm + thống kê sao.
    /// Lọc: ?rating=1..5, ?hasImages=true. Phân trang: ?page=1&amp;pageSize=10
    /// </summary>
    [HttpGet("api/products/{productId:guid}/reviews")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(ProductReviewsResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetProductReviews(Guid productId, [FromQuery] ReviewQueryParams query)
    {
        try
        {
            return Ok(await _reviewService.GetProductReviewsAsync(productId, query, CurrentUserId));
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    /// <summary>
    /// Khách: kiểm tra mình có được đánh giá sản phẩm này không, kèm đánh giá cũ (nếu có) để sửa.
    /// </summary>
    [HttpGet("api/products/{productId:guid}/reviews/me")]
    [Authorize]
    [ProducesResponseType(typeof(MyReviewStatusDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetMyReviewStatus(Guid productId)
    {
        if (CurrentUserId is not { } userId) return Unauthorized();
        return Ok(await _reviewService.GetMyReviewStatusAsync(productId, userId));
    }

    /// <summary>
    /// Khách: gửi mới hoặc cập nhật đánh giá (multipart/form-data).
    /// Fields: Rating (1-5), Comment, Images (tối đa 5 ảnh, mỗi ảnh ≤ 5MB), KeepImageUrls (ảnh cũ muốn giữ khi sửa).
    /// </summary>
    [HttpPost("api/products/{productId:guid}/reviews")]
    [Authorize]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(30_000_000)]
    [ProducesResponseType(typeof(ReviewDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> SubmitReview(Guid productId, [FromForm] SubmitReviewRequest request)
    {
        if (CurrentUserId is not { } userId) return Unauthorized();

        try
        {
            return Ok(await _reviewService.SubmitReviewAsync(productId, userId, request));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi gửi đánh giá sản phẩm {ProductId} của user {UserId}", productId, userId);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "Không thể gửi đánh giá, vui lòng thử lại." });
        }
    }

    /// <summary>
    /// Khách: các sản phẩm đã mua (đơn hoàn thành) nhưng chưa đánh giá.
    /// </summary>
    [HttpGet("api/reviews/pending")]
    [Authorize]
    [ProducesResponseType(typeof(List<PendingReviewItemDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPendingReviews()
    {
        if (CurrentUserId is not { } userId) return Unauthorized();
        return Ok(await _reviewService.GetPendingReviewsAsync(userId));
    }
}
