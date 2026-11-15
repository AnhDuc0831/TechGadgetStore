using BusinessObjects.Models;
using DataAccessObjects;
using Repositories.Interfaces;

namespace Repositories.Implementations;

public class VoucherRepository : IVoucherRepository
{
    private readonly VoucherDAO _voucherDao;

    public VoucherRepository(VoucherDAO voucherDao)
    {
        _voucherDao = voucherDao;
    }

    public Task<(List<Voucher> Items, int TotalCount)> GetPagedAsync(int page, int pageSize, string? search, string? status, DateTimeOffset now) =>
        _voucherDao.GetPagedAsync(page, pageSize, search, status, now);

    public Task<Dictionary<Guid, int>> GetUsedCountsAsync(IEnumerable<Guid> voucherIds) =>
        _voucherDao.GetUsedCountsAsync(voucherIds);

    public Task<Voucher?> GetByIdAsync(Guid id) => _voucherDao.GetByIdAsync(id);

    public Task<Voucher?> GetByCodeAsync(string normalizedCode) => _voucherDao.GetByCodeAsync(normalizedCode);

    public Task<bool> CodeExistsAsync(string normalizedCode, Guid? excludeId = null) =>
        _voucherDao.CodeExistsAsync(normalizedCode, excludeId);

    public Task<Voucher> AddAsync(Voucher voucher) => _voucherDao.AddAsync(voucher);

    public Task UpdateAsync(Voucher voucher) => _voucherDao.UpdateAsync(voucher);

    public Task DeleteAsync(Voucher voucher) => _voucherDao.DeleteAsync(voucher);

    public Task<List<Voucher>> GetPublicVouchersAsync(DateTimeOffset now) => _voucherDao.GetPublicVouchersAsync(now);

    public Task<List<Guid>> GetClaimedVoucherIdsAsync(Guid userId) => _voucherDao.GetClaimedVoucherIdsAsync(userId);

    public Task<List<UserVoucher>> GetUserVouchersAsync(Guid userId) => _voucherDao.GetUserVouchersAsync(userId);

    public Task<bool> HasClaimedAsync(Guid voucherId, Guid userId) => _voucherDao.HasClaimedAsync(voucherId, userId);

    public Task<UserVoucher?> ClaimAsync(Guid voucherId, Guid userId, DateTimeOffset now) =>
        _voucherDao.ClaimAsync(voucherId, userId, now);
}
