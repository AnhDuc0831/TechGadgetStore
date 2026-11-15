using Microsoft.AspNetCore.Http;

namespace BusinessObjects.DTOs;

// =====================================================================
// DANH MỤC
// =====================================================================

public class AdminCategoryDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Slug { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? ImageUrl { get; set; }

    /// <summary>Số sản phẩm thuộc danh mục (kể cả đang ẩn). &gt; 0 thì không xóa được.</summary>
    public int ProductCount { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>Tạo / sửa danh mục (multipart/form-data vì có ảnh).</summary>
public class SaveCategoryRequest
{
    public string Name { get; set; } = string.Empty;

    /// <summary>Để trống → tự sinh từ tên.</summary>
    public string? Slug { get; set; }
    public string? Description { get; set; }
    public IFormFile? ImageFile { get; set; }

    /// <summary>Khi sửa: true để gỡ ảnh hiện tại.</summary>
    public bool RemoveImage { get; set; }
}

// =====================================================================
// THƯƠNG HIỆU
// =====================================================================

public class AdminBrandDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? LogoUrl { get; set; }
    public int ProductCount { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public class SaveBrandRequest
{
    public string Name { get; set; } = string.Empty;
    public IFormFile? LogoFile { get; set; }
    public bool RemoveLogo { get; set; }
}
