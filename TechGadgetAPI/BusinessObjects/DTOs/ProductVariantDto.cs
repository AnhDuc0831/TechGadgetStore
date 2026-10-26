using System.Text.Json;

namespace BusinessObjects.DTOs;

public class ProductVariantDto
{
    public Guid Id { get; set; }
    public string Sku { get; set; } = null!;

    /// <summary>
    /// Thuộc tính của biến thể (vd: {"color": "Black", "storage": "128GB"}), trả về dạng JSON object.
    /// </summary>
    public JsonElement Attributes { get; set; }

    public decimal PriceAdjustment { get; set; }
    public decimal FinalPrice { get; set; }
    public int StockQuantity { get; set; }
    public bool InStock { get; set; }
}
