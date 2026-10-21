using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using BusinessObjects.Enums;

namespace BusinessObjects.Models;

[Table("profiles")]
public class Profile
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("full_name")]
    public string? FullName { get; set; }

    [Column("avatar_url")]
    public string? AvatarUrl { get; set; }

    [Column("phone")]
    public string? Phone { get; set; }

    [Column("role")]
    public UserRole Role { get; set; } = UserRole.Customer;

    [Column("created_at")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [Column("updated_at")]
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation Properties
    public virtual ShoppingCart? ShoppingCart { get; set; }
    public virtual ICollection<Order> Orders { get; set; } = new List<Order>();
    public virtual ICollection<Review> Reviews { get; set; } = new List<Review>();
    public virtual ICollection<Favorite> Favorites { get; set; } = new List<Favorite>();
}
