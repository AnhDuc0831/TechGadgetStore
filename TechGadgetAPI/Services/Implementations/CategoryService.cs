using BusinessObjects.DTOs;
using BusinessObjects.Helpers;
using BusinessObjects.Models;
using Repositories.Interfaces;
using Services.Interfaces;

namespace Services.Implementations;

public class CategoryService : ICategoryService
{
    public const int MaxNameLength = 100;
    public const int MaxDescriptionLength = 500;
    private const string ImageFolder = "tech_gadgets/categories";

    private readonly ICategoryRepository _categoryRepository;
    private readonly ICloudinaryService _cloudinary;

    public CategoryService(ICategoryRepository categoryRepository, ICloudinaryService cloudinary)
    {
        _categoryRepository = categoryRepository;
        _cloudinary = cloudinary;
    }

    public async Task<List<CategoryDto>> GetAllCategoriesAsync()
    {
        var categories = await _categoryRepository.GetAllCategoriesAsync();
        return categories
            .OrderBy(c => c.Name)
            .Select(c => new CategoryDto
            {
                Id = c.Id,
                Name = c.Name,
                Slug = c.Slug,
                Description = c.Description,
                ImageUrl = c.ImageUrl
            })
            .ToList();
    }

    // =====================================================================
    // ADMIN
    // =====================================================================

    public async Task<List<AdminCategoryDto>> GetAdminCategoriesAsync()
    {
        var rows = await _categoryRepository.GetAllWithProductCountAsync();
        return rows.Select(r => MapToAdminDto(r.Category, r.ProductCount)).ToList();
    }

    public async Task<AdminCategoryDto> CreateCategoryAsync(SaveCategoryRequest request)
    {
        var (name, slug, description) = await ValidateAsync(request, excludeId: null);

        string? imageUrl = null;
        if (request.ImageFile is { Length: > 0 } file)
        {
            ImageFileRules.EnsureValid(file);
            imageUrl = await _cloudinary.UploadImageAsync(file, ImageFolder);
        }

        var now = DateTimeOffset.UtcNow;
        var category = new Category
        {
            Id = Guid.NewGuid(),
            Name = name,
            Slug = slug,
            Description = description,
            ImageUrl = imageUrl,
            CreatedAt = now,
            UpdatedAt = now
        };

        await _categoryRepository.AddAsync(category);
        return MapToAdminDto(category, 0);
    }

    public async Task<AdminCategoryDto> UpdateCategoryAsync(Guid id, SaveCategoryRequest request)
    {
        var category = await _categoryRepository.GetByIdAsync(id)
                       ?? throw new KeyNotFoundException("Không tìm thấy danh mục.");

        var (name, slug, description) = await ValidateAsync(request, excludeId: id);

        if (request.ImageFile is { Length: > 0 } file)
        {
            ImageFileRules.EnsureValid(file);
            category.ImageUrl = await _cloudinary.UploadImageAsync(file, ImageFolder);
        }
        else if (request.RemoveImage)
        {
            category.ImageUrl = null;
        }

        category.Name = name;
        category.Slug = slug;
        category.Description = description;
        await _categoryRepository.UpdateAsync(category);

        var count = await _categoryRepository.CountProductsAsync(id);
        return MapToAdminDto(category, count);
    }

    public async Task DeleteCategoryAsync(Guid id)
    {
        var category = await _categoryRepository.GetByIdAsync(id)
                       ?? throw new KeyNotFoundException("Không tìm thấy danh mục.");

        var count = await _categoryRepository.CountProductsAsync(id);
        if (count > 0)
        {
            throw new InvalidOperationException(
                $"Danh mục '{category.Name}' đang có {count} sản phẩm. Hãy chuyển các sản phẩm sang danh mục khác trước khi xóa.");
        }

        await _categoryRepository.DeleteAsync(category);
    }

    // =====================================================================
    // HELPERS
    // =====================================================================

    private async Task<(string Name, string Slug, string? Description)> ValidateAsync(SaveCategoryRequest request, Guid? excludeId)
    {
        var name = request.Name?.Trim() ?? string.Empty;
        if (name.Length == 0)
        {
            throw new InvalidOperationException("Vui lòng nhập tên danh mục.");
        }
        if (name.Length > MaxNameLength)
        {
            throw new InvalidOperationException($"Tên danh mục tối đa {MaxNameLength} ký tự.");
        }

        var description = string.IsNullOrWhiteSpace(request.Description) ? null : request.Description.Trim();
        if (description?.Length > MaxDescriptionLength)
        {
            throw new InvalidOperationException($"Mô tả tối đa {MaxDescriptionLength} ký tự.");
        }

        // Slug: dùng slug admin nhập (đã chuẩn hóa) hoặc tự sinh từ tên
        var slug = SlugHelper.Generate(string.IsNullOrWhiteSpace(request.Slug) ? name : request.Slug);
        if (slug.Length == 0)
        {
            throw new InvalidOperationException("Không thể tạo đường dẫn (slug) từ tên danh mục. Vui lòng nhập slug.");
        }

        if (await _categoryRepository.NameExistsAsync(name, excludeId))
        {
            throw new InvalidOperationException($"Danh mục '{name}' đã tồn tại.");
        }
        if (await _categoryRepository.SlugExistsAsync(slug, excludeId))
        {
            throw new InvalidOperationException($"Đường dẫn '{slug}' đã được dùng cho danh mục khác.");
        }

        return (name, slug, description);
    }

    private static AdminCategoryDto MapToAdminDto(Category c, int productCount) => new()
    {
        Id = c.Id,
        Name = c.Name,
        Slug = c.Slug,
        Description = c.Description,
        ImageUrl = c.ImageUrl,
        ProductCount = productCount,
        CreatedAt = c.CreatedAt
    };
}
