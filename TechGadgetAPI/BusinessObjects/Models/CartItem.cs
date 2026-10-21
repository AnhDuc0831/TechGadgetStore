using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BusinessObjects.Models;

[Table("cart_items")]
public class CartItem
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("cart_id")]
    public Guid CartId { get; set; }

    [Column("product_variant_id")]
    public Guid ProductVariantId { get; set; }

    [Column("quantity")]
    public int Quantity { get; set; } = 1;

    [Column("created_at")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [Column("updated_at")]
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation Properties
    [ForeignKey(nameof(CartId))]
    public virtual ShoppingCart Cart { get; set; } = null!;

    [ForeignKey(nameof(ProductVariantId))]
    public virtual ProductVariant ProductVariant { get; set; } = null!;
}
