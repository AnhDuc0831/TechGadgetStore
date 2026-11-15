using BusinessObjects.DTOs;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;

namespace API.Controllers;

/// <summary>
/// Admin: Quản lý thương hiệu (thêm, sửa, xóa).
/// </summary>
[Route("api/admin/brands")]
public class AdminBrandsController : AdminControllerBase
{
    private readonly IBrandService _brandService;

    public AdminBrandsController(
        IBrandService brandService,
        IProfileService profileService,
        ILogger<AdminBrandsController> logger) : base(profileService, logger)
    {
        _brandService = brandService;
    }

    /// <summary>Admin: Danh sách thương hiệu kèm số sản phẩm.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(List<AdminBrandDto>), StatusCodes.Status200OK)]
    public Task<IActionResult> GetBrands() =>
        AdminActionAsync(() => _brandService.GetAdminBrandsAsync(), "Không thể tải thương hiệu.");

    /// <summary>Admin: Tạo thương hiệu (multipart/form-data: Name, LogoFile?).</summary>
    [HttpPost]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(AdminBrandDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public Task<IActionResult> CreateBrand([FromForm] SaveBrandRequest request) =>
        AdminActionAsync(() => _brandService.CreateBrandAsync(request), "Không thể tạo thương hiệu.");

    /// <summary>Admin: Cập nhật thương hiệu. Gửi RemoveLogo=true để gỡ logo.</summary>
    [HttpPut("{id:guid}")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(AdminBrandDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public Task<IActionResult> UpdateBrand(Guid id, [FromForm] SaveBrandRequest request) =>
        AdminActionAsync(() => _brandService.UpdateBrandAsync(id, request), "Không thể cập nhật thương hiệu.");

    /// <summary>Admin: Xóa thương hiệu (chỉ khi không còn sản phẩm nào).</summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public Task<IActionResult> DeleteBrand(Guid id) =>
        AdminActionAsync(async () =>
        {
            await _brandService.DeleteBrandAsync(id);
            return new { message = "Đã xóa thương hiệu." };
        }, "Không thể xóa thương hiệu.");
}
