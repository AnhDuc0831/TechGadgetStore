using BusinessObjects.Enums;

namespace BusinessObjects.DTOs.Cart;

public class CartItemDto
{
    public Guid Id { get; set; }
    public Guid ProductId { get; set; }
    public Guid ProductVariantId { get; set; }
    public string ProductName { get; set; } = "";
    public string? ThumbnailUrl { get; set; }
    public string Sku { get; set; } = "";
    public string? Attributes { get; set; }   // jsonb dạng chuỗi, vd {"color":"Black","ram":"8GB"}
    public decimal UnitPrice { get; set; }    // base_price + price_adjustment
    public int Quantity { get; set; }
    public int StockQuantity { get; set; }
    public CartItemStatus Status { get; set; }
    public bool IsAvailable => Status == CartItemStatus.Available;
    public decimal LineTotal => UnitPrice * Quantity;
}