using BusinessObjects.Models;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace DataAccessObjects;

public class VoucherDAO
{
    private readonly TechGadgetDbContext _context;

    public VoucherDAO(TechGadgetDbContext context)
    {
        _context = context;
    }

    // =====================================================================
    // ADMIN
    // =====================================================================

    public async Task<(List<Voucher> Items, int TotalCount)> GetPagedAsync(
        int page, int pageSize, string? search, string? status, DateTimeOffset now)
    {
        var query = _context.Vouchers.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var keyword = $"%{search.Trim()}%";
            query = query.Where(v => EF.Functions.ILike(v.Code, keyword) || EF.Functions.ILike(v.Name, keyword));
        }

        query = status?.Trim().ToLowerInvariant() switch
        {
            "running" => query.Where(v => v.IsActive && v.StartsAt <= now && v.EndsAt >= now),
            "upcoming" => query.Where(v => v.IsActive && v.StartsAt > now),
            "expired" => query.Where(v => v.IsActive && v.EndsAt < now),
            "disabled" => query.Where(v => !v.IsActive),
            _ => query
        };

        var total = await query.CountAsync();
        var items = await query
            .OrderByDescending(v => v.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return (items, total);
    }

    public async Task<Dictionary<Guid, int>> GetUsedCountsAsync(IEnumerable<Guid> voucherIds)
    {
        var ids = voucherIds.ToList();
        return await _context.UserVouchers
            .AsNoTracking()
            .Where(uv => ids.Contains(uv.VoucherId) && uv.Status == UserVoucherStatus.Used)
            .GroupBy(uv => uv.VoucherId)
            .Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Key, x => x.Count);
    }

    public Task<Voucher?> GetByIdAsync(Guid id) =>
        _context.Vouchers.FirstOrDefaultAsync(v => v.Id == id);

    public Task<Voucher?> GetByCodeAsync(string normalizedCode) =>
        _context.Vouchers.FirstOrDefaultAsync(v => v.Code == normalizedCode);

    public Task<bool> CodeExistsAsync(string normalizedCode, Guid? excludeId = null) =>
        _context.Vouchers.AnyAsync(v => v.Code == normalizedCode && (excludeId == null || v.Id != excludeId));

    public async Task<Voucher> AddAsync(Voucher voucher)
    {
        _context.Vouchers.Add(voucher);
        await _context.SaveChangesAsync();
        return voucher;
    }

    public async Task UpdateAsync(Voucher voucher)
    {
        voucher.UpdatedAt = DateTimeOffset.UtcNow;
        _context.Vouchers.Update(voucher);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Voucher voucher)
    {
        _context.Vouchers.Remove(voucher);
        await _context.SaveChangesAsync();
    }

    // =====================================================================
    // CUSTOMER
    // =====================================================================

    /// <summary>Voucher công khai đang chạy hoặc sắp diễn ra (chưa hết hạn), dùng cho "Kho voucher".</summary>
    public Task<List<Voucher>> GetPublicVouchersAsync(DateTimeOffset now) =>
        _context.Vouchers
            .AsNoTracking()
            .Where(v => v.IsActive && v.IsPublic && v.EndsAt >= now)
            .OrderBy(v => v.EndsAt)
            .ToListAsync();

    public Task<List<Guid>> GetClaimedVoucherIdsAsync(Guid userId) =>
        _context.UserVouchers
            .AsNoTracking()
            .Where(uv => uv.UserId == userId)
            .Select(uv => uv.VoucherId)
            .ToListAsync();

    public Task<List<UserVoucher>> GetUserVouchersAsync(Guid userId) =>
        _context.UserVouchers
            .AsNoTracking()
            .Include(uv => uv.Voucher)
            .Where(uv => uv.UserId == userId)
            .OrderByDescending(uv => uv.ClaimedAt)
            .ToListAsync();

    public Task<bool> HasClaimedAsync(Guid voucherId, Guid userId) =>
        _context.UserVouchers.AnyAsync(uv => uv.VoucherId == voucherId && uv.UserId == userId);

    /// <summary>
    /// Lưu voucher vào ví. Trừ suất bằng 1 câu UPDATE có điều kiện để chống race condition
    /// (2 người cùng bấm lưu suất cuối cùng chỉ 1 người thành công).
    /// Trả về null nếu đã hết suất / voucher không còn hiệu lực; ném InvalidOperationException nếu đã lưu trước đó.
    /// </summary>
    public async Task<UserVoucher?> ClaimAsync(Guid voucherId, Guid userId, DateTimeOffset now)
    {
        await using var transaction = await _context.Database.BeginTransactionAsync();

        var affected = await _context.Vouchers
            .Where(v => v.Id == voucherId
                        && v.IsActive
                        && v.EndsAt >= now
                        && v.ClaimedCount < v.TotalQuantity)
            .ExecuteUpdateAsync(s => s
                .SetProperty(v => v.ClaimedCount, v => v.ClaimedCount + 1)
                .SetProperty(v => v.UpdatedAt, now));

        if (affected == 0)
        {
            return null;
        }

        var userVoucher = new UserVoucher
        {
            Id = Guid.NewGuid(),
            VoucherId = voucherId,
            UserId = userId,
            Status = UserVoucherStatus.Available,
            ClaimedAt = now
        };
        _context.UserVouchers.Add(userVoucher);

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // Rollback (dispose transaction) → claimed_count được hoàn lại
            throw new InvalidOperationException("Bạn đã lưu voucher này rồi.");
        }

        await transaction.CommitAsync();
        return userVoucher;
    }
}
