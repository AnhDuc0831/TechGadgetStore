using BusinessObjects.Models;

namespace BusinessObjects.Helpers;

/// <summary>
/// Quy tắc tính giảm giá dùng chung cho cả bước xem trước (Service) và bước checkout trong transaction (DAO),
/// đảm bảo số tiền hiển thị cho khách và số tiền thực trừ luôn khớp nhau.
/// </summary>
public static class VoucherCalculator
{
    /// <summary>
    /// Số tiền giảm (VNĐ, số nguyên) cho một tiền hàng (subtotal, chưa gồm phí ship).
    /// Không bao giờ vượt quá subtotal.
    /// </summary>
    public static decimal CalculateDiscount(Voucher voucher, decimal subtotal)
    {
        if (subtotal <= 0) return 0;

        decimal discount = voucher.DiscountType == VoucherDiscountType.Percent
            ? Math.Floor(subtotal * voucher.DiscountValue / 100m)
            : Math.Floor(voucher.DiscountValue);

        if (voucher.DiscountType == VoucherDiscountType.Percent && voucher.MaxDiscount.HasValue)
        {
            discount = Math.Min(discount, Math.Floor(voucher.MaxDiscount.Value));
        }

        return Math.Max(0, Math.Min(discount, subtotal));
    }

    /// <summary>
    /// Trả về lý do voucher không dùng được cho đơn này, hoặc null nếu dùng được.
    /// </summary>
    public static string? GetIneligibleReason(Voucher voucher, decimal subtotal, DateTimeOffset now)
    {
        if (!voucher.IsActive) return "Voucher đã bị ngừng áp dụng.";
        if (now < voucher.StartsAt) return $"Voucher có hiệu lực từ {voucher.StartsAt.ToOffset(TimeSpan.FromHours(7)):dd/MM/yyyy HH:mm}.";
        if (now > voucher.EndsAt) return "Voucher đã hết hạn.";
        if (subtotal < voucher.MinOrderValue)
        {
            var missing = voucher.MinOrderValue - subtotal;
            return $"Mua thêm {FormatVnd(missing)}đ để dùng voucher này.";
        }
        return null;
    }

    /// <summary>Trạng thái hiển thị của voucher: running | upcoming | expired | disabled.</summary>
    public static string GetDisplayStatus(Voucher voucher, DateTimeOffset now)
    {
        if (!voucher.IsActive) return "disabled";
        if (now < voucher.StartsAt) return "upcoming";
        if (now > voucher.EndsAt) return "expired";
        return "running";
    }

    public static string NormalizeCode(string code) => code.Trim().ToUpperInvariant();

    /// <summary>1200000 → "1.200.000" (không phụ thuộc culture của server).</summary>
    private static string FormatVnd(decimal amount) =>
        amount.ToString("N0", System.Globalization.CultureInfo.InvariantCulture).Replace(",", ".");
}
