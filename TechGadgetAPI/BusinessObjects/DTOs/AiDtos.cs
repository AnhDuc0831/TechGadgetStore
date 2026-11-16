using System.Text.Json.Serialization;

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
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("categoryHint")]
    public string CategoryHint { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string? CategoryAlias { set { if (string.IsNullOrWhiteSpace(CategoryHint) && !string.IsNullOrWhiteSpace(value)) CategoryHint = value; } }

    [JsonPropertyName("brandHint")]
    public string BrandHint { get; set; } = string.Empty;

    [JsonPropertyName("brand")]
    public string? BrandAlias { set { if (string.IsNullOrWhiteSpace(BrandHint) && !string.IsNullOrWhiteSpace(value)) BrandHint = value; } }

    [JsonPropertyName("basePrice")]
    public decimal BasePrice { get; set; }

    [JsonPropertyName("discountPrice")]
    public decimal? DiscountPrice { get; set; }

    [JsonPropertyName("price")]
    public decimal? PriceAlias { set { if (BasePrice <= 0 && value.HasValue) BasePrice = value.Value; } }

    [JsonPropertyName("base_price")]
    public decimal? BasePriceSnake { set { if (BasePrice <= 0 && value.HasValue) BasePrice = value.Value; } }

    [JsonPropertyName("discount_price")]
    public decimal? DiscountPriceSnake { set { if (DiscountPrice == null && value.HasValue) DiscountPrice = value.Value; } }

    [JsonPropertyName("stock")]
    public int Stock { get; set; }

    [JsonPropertyName("sku")]
    public string Sku { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("specifications")]
    public Dictionary<string, object> Specifications { get; set; } = new();

    [JsonPropertyName("source")]
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
