using BusinessObjects.DTOs;
using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Services.Interfaces;

namespace Services.Implementations;

public class CloudinaryService : ICloudinaryService
{
    private readonly Cloudinary? _cloudinary;
    private readonly ILogger<CloudinaryService> _logger;

    public CloudinaryService(IOptions<CloudinaryOptions> options, ILogger<CloudinaryService> logger)
    {
        _logger = logger;
        var config = options.Value;

        if (!string.IsNullOrWhiteSpace(config.CloudName) &&
            !string.IsNullOrWhiteSpace(config.ApiKey) &&
            !string.IsNullOrWhiteSpace(config.ApiSecret) &&
            !config.CloudName.Contains("YOUR_"))
        {
            var account = new Account(config.CloudName, config.ApiKey, config.ApiSecret);
            _cloudinary = new Cloudinary(account);
            _cloudinary.Api.Secure = true;
        }
        else
        {
            _logger.LogWarning("Cloudinary credentials are not configured or still have placeholder values.");
        }
    }

    public async Task<string?> UploadImageAsync(IFormFile file, string folder = "tech_gadgets/products")
    {
        if (file.Length <= 0) return null;

        if (_cloudinary == null)
        {
            _logger.LogError("Không thể upload ảnh: Cloudinary chưa được cấu hình ApiKey / CloudName trong appsettings.json.");
            throw new InvalidOperationException("Cloudinary chưa được cấu hình thông tin xác thực trên máy chủ.");
        }

        await using var stream = file.OpenReadStream();
        var uploadParams = new ImageUploadParams
        {
            File = new FileDescription(file.FileName, stream),
            Folder = folder,
            UseFilename = false,
            UniqueFilename = true,
            Overwrite = false
        };

        var uploadResult = await _cloudinary.UploadAsync(uploadParams);
        if (uploadResult.Error != null)
        {
            _logger.LogError("Lỗi Cloudinary upload: {Message}", uploadResult.Error.Message);
            throw new Exception($"Cloudinary upload failed: {uploadResult.Error.Message}");
        }

        return uploadResult.SecureUrl?.ToString() ?? uploadResult.Url?.ToString();
    }

    public async Task<List<string>> UploadImagesAsync(IEnumerable<IFormFile> files, string folder = "tech_gadgets/products")
    {
        var urls = new List<string>();
        foreach (var file in files)
        {
            var url = await UploadImageAsync(file, folder);
            if (!string.IsNullOrEmpty(url))
            {
                urls.Add(url);
            }
        }
        return urls;
    }
}
