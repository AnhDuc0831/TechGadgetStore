using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace BusinessObjects.Models;

/// <summary>Thông báo trong app gửi tới 1 người dùng (Admin hoặc Khách).</summary>
[Table("notifications")]
public class AppNotification
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; }

    /// <summary>Người nhận.</summary>
    [Column("user_id")]
    public Guid UserId { get; set; }

    [Required]
    [Column("type")]
    public string Type { get; set; } = NotificationTypes.OrderStatus;

    [Required]
    [Column("title")]
    public string Title { get; set; } = null!;

    [Required]
    [Column("message")]
    public string Message { get; set; } = null!;

    [Column("order_id")]
    public Guid? OrderId { get; set; }

    [Column("is_read")]
    public bool IsRead { get; set; }

    [Column("created_at")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [ForeignKey(nameof(UserId))]
    public virtual Profile User { get; set; } = null!;
}

public static class NotificationTypes
{
    // Gửi Admin
    public const string NewOrder = "new_order";
    public const string OrderPaid = "order_paid";
    public const string OrderReceived = "order_received";

    // Gửi Khách (và Admin khi khách tự hủy)
    public const string OrderStatus = "order_status";
    public const string OrderCancelled = "order_cancelled";
}
