using BusinessObjects.DTOs;

namespace Services.Interfaces;

public interface IVoucherService
{
    // Admin
    Task<PagedResult<AdminVoucherDto>> GetAdminVouchersAsync(AdminVoucherQueryParams query);
    Task<AdminVoucherDto> GetAdminVoucherByIdAsync(Guid id);
    Task<AdminVoucherDto> CreateVoucherAsync(CreateVoucherRequest request);
    Task<AdminVoucherDto> UpdateVoucherAsync(Guid id, UpdateVoucherRequest request);
    Task<AdminVoucherDto> ToggleVoucherAsync(Guid id);
    Task DeleteVoucherAsync(Guid id);

    // Customer
    Task<List<PublicVoucherDto>> GetPublicVouchersAsync(Guid userId);
    Task<MyVoucherDto> ClaimVoucherAsync(Guid voucherId, Guid userId);
    Task<MyVoucherDto> ClaimVoucherByCodeAsync(string code, Guid userId);
    Task<List<MyVoucherDto>> GetMyVouchersAsync(Guid userId, decimal? subtotal = null);
}
