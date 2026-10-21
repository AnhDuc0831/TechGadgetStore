using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using BusinessObjects.Enums;

namespace BusinessObjects.Models;

[Table("orders")]
public class Order
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("user_id")]
    public Guid? UserId { get; set; }

    [Column("status")]
    public OrderStatus Status { get; set; } = OrderStatus.Pending;

    [Column("shipping_fee", TypeName = "numeric(14,2)")]
    public decimal ShippingFee { get; set; } = 0;

    [Column("total_amount", TypeName = "numeric(14,2)")]
    public decimal TotalAmount { get; set; }

    [Required]
    [Column("shipping_address", TypeName = "jsonb")]
    public string ShippingAddress { get; set; } = null!;

    [Column("payment_method")]
    public PaymentMethod PaymentMethod { get; set; } = PaymentMethod.Cod;

    [Column("payment_status")]
    public PaymentStatus PaymentStatus { get; set; } = PaymentStatus.Unpaid;

    [Column("note")]
    public string? Note { get; set; }

    [Column("created_at")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [Column("updated_at")]
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    // Navigation Properties
    [ForeignKey(nameof(UserId))]
    public virtual Profile? User { get; set; }

    public virtual ICollection<OrderItem> OrderItems { get; set; } = new List<OrderItem>();
}
