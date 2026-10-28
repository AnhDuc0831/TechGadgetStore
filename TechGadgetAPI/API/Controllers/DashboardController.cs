using System.Security.Claims;
using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;

namespace API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DashboardController : ControllerBase
{
    private readonly IDashboardService _dashboardService;
    private readonly IProfileService _profileService;
    private readonly ILogger<DashboardController> _logger;

    public DashboardController(
        IDashboardService dashboardService,
        IProfileService profileService,
        ILogger<DashboardController> logger)
    {
        _dashboardService = dashboardService;
        _profileService = profileService;
        _logger = logger;
    }

    /// <summary>
    /// Lấy toàn bộ dữ liệu thống kê tổng quan (KPI Summary, Biểu đồ Doanh thu/Lợi nhuận, Phân bố đơn hàng, Top SP, Cảnh báo tồn kho).
    /// </summary>
    /// <param name="query">Bộ lọc thời gian (today, 7days, 30days, this_month, this_year, all, custom) và ngưỡng lọc</param>
    [HttpGet("overview")]
    [ProducesResponseType(typeof(DashboardOverviewDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetOverview([FromQuery] DashboardQueryParams query)
    {
        // Kiểm tra quyền Admin nếu người dùng có gửi token xác thực
        var (isAuthorized, errorResult) = await VerifyAdminAccessAsync();
        if (!isAuthorized && errorResult != null)
        {
            return errorResult;
        }

        var result = await _dashboardService.GetOverviewAsync(query);
        return Ok(result);
    }

    /// <summary>
    /// Lấy nhanh 4 thẻ chỉ số KPI tổng quan (Doanh thu, Lợi nhuận, Đơn hàng, Sản phẩm tồn kho).
    /// </summary>
    [HttpGet("summary")]
    [ProducesResponseType(typeof(DashboardSummaryDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetSummary([FromQuery] DashboardQueryParams query)
    {
        var (isAuthorized, errorResult) = await VerifyAdminAccessAsync();
        if (!isAuthorized && errorResult != null) return errorResult;

        var result = await _dashboardService.GetOverviewAsync(query);
        return Ok(result.Summary);
    }

    /// <summary>
    /// Lấy dữ liệu biểu đồ Doanh thu và Lợi nhuận theo chuỗi thời gian liên tục.
    /// </summary>
    [HttpGet("revenue-chart")]
    [ProducesResponseType(typeof(List<RevenueProfitChartPointDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetRevenueChart([FromQuery] DashboardQueryParams query)
    {
        var (isAuthorized, errorResult) = await VerifyAdminAccessAsync();
        if (!isAuthorized && errorResult != null) return errorResult;

        var result = await _dashboardService.GetOverviewAsync(query);
        return Ok(result.ChartData);
    }

    /// <summary>
    /// Lấy danh sách Top sản phẩm bán chạy nhất.
    /// </summary>
    [HttpGet("top-products")]
    [ProducesResponseType(typeof(List<TopProductDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetTopProducts([FromQuery] DashboardQueryParams query)
    {
        var (isAuthorized, errorResult) = await VerifyAdminAccessAsync();
        if (!isAuthorized && errorResult != null) return errorResult;

        var result = await _dashboardService.GetOverviewAsync(query);
        return Ok(result.TopSellingProducts);
    }

    /// <summary>
    /// Lấy danh sách sản phẩm sắp hết hàng hoặc đã hết hàng.
    /// </summary>
    [HttpGet("low-stock")]
    [ProducesResponseType(typeof(List<LowStockItemDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetLowStockAlerts([FromQuery] DashboardQueryParams query)
    {
        var (isAuthorized, errorResult) = await VerifyAdminAccessAsync();
        if (!isAuthorized && errorResult != null) return errorResult;

        var result = await _dashboardService.GetOverviewAsync(query);
        return Ok(result.LowStockAlerts);
    }

    private async Task<(bool IsAuthorized, IActionResult? ErrorResult)> VerifyAdminAccessAsync()
    {
        // Nếu client có đính kèm Bearer Token, kiểm tra xem Profile trong DB có Role == admin hay không
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                       ?? User.FindFirst("sub")?.Value;

        if (!string.IsNullOrEmpty(userIdClaim) && Guid.TryParse(userIdClaim, out var userId))
        {
            var profile = await _profileService.GetProfileByIdAsync(userId);
            if (profile != null && !string.Equals(profile.Role, "admin", StringComparison.OrdinalIgnoreCase))
            {
                return (false, StatusCode(StatusCodes.Status403Forbidden, new
                {
                    message = "Chỉ tài khoản Quản trị viên (Admin) mới có quyền xem bảng điều khiển thống kê."
                }));
            }
        }

        return (true, null);
    }
}

