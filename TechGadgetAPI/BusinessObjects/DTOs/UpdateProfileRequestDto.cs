using System.ComponentModel.DataAnnotations;

namespace BusinessObjects.DTOs;

public class UpdateProfileRequestDto
{
    [MaxLength(100, ErrorMessage = "Full name cannot exceed 100 characters.")]
    public string? FullName { get; set; }

    [Url(ErrorMessage = "Avatar URL must be a valid URL.")]
    public string? AvatarUrl { get; set; }

    [Phone(ErrorMessage = "Invalid phone number format.")]
    [MaxLength(20, ErrorMessage = "Phone cannot exceed 20 characters.")]
    public string? Phone { get; set; }
}
