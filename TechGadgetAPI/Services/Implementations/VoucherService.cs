using BusinessObjects.DTOs;
using BusinessObjects.Helpers;
using BusinessObjects.Models;
using Repositories.Interfaces;
using Services.Interfaces;

namespace Services.Implementations;

public class VoucherService : IVoucherService
{
    private readonly IVoucherRepository _voucherRepo;
    private readonly TimeProvider _timeProvider;

    public VoucherService(IVoucherRepository voucherRepo, TimeProvider? timeProvider = null)
    {
        _voucherRepo = voucherRepo;
        _timeProvider = timeProvider ?? TimeProvider.System;
    }

    private DateTimeOffset Now => _timeProvider.GetUtcNow();

    // =====================================================================
    // ADMIN
    // =====================================================================

    public async Task<PagedResult<AdminVoucherDto>> GetAdminVouchersAsync(AdminVoucherQueryParams query)
    {
        var page = Math.Max(1, query.Page);
        var pageSize = Math.Clamp(query.PageSize, 1, 100);
        var now = Now;

        var (items, total) = await _voucherRepo.GetPagedAsync(page, pageSize, query.Search, query.Status, now);
        var usedCounts = await _voucherRepo.GetUsedCountsAsync(items.Select(v => v.Id));

        return new PagedResult<AdminVoucherDto>
        {
            Items = items.Select(v => MapToAdminDto(v, usedCounts.GetValueOrDefault(v.Id), now)).ToList(),
            Page = page,
            PageSize = pageSize,
            TotalCount = total
        };
    }

    public async Task<AdminVoucherDto> GetAdminVoucherByIdAsync(Guid id)
    {
        var voucher = await GetVoucherOrThrowAsync(id);
        return await MapToAdminDtoAsync(voucher);
    }

    public async Task<AdminVoucherDto> CreateVoucherAsync(CreateVoucherRequest request)
    {
        ValidateRequest(request);

        var code = VoucherCalculator.NormalizeCode(request.Code);
        if (await _voucherRepo.CodeExistsAsync(code))
        {
            throw new InvalidOperationException($"Mã voucher '{code}' đã tồn tại.");
        }

        var now = Now;
        var voucher = new Voucher
        {
            Id = Guid.NewGuid(),
            Code = code,
            CreatedAt = now,
            UpdatedAt = now
        };
        ApplyRequest(voucher, request);

        await _voucherRepo.AddAsync(voucher);
        return MapToAdminDto(voucher, 0, now);
    }

    public async Task<AdminVoucherDto> UpdateVoucherAsync(Guid id, UpdateVoucherRequest request)
    {
        ValidateRequest(request);

        var voucher = await GetVoucherOrThrowAsync(id);
        var code = VoucherCalculator.NormalizeCode(request.Code);

        if (voucher.ClaimedCount > 0)
        {
            // Đã có khách lưu → không cho đổi quyền lợi của voucher
            var normalizedMax = request.DiscountType == VoucherDiscountType.Percent ? request.MaxDiscount : null;
            if (code != voucher.Code
                || request.DiscountType != voucher.DiscountType
                || request.DiscountValue != voucher.DiscountValue
                || normalizedMax != voucher.MaxDiscount
                || request.MinOrderValue != voucher.MinOrderValue)
            {
                throw new InvalidOperationException(
                    "Voucher đã có khách lưu nên không thể đổi mã, loại giảm, mức giảm, giảm tối đa hoặc đơn tối thiểu. " +
                    "Bạn chỉ có thể sửa tên, mô tả, thời gian, số lượng và trạng thái. Muốn đổi mức giảm hãy tạo voucher mới.");
            }

            if (request.TotalQuantity < voucher.ClaimedCount)
            {
                throw new InvalidOperationException($"Số lượng không được nhỏ hơn số suất đã được lưu ({voucher.ClaimedCount}).");
            }
        }
        else if (code != voucher.Code && await _voucherRepo.CodeExistsAsync(code, voucher.Id))
        {
            throw new InvalidOperationException($"Mã voucher '{code}' đã tồn tại.");
        }

        voucher.Code = code;
        ApplyRequest(voucher, request);
        await _voucherRepo.UpdateAsync(voucher);

        return await MapToAdminDtoAsync(voucher);
    }

    public async Task<AdminVoucherDto> ToggleVoucherAsync(Guid id)
    {
        var voucher = await GetVoucherOrThrowAsync(id);
        voucher.IsActive = !voucher.IsActive;
        await _voucherRepo.UpdateAsync(voucher);
        return await MapToAdminDtoAsync(voucher);
    }

    public async Task DeleteVoucherAsync(Guid id)
    {
        var voucher = await GetVoucherOrThrowAsync(id);
        if (voucher.ClaimedCount > 0)
        {
            throw new InvalidOperationException("Voucher đã có khách lưu nên không thể xóa. Hãy tắt voucher thay vì xóa.");
        }
        await _voucherRepo.DeleteAsync(voucher);
    }

    // =====================================================================
    // CUSTOMER
    // =====================================================================

    public async Task<List<PublicVoucherDto>> GetPublicVouchersAsync(Guid userId)
    {
        var vouchers = await _voucherRepo.GetPublicVouchersAsync(Now);
        var claimed = (await _voucherRepo.GetClaimedVoucherIdsAsync(userId)).ToHashSet();

        return vouchers.Select(v => new PublicVoucherDto
        {
            Id = v.Id,
            Code = v.Code,
            Name = v.Name,
            Description = v.Description,
            DiscountType = v.DiscountType,
            DiscountValue = v.DiscountValue,
            MaxDiscount = v.MaxDiscount,
            MinOrderValue = v.MinOrderValue,
            TotalQuantity = v.TotalQuantity,
            RemainingQuantity = Math.Max(0, v.TotalQuantity - v.ClaimedCount),
            StartsAt = v.StartsAt,
            EndsAt = v.EndsAt,
            IsClaimed = claimed.Contains(v.Id)
        }).ToList();
    }

    public async Task<MyVoucherDto> ClaimVoucherAsync(Guid voucherId, Guid userId)
    {
        var voucher = await GetVoucherOrThrowAsync(voucherId);
        return await ClaimInternalAsync(voucher, userId);
    }

    public async Task<MyVoucherDto> ClaimVoucherByCodeAsync(string code, Guid userId)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            throw new InvalidOperationException("Vui lòng nhập mã voucher.");
        }

        var voucher = await _voucherRepo.GetByCodeAsync(VoucherCalculator.NormalizeCode(code));
        if (voucher == null)
        {
            throw new KeyNotFoundException("Mã voucher không tồn tại.");
        }

        return await ClaimInternalAsync(voucher, userId);
    }

    public async Task<List<MyVoucherDto>> GetMyVouchersAsync(Guid userId, decimal? subtotal = null)
    {
        var now = Now;
        var userVouchers = await _voucherRepo.GetUserVouchersAsync(userId);
        var result = userVouchers.Select(uv => MapToMyDto(uv, uv.Voucher, now, subtotal)).ToList();

        // Có thể dùng lên đầu, ưu tiên voucher giảm nhiều nhất
        return result
            .OrderBy(x => x.Status == "available" ? 0 : x.Status == "upcoming" ? 1 : 2)
            .ThenByDescending(x => x.IsApplicable == true)
            .ThenByDescending(x => x.EstimatedDiscount ?? 0)
            .ThenBy(x => x.EndsAt)
            .ToList();
    }

    // =====================================================================
    // HELPERS
    // =====================================================================

    private async Task<MyVoucherDto> ClaimInternalAsync(Voucher voucher, Guid userId)
    {
        var now = Now;

        if (await _voucherRepo.HasClaimedAsync(voucher.Id, userId))
        {
            throw new InvalidOperationException("Bạn đã lưu voucher này rồi.");
        }
        if (!voucher.IsActive)
        {
            throw new InvalidOperationException("Voucher đã ngừng áp dụng.");
        }
        if (now > voucher.EndsAt)
        {
            throw new InvalidOperationException("Voucher đã hết hạn.");
        }
        if (voucher.ClaimedCount >= voucher.TotalQuantity)
        {
            throw new InvalidOperationException("Voucher đã hết lượt lưu.");
        }

        var userVoucher = await _voucherRepo.ClaimAsync(voucher.Id, userId, now);
        if (userVoucher == null)
        {
            // Bị người khác lấy mất suất cuối trong lúc xử lý
            throw new InvalidOperationException("Voucher đã hết lượt lưu.");
        }

        return MapToMyDto(userVoucher, voucher, now, null);
    }

    private async Task<Voucher> GetVoucherOrThrowAsync(Guid id)
    {
        return await _voucherRepo.GetByIdAsync(id)
               ?? throw new KeyNotFoundException("Không tìm thấy voucher.");
    }

    private static void ValidateRequest(CreateVoucherRequest request)
    {
        request.DiscountType = request.DiscountType?.Trim().ToLowerInvariant() ?? string.Empty;
        if (!VoucherDiscountType.IsValid(request.DiscountType))
        {
            throw new InvalidOperationException("Loại giảm giá không hợp lệ (chỉ 'percent' hoặc 'fixed').");
        }
        if (string.IsNullOrWhiteSpace(request.Code) || string.IsNullOrWhiteSpace(request.Name))
        {
            throw new InvalidOperationException("Vui lòng nhập đầy đủ mã và tên voucher.");
        }
        if (request.DiscountValue <= 0)
        {
            throw new InvalidOperationException("Giá trị giảm phải lớn hơn 0.");
        }
        if (request.DiscountType == VoucherDiscountType.Percent && request.DiscountValue > 100)
        {
            throw new InvalidOperationException("Giảm theo phần trăm không được vượt quá 100%.");
        }
        if (request.MinOrderValue < 0)
        {
            throw new InvalidOperationException("Giá trị đơn tối thiểu không hợp lệ.");
        }
        if (request.TotalQuantity < 1)
        {
            throw new InvalidOperationException("Số lượng voucher phải từ 1 trở lên.");
        }
        if (request.EndsAt <= request.StartsAt)
        {
            throw new InvalidOperationException("Thời gian kết thúc phải sau thời gian bắt đầu.");
        }
    }

    private static void ApplyRequest(Voucher voucher, CreateVoucherRequest request)
    {
        voucher.Name = request.Name.Trim();
        voucher.Description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim();
        voucher.DiscountType = request.DiscountType;
        voucher.DiscountValue = request.DiscountValue;
        voucher.MaxDiscount = request.DiscountType == VoucherDiscountType.Percent ? request.MaxDiscount : null;
        voucher.MinOrderValue = request.MinOrderValue;
        voucher.TotalQuantity = request.TotalQuantity;
        voucher.StartsAt = request.StartsAt.ToUniversalTime();
        voucher.EndsAt = request.EndsAt.ToUniversalTime();
        voucher.IsActive = request.IsActive;
        voucher.IsPublic = request.IsPublic;
    }

    private async Task<AdminVoucherDto> MapToAdminDtoAsync(Voucher voucher)
    {
        var usedCounts = await _voucherRepo.GetUsedCountsAsync(new[] { voucher.Id });
        return MapToAdminDto(voucher, usedCounts.GetValueOrDefault(voucher.Id), Now);
    }

    private static AdminVoucherDto MapToAdminDto(Voucher v, int usedCount, DateTimeOffset now) => new()
    {
        Id = v.Id,
        Code = v.Code,
        Name = v.Name,
        Description = v.Description,
        DiscountType = v.DiscountType,
        DiscountValue = v.DiscountValue,
        MaxDiscount = v.MaxDiscount,
        MinOrderValue = v.MinOrderValue,
        TotalQuantity = v.TotalQuantity,
        ClaimedCount = v.ClaimedCount,
        UsedCount = usedCount,
        StartsAt = v.StartsAt,
        EndsAt = v.EndsAt,
        IsActive = v.IsActive,
        IsPublic = v.IsPublic,
        DisplayStatus = VoucherCalculator.GetDisplayStatus(v, now),
        CreatedAt = v.CreatedAt
    };

    private static MyVoucherDto MapToMyDto(UserVoucher uv, Voucher v, DateTimeOffset now, decimal? subtotal)
    {
        string status;
        if (uv.Status == UserVoucherStatus.Used)
        {
            status = "used";
        }
        else
        {
            status = VoucherCalculator.GetDisplayStatus(v, now) switch
            {
                "running" => "available",
                var other => other // upcoming | expired | disabled
            };
        }

        var dto = new MyVoucherDto
        {
            UserVoucherId = uv.Id,
            VoucherId = v.Id,
            Code = v.Code,
            Name = v.Name,
            Description = v.Description,
            DiscountType = v.DiscountType,
            DiscountValue = v.DiscountValue,
            MaxDiscount = v.MaxDiscount,
            MinOrderValue = v.MinOrderValue,
            StartsAt = v.StartsAt,
            EndsAt = v.EndsAt,
            Status = status,
            ClaimedAt = uv.ClaimedAt,
            UsedAt = uv.UsedAt,
            OrderId = uv.OrderId,
            UsedDiscountAmount = uv.DiscountAmount
        };

        if (subtotal.HasValue)
        {
            if (status == "used")
            {
                dto.IsApplicable = false;
                dto.IneligibleReason = "Voucher đã được sử dụng.";
            }
            else
            {
                var reason = VoucherCalculator.GetIneligibleReason(v, subtotal.Value, now);
                dto.IsApplicable = reason == null;
                dto.IneligibleReason = reason;
                dto.EstimatedDiscount = reason == null ? VoucherCalculator.CalculateDiscount(v, subtotal.Value) : null;
            }
        }

        return dto;
    }
}
