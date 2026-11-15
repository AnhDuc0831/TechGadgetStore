using Microsoft.AspNetCore.Http;

namespace Services.Implementations;

/// <summary>
/// Quy tắc kiểm tra file ảnh tải lên dùng chung (đánh giá, danh mục, thương hiệu...).
/// </summary>
public static class ImageFileRules
{
    public const long MaxBytes = 5 * 1024 * 1024;

    private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif", ".gif"
    };

    /// <summary>Ném InvalidOperationException nếu file không phải ảnh hợp lệ.</summary>
    public static void EnsureValid(IFormFile file)
    {
        if (file.Length > MaxBytes)
        {
            throw new InvalidOperationException($"Ảnh '{file.FileName}' vượt quá 5MB.");
        }

        // Mobile thường gửi "application/octet-stream" → chấp nhận nếu content-type là image/* HOẶC đuôi file là ảnh
        var isImageType = !string.IsNullOrEmpty(file.ContentType)
                          && file.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase);
        var isImageExt = AllowedExtensions.Contains(Path.GetExtension(file.FileName ?? string.Empty));
        if (!isImageType && !isImageExt)
        {
            throw new InvalidOperationException($"Tệp '{file.FileName}' không phải là ảnh.");
        }
    }
}
