using System.ComponentModel.DataAnnotations;

namespace BusinessObjects.DTOs;

public class AdminProductQueryParams
{
    [Range(1, int.MaxValue, ErrorMessage = "Page must be greater than or equal to 1.")]
    public int Page { get; set; } = 1;

    [Range(1, 100, ErrorMessage = "Page size must be between 1 and 100.")]
    public int PageSize { get; set; } = 20;

    public Guid? CategoryId { get; set; }

    public Guid? BrandId { get; set; }

    public bool? IsActive { get; set; }

    [MaxLength(100, ErrorMessage = "Search keyword cannot exceed 100 characters.")]
    public string? Search { get; set; }

    /// <summary>
    /// Values: newest, price_asc, price_desc, name
    /// </summary>
    public string? SortBy { get; set; }
}
