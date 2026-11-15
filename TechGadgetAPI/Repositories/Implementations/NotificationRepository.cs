using BusinessObjects.Models;
using DataAccessObjects;
using Repositories.Interfaces;

namespace Repositories.Implementations;

public class NotificationRepository : INotificationRepository
{
    private readonly NotificationDAO _notificationDao;

    public NotificationRepository(NotificationDAO notificationDao)
    {
        _notificationDao = notificationDao;
    }

    public Task<List<Guid>> GetAdminUserIdsAsync() => _notificationDao.GetAdminUserIdsAsync();

    public Task AddRangeAsync(IEnumerable<AppNotification> notifications) => _notificationDao.AddRangeAsync(notifications);

    public Task<(List<AppNotification> Items, int TotalCount)> GetPagedAsync(Guid userId, int page, int pageSize, bool unreadOnly) =>
        _notificationDao.GetPagedAsync(userId, page, pageSize, unreadOnly);

    public Task<int> CountUnreadAsync(Guid userId) => _notificationDao.CountUnreadAsync(userId);

    public Task<DateTimeOffset?> GetLatestCreatedAtAsync(Guid userId) => _notificationDao.GetLatestCreatedAtAsync(userId);

    public Task<int> MarkAsReadAsync(Guid id, Guid userId) => _notificationDao.MarkAsReadAsync(id, userId);

    public Task<int> MarkAllAsReadAsync(Guid userId) => _notificationDao.MarkAllAsReadAsync(userId);

    public Task<bool> ExistsForUserAsync(Guid id, Guid userId) => _notificationDao.ExistsForUserAsync(id, userId);
}
