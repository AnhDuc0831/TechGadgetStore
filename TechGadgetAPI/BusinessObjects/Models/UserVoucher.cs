using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BusinessObjects.Models;

/// <summary>
/// Một voucher nằm trong ví của khách hàng.
/// Vòng đời: available → (checkout) used → (hủy đơn) available.
/// </summary>
[Table("user_vouchers")]
public class UserVoucher
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Column("voucher_id")]
    public Guid VoucherId { get; set; }

    [Column("user_id")]
    public Guid UserId { get; set; }

    [Required]
    [Column("status")]
    public string Status { get; set; } = UserVoucherStatus.Available;

    [Column("order_id")]
    public Guid? OrderId { get; set; }

    [Column("discount_amount", TypeName = "numeric(14,2)")]
    public decimal? DiscountAmount { get; set; }

    [Column("claimed_at")]
    public DateTimeOffset ClaimedAt { get; set; } = DateTimeOffset.UtcNow;

    [Column("used_at")]
    public DateTimeOffset? UsedAt { get; set; }

    [ForeignKey(nameof(VoucherId))]
    public virtual Voucher Voucher { get; set; } = null!;

    [ForeignKey(nameof(UserId))]
    public virtual Profile User { get; set; } = null!;
}

public static class UserVoucherStatus
{
    public const string Available = "available";
    public const string Used = "used";
}
