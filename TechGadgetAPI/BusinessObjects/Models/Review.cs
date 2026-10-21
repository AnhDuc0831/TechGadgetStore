using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BusinessObjects.Models;

[Table("reviews")]
public class Review
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("product_id")]
    public Guid ProductId { get; set; }

    [Column("user_id")]
    public Guid UserId { get; set; }

    [Column("rating")]
    public short Rating { get; set; }

    [Column("comment")]
    public string? Comment { get; set; }

    [Column("created_at")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [Column("updated_at")]
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation Properties
    [ForeignKey(nameof(ProductId))]
    public virtual Product Product { get; set; } = null!;

    [ForeignKey(nameof(UserId))]
    public virtual Profile User { get; set; } = null!;
}
