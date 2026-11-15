using System.ComponentModel.DataAnnotations;

namespace BusinessObjects.DTOs;

// =====================================================================
// ADMIN
// =====================================================================

public class AdminVoucherQueryParams
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
    public string? Search { get; set; }

    /// <summary>"running" | "upcoming" | "expired" | "disabled" | null (tất cả)</summary>
    public string? Status { get; set; }
}

public class AdminVoucherDto
{
    public Guid Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string DiscountType { get; set; } = string.Empty;
    public decimal DiscountValue { get; set; }
    public decimal? MaxDiscount { get; set; }
    public decimal MinOrderValue { get; set; }
    public int TotalQuantity { get; set; }
    public int ClaimedCount { get; set; }
    public int UsedCount { get; set; }
    public int RemainingQuantity => Math.Max(0, TotalQuantity - ClaimedCount);
    public DateTimeOffset StartsAt { get; set; }
    public DateTimeOffset EndsAt { get; set; }
    public bool IsActive { get; set; }
    public bool IsPublic { get; set; }

    /// <summary>"running" | "upcoming" | "expired" | "disabled"</summary>
    public string DisplayStatus { get; set; } = string.Empty;

    /// <summary>Đã có người lưu → khóa các trường ảnh hưởng tới số tiền giảm.</summary>
    public bool IsLocked => ClaimedCount > 0;
    public DateTimeOffset CreatedAt { get; set; }
}

public class CreateVoucherRequest
{
    [Required(ErrorMessage = "Vui lòng nhập mã voucher.")]
    [StringLength(30, MinimumLength = 3, ErrorMessage = "Mã voucher dài từ 3 đến 30 ký tự.")]
    [RegularExpression("^[A-Za-z0-9_-]+$", ErrorMessage = "Mã voucher chỉ gồm chữ, số, '-' và '_'.")]
    public string Code { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập tên voucher.")]
    [StringLength(120)]
    public string Name { get; set; } = string.Empty;

    [StringLength(500)]
    public string? Description { get; set; }

    /// <summary>"percent" | "fixed"</summary>
    [Required]
    public string DiscountType { get; set; } = "fixed";

    [Range(1, 1_000_000_000, ErrorMessage = "Giá trị giảm phải lớn hơn 0.")]
    public decimal DiscountValue { get; set; }

    [Range(1, 1_000_000_000)]
    public decimal? MaxDiscount { get; set; }

    [Range(0, 1_000_000_000)]
    public decimal MinOrderValue { get; set; }

    [Range(1, 1_000_000, ErrorMessage = "Số lượng phải từ 1 trở lên.")]
    public int TotalQuantity { get; set; }

    public DateTimeOffset StartsAt { get; set; }
    public DateTimeOffset EndsAt { get; set; }
    public bool IsActive { get; set; } = true;
    public bool IsPublic { get; set; } = true;
}

/// <summary>
/// Khi voucher đã có người lưu, server bỏ qua thay đổi ở Code/DiscountType/DiscountValue/MaxDiscount/MinOrderValue
/// (nếu khác giá trị cũ sẽ báo lỗi) để không làm thay đổi quyền lợi của khách đã lưu.
/// </summary>
public class UpdateVoucherRequest : CreateVoucherRequest
{
}

// =====================================================================
// CUSTOMER
// =====================================================================

/// <summary>Voucher hiển thị trong "Kho voucher".</summary>
public class PublicVoucherDto
{
    public Guid Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string DiscountType { get; set; } = string.Empty;
    public decimal DiscountValue { get; set; }
    public decimal? MaxDiscount { get; set; }
    public decimal MinOrderValue { get; set; }
    public int TotalQuantity { get; set; }
    public int RemainingQuantity { get; set; }
    public DateTimeOffset StartsAt { get; set; }
    public DateTimeOffset EndsAt { get; set; }
    public bool IsClaimed { get; set; }
}

/// <summary>Voucher trong ví của khách.</summary>
public class MyVoucherDto
{
    public Guid UserVoucherId { get; set; }
    public Guid VoucherId { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string DiscountType { get; set; } = string.Empty;
    public decimal DiscountValue { get; set; }
    public decimal? MaxDiscount { get; set; }
    public decimal MinOrderValue { get; set; }
    public DateTimeOffset StartsAt { get; set; }
    public DateTimeOffset EndsAt { get; set; }

    /// <summary>"available" | "used" | "expired" | "upcoming" | "disabled"</summary>
    public string Status { get; set; } = string.Empty;
    public DateTimeOffset ClaimedAt { get; set; }
    public DateTimeOffset? UsedAt { get; set; }
    public Guid? OrderId { get; set; }

    /// <summary>Số tiền đã giảm (với voucher đã dùng).</summary>
    public decimal? UsedDiscountAmount { get; set; }

    // Chỉ có khi client truyền ?subtotal=... (dùng ở màn hình checkout)
    public bool? IsApplicable { get; set; }
    public decimal? EstimatedDiscount { get; set; }
    public string? IneligibleReason { get; set; }
}

public class ClaimVoucherByCodeRequest
{
    [Required(ErrorMessage = "Vui lòng nhập mã voucher.")]
    public string Code { get; set; } = string.Empty;
}
