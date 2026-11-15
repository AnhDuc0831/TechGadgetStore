using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BusinessObjects.Models;

[Table("vouchers")]
public class Voucher
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    [Required]
    [Column("code")]
    public string Code { get; set; } = null!;

    [Required]
    [Column("name")]
    public string Name { get; set; } = null!;

    [Column("description")]
    public string? Description { get; set; }

    /// <summary>"percent" hoặc "fixed" (xem <see cref="VoucherDiscountType"/>).</summary>
    [Required]
    [Column("discount_type")]
    public string DiscountType { get; set; } = VoucherDiscountType.Fixed;

    [Column("discount_value", TypeName = "numeric(14,2)")]
    public decimal DiscountValue { get; set; }

    [Column("max_discount", TypeName = "numeric(14,2)")]
    public decimal? MaxDiscount { get; set; }

    [Column("min_order_value", TypeName = "numeric(14,2)")]
    public decimal MinOrderValue { get; set; }

    [Column("total_quantity")]
    public int TotalQuantity { get; set; }

    [Column("claimed_count")]
    public int ClaimedCount { get; set; }

    [Column("starts_at")]
    public DateTimeOffset StartsAt { get; set; }

    [Column("ends_at")]
    public DateTimeOffset EndsAt { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; } = true;

    [Column("is_public")]
    public bool IsPublic { get; set; } = true;

    [Column("created_at")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [Column("updated_at")]
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    public virtual ICollection<UserVoucher> UserVouchers { get; set; } = new List<UserVoucher>();
}

public static class VoucherDiscountType
{
    public const string Percent = "percent";
    public const string Fixed = "fixed";

    public static bool IsValid(string? value) => value == Percent || value == Fixed;
}
