namespace BusinessObjects.DTOs;

public record AiStatusResponse(bool Configured, string Model, string Message);

public record DraftProductRequest(string Prompt);

public record AiChatRequest(
    string Message,
    string? Role = "customer",
    string? ProductId = null,
    List<ChatMessageDto>? History = null);

public record ChatMessageDto(string Role, string Content);

public class ProductRecommendationDto
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Slug { get; set; } = string.Empty;
    public decimal BasePrice { get; set; }
    public decimal? DiscountPrice { get; set; }
    public string? ThumbnailUrl { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string BrandName { get; set; } = string.Empty;
    public string? Reason { get; set; }
}

public class ProductDraftDto
{
    public string Name { get; set; } = string.Empty;
    public string CategoryHint { get; set; } = string.Empty;
    public string BrandHint { get; set; } = string.Empty;
    public decimal BasePrice { get; set; }
    public decimal? DiscountPrice { get; set; }
    public int Stock { get; set; }
    public string Sku { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public Dictionary<string, object> Specifications { get; set; } = new();
    public string Source { get; set; } = "Google Gemini";
}

public class TopProductSnapshotDto
{
    public string Name { get; set; } = string.Empty;
    public int UnitsSold { get; set; }
    public decimal Revenue { get; set; }
}

public class LowStockSnapshotDto
{
    public string Name { get; set; } = string.Empty;
    public string Sku { get; set; } = string.Empty;
    public int Stock { get; set; }
}

public class DashboardSnapshotDto
{
    public string Period { get; set; } = "30days";
    public decimal TotalRevenue { get; set; }
    public decimal TotalProfit { get; set; }
    public double ProfitMarginPercentage { get; set; }
    public int TotalOrders { get; set; }
    public int DeliveredOrders { get; set; }
    public int PendingOrders { get; set; }
    public int CancelledOrders { get; set; }
    public int TotalProducts { get; set; }
    public int LowStockProductsCount { get; set; }
    public int OutOfStockProductsCount { get; set; }
    public List<TopProductSnapshotDto> TopSellingProducts { get; set; } = new();
    public List<LowStockSnapshotDto> LowStockAlerts { get; set; } = new();
}

public class AiChatResponseDto
{
    public string Reply { get; set; } = string.Empty;
    public ProductDraftDto? ProductDraft { get; set; }
    public List<ProductRecommendationDto>? RecommendedProducts { get; set; }
    public DashboardSnapshotDto? DashboardSnapshot { get; set; }
    public bool IsConfigured { get; set; }
    public string Source { get; set; } = "Google Gemini";
    public bool IsFallback { get; set; } = false;
    public string? ErrorDetail { get; set; }
}
