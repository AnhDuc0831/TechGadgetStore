using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BusinessObjects.Models;

[Table("products")]
public class Product
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("category_id")]
    public Guid CategoryId { get; set; }

    [Column("brand_id")]
    public Guid BrandId { get; set; }

    [Required]
    [Column("name")]
    public string Name { get; set; } = null!;

    [Required]
    [Column("slug")]
    public string Slug { get; set; } = null!;

    [Column("description")]
    public string? Description { get; set; }

    [Column("thumbnail_url")]
    public string? ThumbnailUrl { get; set; }

    [Column("base_price", TypeName = "numeric(14,2)")]
    public decimal BasePrice { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; } = true;

    [Column("created_at")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [Column("updated_at")]
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation Properties
    [ForeignKey(nameof(CategoryId))]
    public virtual Category Category { get; set; } = null!;

    [ForeignKey(nameof(BrandId))]
    public virtual Brand Brand { get; set; } = null!;

    public virtual ICollection<ProductVariant> ProductVariants { get; set; } = new List<ProductVariant>();
    public virtual ICollection<Review> Reviews { get; set; } = new List<Review>();
    public virtual ICollection<Favorite> Favorites { get; set; } = new List<Favorite>();
}
