using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Http;

namespace BusinessObjects.DTOs;

public class CreateProductRequest : IValidatableObject
{
    [Required(ErrorMessage = "Tên sản phẩm không được để trống.")]
    [MaxLength(255, ErrorMessage = "Tên sản phẩm tối đa 255 ký tự.")]
    public string Name { get; set; } = null!;

    [Required(ErrorMessage = "Danh mục không được để trống.")]
    public Guid CategoryId { get; set; }

    [Required(ErrorMessage = "Thương hiệu không được để trống.")]
    public Guid BrandId { get; set; }

    [MaxLength(4000, ErrorMessage = "Mô tả tối đa 4000 ký tự.")]
    public string? Description { get; set; }

    [Required(ErrorMessage = "Giá gốc không được để trống.")]
    [Range(0, double.MaxValue, ErrorMessage = "Giá gốc phải lớn hơn hoặc bằng 0.")]
    public decimal BasePrice { get; set; }

    [Range(0, double.MaxValue, ErrorMessage = "Giá khuyến mãi phải lớn hơn hoặc bằng 0.")]
    public decimal? DiscountPrice { get; set; }

    [Range(0, int.MaxValue, ErrorMessage = "Số lượng tồn kho phải lớn hơn hoặc bằng 0.")]
    public int StockQuantity { get; set; } = 0;

    [MaxLength(50, ErrorMessage = "Mã SKU tối đa 50 ký tự.")]
    public string? Sku { get; set; }

    public string Specifications { get; set; } = "{}";

    public bool IsActive { get; set; } = true;

    /// <summary>
    /// Danh sách file ảnh upload trực tiếp từ mobile/web lên Cloudinary
    /// </summary>
    public List<IFormFile>? ImageFiles { get; set; }

    /// <summary>
    /// Danh sách URL ảnh có sẵn (nếu có)
    /// </summary>
    public List<string>? ImageUrls { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (DiscountPrice.HasValue && DiscountPrice.Value > BasePrice)
        {
            yield return new ValidationResult(
                "Giá khuyến mãi không được lớn hơn giá gốc.",
                new[] { nameof(DiscountPrice) }
            );
        }
    }
}
