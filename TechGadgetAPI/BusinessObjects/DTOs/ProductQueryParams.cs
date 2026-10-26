using System.ComponentModel.DataAnnotations;

namespace BusinessObjects.DTOs;

public class ProductQueryParams : IValidatableObject
{
    [Range(1, int.MaxValue, ErrorMessage = "Page must be greater than or equal to 1.")]
    public int Page { get; set; } = 1;

    [Range(1, 50, ErrorMessage = "Page size must be between 1 and 50.")]
    public int PageSize { get; set; } = 20;

    public List<Guid>? CategoryIds { get; set; }

    public List<Guid>? BrandIds { get; set; }

    [MaxLength(100, ErrorMessage = "Search keyword cannot exceed 100 characters.")]
    public string? Search { get; set; }

    [RegularExpression("^(newest|price_asc|price_desc|name)$",
        ErrorMessage = "SortBy must be one of: newest, price_asc, price_desc, name.")]
    public string? SortBy { get; set; }

    /// <summary>
    /// Lọc theo giá thấp nhất của sản phẩm (giá "Từ ..." hiển thị trên danh sách).
    /// </summary>
    [Range(0, double.MaxValue, ErrorMessage = "MinPrice must be greater than or equal to 0.")]
    public decimal? MinPrice { get; set; }

    [Range(0, double.MaxValue, ErrorMessage = "MaxPrice must be greater than or equal to 0.")]
    public decimal? MaxPrice { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (MinPrice.HasValue && MaxPrice.HasValue && MinPrice > MaxPrice)
        {
            yield return new ValidationResult(
                "MinPrice cannot be greater than MaxPrice.",
                new[] { nameof(MinPrice), nameof(MaxPrice) });
        }
    }
}
