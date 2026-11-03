using Microsoft.AspNetCore.Http;

namespace Services.Interfaces;

public interface ICloudinaryService
{
    Task<string?> UploadImageAsync(IFormFile file, string folder = "tech_gadgets/products");
    Task<List<string>> UploadImagesAsync(IEnumerable<IFormFile> files, string folder = "tech_gadgets/products");
}
