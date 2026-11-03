namespace BusinessObjects.DTOs;

public class ProductDetailDto : ProductListItemDto
{
    public string? Description { get; set; }
    public List<string> Images { get; set; } = new();
    public string Specifications { get; set; } = "{}";
    public DateTimeOffset UpdatedAt { get; set; }
    public List<ProductVariantDto> Variants { get; set; } = new();
}
