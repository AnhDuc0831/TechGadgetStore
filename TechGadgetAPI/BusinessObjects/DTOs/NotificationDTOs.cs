namespace BusinessObjects.DTOs;

public class NotificationDto
{
    public Guid Id { get; set; }
    public string Type { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public Guid? OrderId { get; set; }
    public bool IsRead { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public class NotificationQueryParams
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
    public bool UnreadOnly { get; set; }
}

public class UnreadCountDto
{
    public int UnreadCount { get; set; }

    /// <summary>Thời điểm thông báo mới nhất – client dùng để phát hiện có thông báo mới.</summary>
    public DateTimeOffset? LatestAt { get; set; }
}
