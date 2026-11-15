using BusinessObjects.DTOs;
using BusinessObjects.Models;
using Repositories.Interfaces;
using Services.Interfaces;

namespace Services.Implementations;

public class BrandService : IBrandService
{
    public const int MaxNameLength = 100;
    private const string LogoFolder = "tech_gadgets/brands";

    private readonly IBrandRepository _brandRepository;
    private readonly ICloudinaryService _cloudinary;

    public BrandService(IBrandRepository brandRepository, ICloudinaryService cloudinary)
    {
        _brandRepository = brandRepository;
        _cloudinary = cloudinary;
    }

    public async Task<List<BrandDto>> GetAllBrandsAsync()
    {
        var brands = await _brandRepository.GetAllAsync();
        return brands.Select(b => new BrandDto
        {
            Id = b.Id,
            Name = b.Name,
            LogoUrl = b.LogoUrl
        }).ToList();
    }

    // =====================================================================
    // ADMIN
    // =====================================================================

    public async Task<List<AdminBrandDto>> GetAdminBrandsAsync()
    {
        var rows = await _brandRepository.GetAllWithProductCountAsync();
        return rows.Select(r => MapToAdminDto(r.Brand, r.ProductCount)).ToList();
    }

    public async Task<AdminBrandDto> CreateBrandAsync(SaveBrandRequest request)
    {
        var name = await ValidateNameAsync(request.Name, excludeId: null);

        string? logoUrl = null;
        if (request.LogoFile is { Length: > 0 } file)
        {
            ImageFileRules.EnsureValid(file);
            logoUrl = await _cloudinary.UploadImageAsync(file, LogoFolder);
        }

        var now = DateTimeOffset.UtcNow;
        var brand = new Brand
        {
            Id = Guid.NewGuid(),
            Name = name,
            LogoUrl = logoUrl,
            CreatedAt = now,
            UpdatedAt = now
        };

        await _brandRepository.AddAsync(brand);
        return MapToAdminDto(brand, 0);
    }

    public async Task<AdminBrandDto> UpdateBrandAsync(Guid id, SaveBrandRequest request)
    {
        var brand = await _brandRepository.GetByIdAsync(id)
                    ?? throw new KeyNotFoundException("Không tìm thấy thương hiệu.");

        var name = await ValidateNameAsync(request.Name, excludeId: id);

        if (request.LogoFile is { Length: > 0 } file)
        {
            ImageFileRules.EnsureValid(file);
            brand.LogoUrl = await _cloudinary.UploadImageAsync(file, LogoFolder);
        }
        else if (request.RemoveLogo)
        {
            brand.LogoUrl = null;
        }

        brand.Name = name;
        await _brandRepository.UpdateAsync(brand);

        var count = await _brandRepository.CountProductsAsync(id);
        return MapToAdminDto(brand, count);
    }

    public async Task DeleteBrandAsync(Guid id)
    {
        var brand = await _brandRepository.GetByIdAsync(id)
                    ?? throw new KeyNotFoundException("Không tìm thấy thương hiệu.");

        var count = await _brandRepository.CountProductsAsync(id);
        if (count > 0)
        {
            throw new InvalidOperationException(
                $"Thương hiệu '{brand.Name}' đang có {count} sản phẩm. Hãy chuyển các sản phẩm sang thương hiệu khác trước khi xóa.");
        }

        await _brandRepository.DeleteAsync(brand);
    }

    // =====================================================================
    // HELPERS
    // =====================================================================

    private async Task<string> ValidateNameAsync(string? rawName, Guid? excludeId)
    {
        var name = rawName?.Trim() ?? string.Empty;
        if (name.Length == 0)
        {
            throw new InvalidOperationException("Vui lòng nhập tên thương hiệu.");
        }
        if (name.Length > MaxNameLength)
        {
            throw new InvalidOperationException($"Tên thương hiệu tối đa {MaxNameLength} ký tự.");
        }
        if (await _brandRepository.NameExistsAsync(name, excludeId))
        {
            throw new InvalidOperationException($"Thương hiệu '{name}' đã tồn tại.");
        }
        return name;
    }

    private static AdminBrandDto MapToAdminDto(Brand b, int productCount) => new()
    {
        Id = b.Id,
        Name = b.Name,
        LogoUrl = b.LogoUrl,
        ProductCount = productCount,
        CreatedAt = b.CreatedAt
    };
}
