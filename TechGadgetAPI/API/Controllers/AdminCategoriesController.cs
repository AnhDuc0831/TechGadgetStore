using BusinessObjects.DTOs;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;

namespace API.Controllers;

/// <summary>
/// Admin: Quản lý danh mục sản phẩm (thêm, sửa, xóa).
/// </summary>
[Route("api/admin/categories")]
public class AdminCategoriesController : AdminControllerBase
{
    private readonly ICategoryService _categoryService;

    public AdminCategoriesController(
        ICategoryService categoryService,
        IProfileService profileService,
        ILogger<AdminCategoriesController> logger) : base(profileService, logger)
    {
        _categoryService = categoryService;
    }

    /// <summary>Admin: Danh sách danh mục kèm số sản phẩm.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(List<AdminCategoryDto>), StatusCodes.Status200OK)]
    public Task<IActionResult> GetCategories() =>
        AdminActionAsync(() => _categoryService.GetAdminCategoriesAsync(), "Không thể tải danh mục.");

    /// <summary>Admin: Tạo danh mục (multipart/form-data: Name, Slug?, Description?, ImageFile?).</summary>
    [HttpPost]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(AdminCategoryDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public Task<IActionResult> CreateCategory([FromForm] SaveCategoryRequest request) =>
        AdminActionAsync(() => _categoryService.CreateCategoryAsync(request), "Không thể tạo danh mục.");

    /// <summary>Admin: Cập nhật danh mục. Gửi RemoveImage=true để gỡ ảnh.</summary>
    [HttpPut("{id:guid}")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(AdminCategoryDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public Task<IActionResult> UpdateCategory(Guid id, [FromForm] SaveCategoryRequest request) =>
        AdminActionAsync(() => _categoryService.UpdateCategoryAsync(id, request), "Không thể cập nhật danh mục.");

    /// <summary>Admin: Xóa danh mục (chỉ khi không còn sản phẩm nào).</summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public Task<IActionResult> DeleteCategory(Guid id) =>
        AdminActionAsync(async () =>
        {
            await _categoryService.DeleteCategoryAsync(id);
            return new { message = "Đã xóa danh mục." };
        }, "Không thể xóa danh mục.");
}
