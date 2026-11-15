using BusinessObjects.Models;

namespace Repositories.Interfaces;

public interface IVoucherRepository
{
    // Admin
    Task<(List<Voucher> Items, int TotalCount)> GetPagedAsync(int page, int pageSize, string? search, string? status, DateTimeOffset now);
    Task<Dictionary<Guid, int>> GetUsedCountsAsync(IEnumerable<Guid> voucherIds);
    Task<Voucher?> GetByIdAsync(Guid id);
    Task<Voucher?> GetByCodeAsync(string normalizedCode);
    Task<bool> CodeExistsAsync(string normalizedCode, Guid? excludeId = null);
    Task<Voucher> AddAsync(Voucher voucher);
    Task UpdateAsync(Voucher voucher);
    Task DeleteAsync(Voucher voucher);

    // Customer
    Task<List<Voucher>> GetPublicVouchersAsync(DateTimeOffset now);
    Task<List<Guid>> GetClaimedVoucherIdsAsync(Guid userId);
    Task<List<UserVoucher>> GetUserVouchersAsync(Guid userId);
    Task<bool> HasClaimedAsync(Guid voucherId, Guid userId);
    Task<UserVoucher?> ClaimAsync(Guid voucherId, Guid userId, DateTimeOffset now);
}
