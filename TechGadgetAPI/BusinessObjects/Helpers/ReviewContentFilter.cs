using System.Text.RegularExpressions;

namespace BusinessObjects.Helpers;

/// <summary>
/// Bộ lọc nội dung đánh giá chạy TỰ ĐỘNG lúc khách gửi.
/// Shop không có quyền ẩn/xóa đánh giá → mọi nội dung vi phạm phải bị chặn ở đây theo quy tắc minh bạch,
/// khách nhận lý do cụ thể và tự sửa lại.
/// </summary>
public static class ReviewContentFilter
{
    public const int MaxCommentLength = 1000;

    // Số điện thoại VN (có thể có dấu cách, chấm, gạch): 0912 345 678, +84 912.345.678
    private static readonly Regex PhoneRegex = new(
        @"(?<!\d)(\+?84|0)[\s.\-]?[1-9](?:[\s.\-]?\d){7,9}(?!\d)",
        RegexOptions.Compiled);

    private static readonly Regex EmailRegex = new(
        @"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}",
        RegexOptions.Compiled);

    private static readonly Regex LinkRegex = new(
        @"(https?://|www\.)\S+|\b[a-z0-9\-]{2,}\.(com|vn|net|org|info|xyz|io|shop|store|site|online|link)\b",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    // Từ ngữ thô tục phổ biến (khớp nguyên từ, không phân biệt hoa thường).
    // Chỉ chọn những từ ít khả năng trùng với từ bình thường để tránh chặn nhầm.
    private static readonly string[] BannedWords =
    {
        "đm", "đmm", "dmm", "đcm", "dcm", "đkm", "vcl", "vkl", "vcc", "clm", "clmm", "cmm",
        "đéo", "địt", "đụ", "lồn", "cặc", "buồi", "đĩ", "óc chó", "ngu như chó", "mẹ mày",
        "fuck", "fucking", "shit", "bitch", "wtf"
    };

    private static readonly Regex BannedRegex = new(
        @"(?<![\p{L}\p{N}])(" + string.Join("|", BannedWords.Select(Regex.Escape)) + @")(?![\p{L}\p{N}])",
        RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    // Lặp 1 ký tự quá nhiều lần: "tốtttttttttt", "!!!!!!!!!!!!" (spam)
    private static readonly Regex RepeatedCharRegex = new(@"(.)\1{9,}", RegexOptions.Compiled);

    /// <summary>
    /// Trả về lý do vi phạm (để báo cho khách), hoặc null nếu nội dung hợp lệ.
    /// </summary>
    public static string? Validate(string? comment)
    {
        if (string.IsNullOrWhiteSpace(comment)) return null;

        if (comment.Length > MaxCommentLength)
            return $"Nội dung đánh giá tối đa {MaxCommentLength} ký tự.";

        if (PhoneRegex.IsMatch(comment))
            return "Đánh giá không được chứa số điện thoại. Vui lòng bỏ số điện thoại để bảo vệ thông tin cá nhân.";

        if (EmailRegex.IsMatch(comment))
            return "Đánh giá không được chứa địa chỉ email.";

        if (LinkRegex.IsMatch(comment))
            return "Đánh giá không được chứa đường link hoặc quảng cáo website.";

        if (BannedRegex.IsMatch(comment))
            return "Đánh giá chứa từ ngữ không phù hợp. Vui lòng sử dụng ngôn từ lịch sự.";

        if (RepeatedCharRegex.IsMatch(comment))
            return "Đánh giá có dấu hiệu spam (lặp ký tự quá nhiều).";

        return null;
    }

    /// <summary>
    /// Che tên người đánh giá: "Nguyễn Văn An" → "Nguyễn V***", "An" → "A***", null → "Khách hàng".
    /// </summary>
    public static string MaskName(string? fullName)
    {
        if (string.IsNullOrWhiteSpace(fullName)) return "Khách hàng";

        var parts = fullName.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 1)
        {
            return $"{char.ToUpper(parts[0][0])}***";
        }

        return $"{parts[0]} {char.ToUpper(parts[1][0])}***";
    }
}
