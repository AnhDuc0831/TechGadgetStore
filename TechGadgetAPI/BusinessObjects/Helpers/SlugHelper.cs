using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace BusinessObjects.Helpers;

public static class SlugHelper
{
    private static readonly Regex NonAlphaNumeric = new("[^a-z0-9]+", RegexOptions.Compiled);

    /// <summary>
    /// "Điện thoại & Máy tính bảng" → "dien-thoai-may-tinh-bang"
    /// </summary>
    public static string Generate(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return string.Empty;

        var normalized = text.Trim().Replace('đ', 'd').Replace('Đ', 'D').Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(normalized.Length);
        foreach (var c in normalized)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
            {
                sb.Append(c);
            }
        }

        var ascii = sb.ToString().Normalize(NormalizationForm.FormC).ToLowerInvariant();
        return NonAlphaNumeric.Replace(ascii, "-").Trim('-');
    }
}
