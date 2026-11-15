using BusinessObjects.Models;

namespace Repositories.Interfaces;

public interface INotificationRepository
{
    Task<List<Guid>> GetAdminUserIdsAsync();
    Task AddRangeAsync(IEnumerable<AppNotification> notifications);
    Task<(List<AppNotification> Items, int TotalCount)> GetPagedAsync(Guid userId, int page, int pageSize, bool unreadOnly);
    Task<int> CountUnreadAsync(Guid userId);
    Task<DateTimeOffset?> GetLatestCreatedAtAsync(Guid userId);
    Task<int> MarkAsReadAsync(Guid id, Guid userId);
    Task<int> MarkAllAsReadAsync(Guid userId);
    Task<bool> ExistsForUserAsync(Guid id, Guid userId);
}
