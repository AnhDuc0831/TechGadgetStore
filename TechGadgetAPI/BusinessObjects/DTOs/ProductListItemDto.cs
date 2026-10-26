namespace BusinessObjects.DTOs;

public class ProductListItemDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = null!;
    public string Slug { get; set; } = null!;
    public string? ThumbnailUrl { get; set; }
    public decimal BasePrice { get; set; }
    public decimal MinPrice { get; set; }
    public decimal MaxPrice { get; set; }
    public bool InStock { get; set; }
    public CategorySummaryDto Category { get; set; } = null!;
    public BrandDto Brand { get; set; } = null!;
    public double AverageRating { get; set; }
    public int ReviewCount { get; set; }
}
