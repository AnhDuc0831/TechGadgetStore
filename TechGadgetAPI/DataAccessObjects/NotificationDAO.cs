using BusinessObjects.Enums;
using BusinessObjects.Models;
using Microsoft.EntityFrameworkCore;

namespace DataAccessObjects;

public class NotificationDAO
{
    private readonly TechGadgetDbContext _context;

    public NotificationDAO(TechGadgetDbContext context)
    {
        _context = context;
    }

    public Task<List<Guid>> GetAdminUserIdsAsync() =>
        _context.Profiles
            .AsNoTracking()
            .Where(p => p.Role == UserRole.Admin)
            .Select(p => p.Id)
            .ToListAsync();

    public async Task AddRangeAsync(IEnumerable<AppNotification> notifications)
    {
        var list = notifications.ToList();
        if (list.Count == 0) return;
        _context.Notifications.AddRange(list);
        try
        {
            await _context.SaveChangesAsync();
        }
        catch
        {
            // Gỡ các thông báo lỗi khỏi DbContext (dùng chung trong request) để lần SaveChanges
            // tiếp theo của nghiệp vụ đơn hàng không bị lỗi theo.
            foreach (var n in list)
            {
                _context.Entry(n).State = EntityState.Detached;
            }
            throw;
        }
    }

    public async Task<(List<AppNotification> Items, int TotalCount)> GetPagedAsync(Guid userId, int page, int pageSize, bool unreadOnly)
    {
        var query = _context.Notifications.AsNoTracking().Where(n => n.UserId == userId);
        if (unreadOnly)
        {
            query = query.Where(n => !n.IsRead);
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderByDescending(n => n.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();
        return (items, total);
    }

    public Task<int> CountUnreadAsync(Guid userId) =>
        _context.Notifications.CountAsync(n => n.UserId == userId && !n.IsRead);

    public Task<DateTimeOffset?> GetLatestCreatedAtAsync(Guid userId) =>
        _context.Notifications
            .Where(n => n.UserId == userId)
            .MaxAsync(n => (DateTimeOffset?)n.CreatedAt);

    /// <summary>Đánh dấu đã đọc (chỉ thông báo của chính user). Trả về số dòng cập nhật.</summary>
    public Task<int> MarkAsReadAsync(Guid id, Guid userId) =>
        _context.Notifications
            .Where(n => n.Id == id && n.UserId == userId && !n.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true));

    public Task<int> MarkAllAsReadAsync(Guid userId) =>
        _context.Notifications
            .Where(n => n.UserId == userId && !n.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true));

    public Task<bool> ExistsForUserAsync(Guid id, Guid userId) =>
        _context.Notifications.AnyAsync(n => n.Id == id && n.UserId == userId);
}
