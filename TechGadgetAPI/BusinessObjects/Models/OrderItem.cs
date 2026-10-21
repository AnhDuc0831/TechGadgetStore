using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BusinessObjects.Models;

[Table("order_items")]
public class OrderItem
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("order_id")]
    public Guid OrderId { get; set; }

    [Column("product_variant_id")]
    public Guid ProductVariantId { get; set; }

    [Required]
    [Column("product_name")]
    public string ProductName { get; set; } = null!;

    [Required]
    [Column("sku")]
    public string Sku { get; set; } = null!;

    [Column("unit_price", TypeName = "numeric(14,2)")]
    public decimal UnitPrice { get; set; }

    [Column("quantity")]
    public int Quantity { get; set; }

    [Column("created_at")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [Column("updated_at")]
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation Properties
    [ForeignKey(nameof(OrderId))]
    public virtual Order Order { get; set; } = null!;

    [ForeignKey(nameof(ProductVariantId))]
    public virtual ProductVariant ProductVariant { get; set; } = null!;
}
