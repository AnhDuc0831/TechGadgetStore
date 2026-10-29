using System.Text.Json.Serialization;

namespace BusinessObjects.Enums;

/// <summary>Trạng thái của một dòng trong giỏ hàng (trả về Flutter dạng chuỗi).</summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CartItemStatus
{
    Available,           // mua được
    Unavailable,         // product/variant đã ngừng bán (is_active = false)
    OutOfStock,          // hết hàng
    InsufficientStock    // còn hàng nhưng không đủ số lượng đang chọn
}