using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BusinessObjects.Models;

[Table("product_variants")]
public class ProductVariant
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("product_id")]
    public Guid ProductId { get; set; }

    [Required]
    [Column("sku")]
    public string Sku { get; set; } = null!;

    [Required]
    [Column("attributes", TypeName = "jsonb")]
    public string Attributes { get; set; } = "{}";

    [Column("price_adjustment", TypeName = "numeric(14,2)")]
    public decimal PriceAdjustment { get; set; } = 0;

    [Column("stock_quantity")]
    public int StockQuantity { get; set; } = 0;

    [Column("is_active")]
    public bool IsActive { get; set; } = true;

    [Column("created_at")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [Column("updated_at")]
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation Properties
    [ForeignKey(nameof(ProductId))]
    public virtual Product Product { get; set; } = null!;

    public virtual ICollection<CartItem> CartItems { get; set; } = new List<CartItem>();
    public virtual ICollection<OrderItem> OrderItems { get; set; } = new List<OrderItem>();
}
