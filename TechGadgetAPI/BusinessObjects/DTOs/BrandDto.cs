namespace BusinessObjects.DTOs;

public class BrandDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = null!;
    public string? LogoUrl { get; set; }
}
