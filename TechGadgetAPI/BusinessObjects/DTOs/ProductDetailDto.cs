namespace BusinessObjects.DTOs;

public class ProductDetailDto : ProductListItemDto
{
    public string? Description { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public List<ProductVariantDto> Variants { get; set; } = new();
}
