namespace BusinessObjects.DTOs;

public class CategorySummaryDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = null!;
    public string Slug { get; set; } = null!;
}
