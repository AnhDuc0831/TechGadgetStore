using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using BusinessObjects.Models;
using Microsoft.EntityFrameworkCore;

namespace DataAccessObjects;

public class DashboardDAO
{
    private readonly TechGadgetDbContext _context;

    public DashboardDAO(TechGadgetDbContext context)
    {
        _context = context;
    }

    public async Task<DashboardOverviewDto> GetOverviewAsync(DashboardQueryParams query)
    {
        var (startDate, endDate) = ResolveDateRange(query);

        // 1. Base query for orders in period
        var ordersInPeriod = await _context.Orders
            .AsNoTracking()
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.ProductVariant)
            .Where(o => o.CreatedAt >= startDate && o.CreatedAt <= endDate)
            .ToListAsync();

        // 2. Successful / Paid orders for Revenue and Profit calculation:
        // Count only Paid orders (PayOS) and Completed/Delivered orders (COD)
        var successfulOrders = ordersInPeriod
            .Where(o =>
                (o.PaymentMethod == PaymentMethod.PayOS && o.PaymentStatus == PaymentStatus.Paid) ||
                (o.PaymentMethod == PaymentMethod.Cod && (o.Status == OrderStatus.Completed || o.Status == OrderStatus.Delivered)) ||
                (o.PaymentMethod != PaymentMethod.PayOS && o.PaymentMethod != PaymentMethod.Cod && (o.Status == OrderStatus.Completed || o.Status == OrderStatus.Delivered || o.PaymentStatus == PaymentStatus.Paid)))
            .ToList();

        var totalRevenue = successfulOrders.Sum(o => o.TotalAmount);

        decimal totalProfit = 0;
        foreach (var order in successfulOrders)
        {
            foreach (var item in order.OrderItems)
            {
                var costPrice = item.CostPrice > 0 
                    ? item.CostPrice 
                    : (item.ProductVariant?.CostPrice > 0 ? item.ProductVariant.CostPrice : Math.Round(item.UnitPrice * 0.7m, 2));

                totalProfit += (item.UnitPrice - costPrice) * item.Quantity;
            }
        }

        var profitMargin = totalRevenue > 0 ? (double)Math.Round((totalProfit / totalRevenue) * 100, 2) : 0;

        // 3. Products & Stock Counts
        var totalProducts = await _context.Products.CountAsync(p => p.IsActive);
        var lowStockVariants = await _context.ProductVariants
            .AsNoTracking()
            .Include(v => v.Product)
            .Where(v => v.IsActive && v.StockQuantity <= query.LowStockThreshold)
            .OrderBy(v => v.StockQuantity)
            .ToListAsync();

        var lowStockCount = lowStockVariants.Count(v => v.StockQuantity > 0);
        var outOfStockCount = lowStockVariants.Count(v => v.StockQuantity == 0);

        // 4. Order Status Distribution
        var totalOrders = ordersInPeriod.Count;
        var orderStatusDistribution = Enum.GetValues<OrderStatus>()
            .Select(status =>
            {
                var count = ordersInPeriod.Count(o => o.Status == status);
                var pct = totalOrders > 0 ? Math.Round((double)count / totalOrders * 100, 1) : 0;
                return new OrderStatusCountDto
                {
                    Status = status.ToString(),
                    StatusNameVi = GetStatusNameVi(status),
                    Count = count,
                    Percentage = pct
                };
            })
            .ToList();

        // 5. Chart Data Points (continuous dates)
        var chartData = GenerateChartData(successfulOrders, startDate, endDate);

        // 6. Top Selling Products
        var topSellingProducts = successfulOrders
            .SelectMany(o => o.OrderItems)
            .GroupBy(oi => new { oi.ProductVariant.ProductId, oi.ProductName })
            .Select(g =>
            {
                var units = g.Sum(x => x.Quantity);
                var rev = g.Sum(x => x.UnitPrice * x.Quantity);
                var prof = g.Sum(x =>
                {
                    var cost = x.CostPrice > 0
                        ? x.CostPrice
                        : (x.ProductVariant?.CostPrice > 0 ? x.ProductVariant.CostPrice : Math.Round(x.UnitPrice * 0.7m, 2));
                    return (x.UnitPrice - cost) * x.Quantity;
                });
                return new TopProductDto
                {
                    ProductId = g.Key.ProductId,
                    ProductName = g.Key.ProductName,
                    UnitsSold = units,
                    TotalRevenue = rev,
                    TotalProfit = prof
                };
            })
            .OrderByDescending(tp => tp.TotalRevenue)
            .Take(query.TopProductsLimit)
            .ToList();

        // Fetch thumbnails for top selling products
        if (topSellingProducts.Count > 0)
        {
            var productIds = topSellingProducts.Select(tp => tp.ProductId).ToList();
            var thumbnails = await _context.Products
                .AsNoTracking()
                .Where(p => productIds.Contains(p.Id))
                .Select(p => new { p.Id, p.ThumbnailUrl })
                .ToDictionaryAsync(p => p.Id, p => p.ThumbnailUrl);

            foreach (var tp in topSellingProducts)
            {
                if (thumbnails.TryGetValue(tp.ProductId, out var thumb))
                {
                    tp.ThumbnailUrl = thumb;
                }
            }
        }

        // 7. Low Stock Alerts
        var lowStockAlerts = lowStockVariants
            .Take(10)
            .Select(v => new LowStockItemDto
            {
                VariantId = v.Id,
                ProductId = v.ProductId,
                ProductName = v.Product?.Name ?? "Sản phẩm",
                Sku = v.Sku,
                StockQuantity = v.StockQuantity,
                Price = (v.Product?.BasePrice ?? 0) + v.PriceAdjustment
            })
            .ToList();

        return new DashboardOverviewDto
        {
            Summary = new DashboardSummaryDto
            {
                TotalRevenue = totalRevenue,
                TotalProfit = totalProfit,
                ProfitMarginPercentage = profitMargin,
                TotalOrders = totalOrders,
                DeliveredOrders = ordersInPeriod.Count(o => o.Status == OrderStatus.Delivered),
                PendingOrders = ordersInPeriod.Count(o => o.Status == OrderStatus.Pending || o.Status == OrderStatus.Processing),
                CancelledOrders = ordersInPeriod.Count(o => o.Status == OrderStatus.Cancelled),
                TotalProducts = totalProducts,
                LowStockProductsCount = lowStockCount,
                OutOfStockProductsCount = outOfStockCount,
                Period = query.Period
            },
            ChartData = chartData,
            OrderStatusDistribution = orderStatusDistribution,
            TopSellingProducts = topSellingProducts,
            LowStockAlerts = lowStockAlerts
        };
    }

    private static (DateTimeOffset Start, DateTimeOffset End) ResolveDateRange(DashboardQueryParams query)
    {
        var now = DateTimeOffset.UtcNow;
        var end = query.EndDate ?? now;

        DateTimeOffset start;
        switch (query.Period.ToLowerInvariant())
        {
            case "today":
                start = new DateTimeOffset(now.Year, now.Month, now.Day, 0, 0, 0, TimeSpan.Zero);
                break;
            case "7days":
                start = new DateTimeOffset(now.Year, now.Month, now.Day, 0, 0, 0, TimeSpan.Zero).AddDays(-6);
                break;
            case "this_month":
                start = new DateTimeOffset(now.Year, now.Month, 1, 0, 0, 0, TimeSpan.Zero);
                break;
            case "this_year":
                start = new DateTimeOffset(now.Year, 1, 1, 0, 0, 0, TimeSpan.Zero);
                break;
            case "all":
                start = DateTimeOffset.MinValue;
                break;
            case "custom":
                start = query.StartDate ?? now.AddDays(-30);
                break;
            case "30days":
            default:
                start = new DateTimeOffset(now.Year, now.Month, now.Day, 0, 0, 0, TimeSpan.Zero).AddDays(-29);
                break;
        }

        return (start, end);
    }

    private static List<RevenueProfitChartPointDto> GenerateChartData(
        List<Order> orders,
        DateTimeOffset start,
        DateTimeOffset end)
    {
        var result = new List<RevenueProfitChartPointDto>();
        var spanDays = (end.Date - start.Date).TotalDays;

        // Group by day if span <= 60 days, otherwise group by month
        if (spanDays <= 60 && start != DateTimeOffset.MinValue)
        {
            var dayCount = (int)spanDays + 1;
            for (int i = 0; i < dayCount; i++)
            {
                var curDate = start.Date.AddDays(i);
                var ordersOnDay = orders.Where(o => o.CreatedAt.Date == curDate).ToList();

                var dayRevenue = ordersOnDay.Sum(o => o.TotalAmount);
                decimal dayProfit = 0;
                foreach (var o in ordersOnDay)
                {
                    foreach (var item in o.OrderItems)
                    {
                        var cost = item.CostPrice > 0
                            ? item.CostPrice
                            : (item.ProductVariant?.CostPrice > 0 ? item.ProductVariant.CostPrice : Math.Round(item.UnitPrice * 0.7m, 2));
                        dayProfit += (item.UnitPrice - cost) * item.Quantity;
                    }
                }

                result.Add(new RevenueProfitChartPointDto
                {
                    Date = curDate.ToString("yyyy-MM-dd"),
                    Label = curDate.ToString("dd/MM"),
                    Revenue = dayRevenue,
                    Profit = dayProfit,
                    OrderCount = ordersOnDay.Count
                });
            }
        }
        else
        {
            // Monthly grouping
            var monthlyGroup = orders
                .GroupBy(o => new { o.CreatedAt.Year, o.CreatedAt.Month })
                .OrderBy(g => g.Key.Year).ThenBy(g => g.Key.Month);

            foreach (var g in monthlyGroup)
            {
                var rev = g.Sum(o => o.TotalAmount);
                decimal prof = 0;
                foreach (var o in g)
                {
                    foreach (var item in o.OrderItems)
                    {
                        var cost = item.CostPrice > 0
                            ? item.CostPrice
                            : (item.ProductVariant?.CostPrice > 0 ? item.ProductVariant.CostPrice : Math.Round(item.UnitPrice * 0.7m, 2));
                        prof += (item.UnitPrice - cost) * item.Quantity;
                    }
                }

                result.Add(new RevenueProfitChartPointDto
                {
                    Date = $"{g.Key.Year}-{g.Key.Month:D2}-01",
                    Label = $"T{g.Key.Month}/{g.Key.Year}",
                    Revenue = rev,
                    Profit = prof,
                    OrderCount = g.Count()
                });
            }

            if (result.Count == 0)
            {
                result.Add(new RevenueProfitChartPointDto
                {
                    Date = DateTime.UtcNow.ToString("yyyy-MM-01"),
                    Label = $"T{DateTime.UtcNow.Month}/{DateTime.UtcNow.Year}",
                    Revenue = 0,
                    Profit = 0,
                    OrderCount = 0
                });
            }
        }

        return result;
    }

    private static string GetStatusNameVi(OrderStatus status) => status switch
    {
        OrderStatus.Pending => "Chờ duyệt",
        OrderStatus.Processing => "Đang xử lý",
        OrderStatus.Shipped => "Đang giao hàng",
        OrderStatus.Delivered => "Đã giao thành công",
        OrderStatus.Cancelled => "Đã hủy",
        _ => status.ToString()
    };
}

