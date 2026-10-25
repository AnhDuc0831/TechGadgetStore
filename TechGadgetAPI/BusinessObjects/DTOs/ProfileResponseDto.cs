namespace BusinessObjects.DTOs;

public class ProfileResponseDto
{
    public Guid Id { get; set; }
    public string? FullName { get; set; }
    public string? AvatarUrl { get; set; }
    public string? Phone { get; set; }
    public string Role { get; set; } = null!;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}
