using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BusinessObjects.Models;

[Table("categories")]
public class Category
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Required]
    [Column("name")]
    public string Name { get; set; } = null!;

    [Required]
    [Column("slug")]
    public string Slug { get; set; } = null!;

    [Column("description")]
    public string? Description { get; set; }

    [Column("image_url")]
    public string? ImageUrl { get; set; }

    [Column("created_at")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [Column("updated_at")]
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation Properties
    public virtual ICollection<Product> Products { get; set; } = new List<Product>();
}
