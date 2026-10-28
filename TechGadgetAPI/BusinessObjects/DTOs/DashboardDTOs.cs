namespace BusinessObjects.DTOs;

public class DashboardOverviewDto
{
    public DashboardSummaryDto Summary { get; set; } = new();
    public List<RevenueProfitChartPointDto> ChartData { get; set; } = new();
    public List<OrderStatusCountDto> OrderStatusDistribution { get; set; } = new();
    public List<TopProductDto> TopSellingProducts { get; set; } = new();
    public List<LowStockItemDto> LowStockAlerts { get; set; } = new();
}

public class DashboardSummaryDto
{
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
    public string Period { get; set; } = "30days";
}

public class RevenueProfitChartPointDto
{
    public string Date { get; set; } = null!;
    public string Label { get; set; } = null!;
    public decimal Revenue { get; set; }
    public decimal Profit { get; set; }
    public int OrderCount { get; set; }
}

public class OrderStatusCountDto
{
    public string Status { get; set; } = null!;
    public string StatusNameVi { get; set; } = null!;
    public int Count { get; set; }
    public double Percentage { get; set; }
}

public class TopProductDto
{
    public Guid ProductId { get; set; }
    public string ProductName { get; set; } = null!;
    public string? ThumbnailUrl { get; set; }
    public int UnitsSold { get; set; }
    public decimal TotalRevenue { get; set; }
    public decimal TotalProfit { get; set; }
}

public class LowStockItemDto
{
    public Guid VariantId { get; set; }
    public Guid ProductId { get; set; }
    public string ProductName { get; set; } = null!;
    public string Sku { get; set; } = null!;
    public int StockQuantity { get; set; }
    public decimal Price { get; set; }
}

public class DashboardQueryParams
{
    public string Period { get; set; } = "30days"; // today, 7days, 30days, this_month, this_year, all, custom
    public DateTimeOffset? StartDate { get; set; }
    public DateTimeOffset? EndDate { get; set; }
    public int TopProductsLimit { get; set; } = 5;
    public int LowStockThreshold { get; set; } = 5;
}

