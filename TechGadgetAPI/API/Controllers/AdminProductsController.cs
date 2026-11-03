using BusinessObjects.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;
using System.Security.Claims;

namespace API.Controllers;

[ApiController]
[Authorize]
[Route("api/admin/products")]
public class AdminProductsController : ControllerBase
{
    private readonly IProductService _productService;
    private readonly IProfileService _profileService;
    private readonly ILogger<AdminProductsController> _logger;

    public AdminProductsController(
        IProductService productService,
        IProfileService profileService,
        ILogger<AdminProductsController> logger)
    {
        _productService = productService;
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
                message = "Chỉ tài khoản Quản trị viên (Admin) mới có quyền truy cập."
            }));
        }

        return (true, null);
    }

    /// <summary>
    /// Admin: Lấy danh sách sản phẩm phân trang, tìm kiếm theo tên, lọc theo danh mục, thương hiệu, trạng thái kinh doanh/ẩn.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<ProductListItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetProducts([FromQuery] AdminProductQueryParams query)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        var result = await _productService.GetAdminProductsAsync(query);
        return Ok(result);
    }

    /// <summary>
    /// Admin: Lấy chi tiết sản phẩm theo Id (kể cả sản phẩm đang bị ẩn).
    /// </summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(ProductDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetProductById(Guid id)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        var product = await _productService.GetAdminProductByIdAsync(id);
        if (product == null)
        {
            return NotFound(new { message = $"Không tìm thấy sản phẩm có ID: {id}" });
        }

        return Ok(product);
    }

    /// <summary>
    /// Admin: Đăng sản phẩm mới lên hệ thống, tự động upload ảnh lên Cloudinary và tạo biến thể mặc định.
    /// </summary>
    [HttpPost]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(ProductDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> CreateProduct([FromForm] CreateProductRequest request)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var created = await _productService.CreateProductAsync(request);
            return Ok(created);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi đăng sản phẩm mới '{Name}'", request.Name);
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = ex.Message ?? "Đã xảy ra lỗi trong quá trình tạo sản phẩm."
            });
        }
    }

    /// <summary>
    /// Admin: Cập nhật thông tin sản phẩm, cập nhật kho, ảnh và biến thể mặc định.
    /// </summary>
    [HttpPut("{id:guid}")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(ProductDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateProduct(Guid id, [FromForm] UpdateProductRequest request)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var updated = await _productService.UpdateProductAsync(id, request);
            return Ok(updated);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi khi cập nhật sản phẩm có ID: {Id}", id);
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = ex.Message ?? "Đã xảy ra lỗi trong quá trình cập nhật sản phẩm."
            });
        }
    }

    /// <summary>
    /// Admin: Xoá mềm sản phẩm (ẩn khỏi cửa hàng, chuyển IsActive = false).
    /// </summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> SoftDeleteProduct(Guid id)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        var success = await _productService.SoftDeleteProductAsync(id);
        if (!success)
        {
            return NotFound(new { message = $"Không tìm thấy sản phẩm có ID: {id}" });
        }

        return Ok(new { message = "Đã ẩn sản phẩm thành công (xoá mềm)." });
    }

    /// <summary>
    /// Admin: Khôi phục sản phẩm đã xoá mềm (chuyển IsActive = true).
    /// </summary>
    [HttpPatch("{id:guid}/restore")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RestoreProduct(Guid id)
    {
        var (isAdmin, error) = await VerifyAdminAsync();
        if (!isAdmin) return error!;

        var success = await _productService.RestoreProductAsync(id);
        if (!success)
        {
            return NotFound(new { message = $"Không tìm thấy sản phẩm có ID: {id}" });
        }

        return Ok(new { message = "Đã khôi phục sản phẩm thành công." });
    }
}
