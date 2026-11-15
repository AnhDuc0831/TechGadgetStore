using BusinessObjects.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;
using System.Security.Claims;

namespace API.Controllers;

/// <summary>
/// Admin: Xem, phản hồi & ẩn nội dung khiếm nhã của đánh giá.
/// Thiết kế có chủ đích: KHÔNG có API xóa hay sửa đánh giá của khách. Admin chỉ ẩn được phần nội dung
/// (bình luận + ảnh); số sao luôn hiển thị và luôn tính vào điểm trung bình để đảm bảo minh bạch.
/// </summary>
[ApiController]
[Authorize]
[Route("api/admin/reviews")]
public class AdminReviewsController : ControllerBase
{
    private readonly IReviewService _reviewService;
    private readonly IProfileService _profileService;
    private readonly ILogger<AdminReviewsController> _logger;

    public AdminReviewsController(
        IReviewService reviewService,
        IProfileService profileService,
        ILogger<AdminReviewsController> logger)
    {
        _reviewService = reviewService;
        _profileService = profileService;
        _logger = logger;
    }

    private async Task<(bool IsAdmin, IActionResult? ErrorResult)> VerifyAdminAsync()
    {
        var userIdClaim = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
        if (!Guid.TryParse(userIdClaim, out var userId))
        {
            return (false, Unauthorized());
        }

        var profile = await _profileService.GetProfileByIdAsync(userId);
        if (profile == null || !string.Equals(profile.Role, "admin", StringComparison.OrdinalIgnoreCase))
        {
            return (false, StatusCode(StatusCodes.Status403Forbidden, new
            {
                message = "Chỉ tài khoản Quản trị viên (Admin) mới có quyền quản lý đánh giá."
            }));
        }

        return (true, null);
    }

    /// <summary>
    /// Admin: danh sách đánh giá. Mặc định ưu tiên đánh giá CHƯA phản hồi và SAO THẤP lên đầu.
    /// Lọc: ?rating=1..5, ?hasReply=true|false, ?search=tên sản phẩm hoặc nội dung
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<AdminReviewDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetReviews([FromQuery] AdminReviewQueryParams query)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        return Ok(await _reviewService.GetAdminReviewsAsync(query));
    }

    /// <summary>
    /// Admin: phản hồi công khai một đánh giá. Gửi reply rỗng để gỡ phản hồi.
    /// </summary>
    [HttpPut("{id:guid}/reply")]
    [ProducesResponseType(typeof(AdminReviewDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Reply(Guid id, [FromBody] ReplyReviewRequest request)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        try
        {
            return Ok(await _reviewService.ReplyAsync(id, request.Reply));
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
            _logger.LogError(ex, "Lỗi khi phản hồi đánh giá {ReviewId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "Không thể lưu phản hồi." });
        }
    }

    /// <summary>
    /// Admin: ẩn / hiện NỘI DUNG (bình luận + ảnh) của đánh giá khiếm nhã.
    /// Số sao vẫn hiển thị và vẫn tính điểm trung bình; nội dung gốc không bị xóa.
    /// Body: { "hidden": true, "reason": "Ngôn từ khiếm nhã" }
    /// </summary>
    [HttpPut("{id:guid}/visibility")]
    [ProducesResponseType(typeof(AdminReviewDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> SetVisibility(Guid id, [FromBody] SetReviewContentVisibilityRequest request)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        try
        {
            return Ok(await _reviewService.SetContentHiddenAsync(id, request.Hidden, request.Reason));
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
            _logger.LogError(ex, "Lỗi khi ẩn/hiện đánh giá {ReviewId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "Không thể cập nhật trạng thái đánh giá." });
        }
    }
}
