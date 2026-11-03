using BusinessObjects.DTOs;
using BusinessObjects.Enums;
using BusinessObjects.Models;
using Microsoft.EntityFrameworkCore;

namespace DataAccessObjects;

public class DashboardDAO
{
    private readonly TechGadgetDbContext _context;
    private static readonly TimeSpan VnTimeZoneOffset = TimeSpan.FromHours(7); // Múi giờ Việt Nam (UTC+7)

    public DashboardDAO(TechGadgetDbContext context)
    {
        _context = context;
    }

    public async Task<DashboardOverviewDto> GetOverviewAsync(DashboardQueryParams query)
    {
        var (startDate, endDate) = ResolveDateRange(query);

        // 1. Lấy toàn bộ đơn hàng trong kỳ truy vấn kèm OrderItems, ProductVariant và Product
        var queryable = _context.Orders
            .AsNoTracking()
            .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.ProductVariant)
                    .ThenInclude(pv => pv.Product)
            .AsQueryable();

        if (query.Period.ToLowerInvariant() != "all")
        {
            queryable = queryable.Where(o => o.CreatedAt >= startDate && o.CreatedAt <= endDate);
        }
        else if (query.EndDate.HasValue)
        {
            queryable = queryable.Where(o => o.CreatedAt <= endDate);
        }

        var ordersInPeriod = await queryable.ToListAsync();

        // 2. Xác định các đơn hàng hợp lệ đem lại doanh thu thực tế:
        // - Loại trừ triệt để đơn đã hủy, hết hạn thanh toán, hoặc đã hoàn tiền
        // - Đơn thanh toán trước (PayOS, thẻ, chuyển khoản...): phải đã thanh toán thành công (PaymentStatus == Paid)
        // - Đơn COD: chỉ tính khi đã giao thành công/hoàn thành hoặc đã nhận tiền
        var successfulOrders = ordersInPeriod
            .Where(o =>
                o.Status != OrderStatus.Cancelled &&
                o.PaymentStatus != PaymentStatus.Cancelled &&
                o.PaymentStatus != PaymentStatus.Expired &&
                o.PaymentStatus != PaymentStatus.Refunded &&
                (
                    o.PaymentStatus == PaymentStatus.Paid ||
                    (o.PaymentMethod == PaymentMethod.Cod && (o.Status == OrderStatus.Completed || o.Status == OrderStatus.Delivered))
                ))
            .ToList();

        // Doanh thu thực thu từ các đơn hàng thành công
        var totalRevenue = successfulOrders.Sum(o => o.TotalAmount);

        // Lợi nhuận gộp thực tế = Tổng (Giá bán - Giá vốn thực) * Số lượng
        // Tuyệt đối không dùng hệ số giả 0.7m
        decimal totalProfit = 0;
        foreach (var order in successfulOrders)
        {
            foreach (var item in order.OrderItems)
            {
                var costPrice = item.CostPrice > 0
                    ? item.CostPrice
                    : (item.ProductVariant != null && item.ProductVariant.CostPrice > 0 ? item.ProductVariant.CostPrice : 0);

                totalProfit += (item.UnitPrice - costPrice) * item.Quantity;
            }
        }

        var profitMargin = totalRevenue > 0 ? (double)Math.Round((totalProfit / totalRevenue) * 100, 2) : 0;

        // 3. Đếm sản phẩm và biến thể tồn kho
        var totalProducts = await _context.Products.CountAsync(p => p.IsActive);
        var lowStockVariants = await _context.ProductVariants
            .AsNoTracking()
            .Include(v => v.Product)
            .Where(v => v.IsActive && v.StockQuantity <= query.LowStockThreshold)
            .OrderBy(v => v.StockQuantity)
            .ToListAsync();

        var lowStockCount = lowStockVariants.Count(v => v.StockQuantity > 0);
        var outOfStockCount = lowStockVariants.Count(v => v.StockQuantity == 0);

        // 4. Phân bố trạng thái đơn hàng (chuẩn hóa theo 5 trạng thái chuẩn nghiệp vụ)
        var totalOrders = ordersInPeriod.Count;
        var canonicalOrderGroups = ordersInPeriod
            .GroupBy(o => OrderStatusMapper.ToCanonical(o.Status))
            .ToDictionary(g => g.Key, g => g.Count());

        var standardStatuses = new[]
        {
            CanonicalOrderStatus.Pending,
            CanonicalOrderStatus.Confirmed,
            CanonicalOrderStatus.Shipping,
            CanonicalOrderStatus.Completed,
            CanonicalOrderStatus.Cancelled
        };

        var orderStatusDistribution = standardStatuses.Select(status =>
        {
            var count = canonicalOrderGroups.GetValueOrDefault(status, 0);
            var pct = totalOrders > 0 ? Math.Round((double)count / totalOrders * 100, 1) : 0;
            return new OrderStatusCountDto
            {
                Status = status.ToString(),
                StatusNameVi = GetCanonicalStatusNameVi(status),
                Count = count,
                Percentage = pct
            };
        }).ToList();

        // 5. Chuỗi dữ liệu biểu đồ Doanh thu & Lợi nhuận
        var chartData = GenerateChartData(successfulOrders, startDate, endDate);

        // 6. Top sản phẩm bán chạy nhất (gộp theo ProductId, dùng giá vốn thực tế)
        var topSellingProducts = successfulOrders
            .SelectMany(o => o.OrderItems)
            .Where(oi => oi.ProductVariant != null || !string.IsNullOrWhiteSpace(oi.ProductName))
            .GroupBy(oi => oi.ProductVariant != null && oi.ProductVariant.ProductId != Guid.Empty
                ? oi.ProductVariant.ProductId
                : (oi.ProductVariantId != Guid.Empty ? oi.ProductVariantId : Guid.NewGuid()))
            .Select(g =>
            {
                var firstItem = g.First();
                var productName = firstItem.ProductVariant?.Product?.Name
                    ?? CleanProductName(firstItem.ProductName);

                var units = g.Sum(x => x.Quantity);
                var rev = g.Sum(x => x.UnitPrice * x.Quantity);
                var prof = g.Sum(x =>
                {
                    var cost = x.CostPrice > 0
                        ? x.CostPrice
                        : (x.ProductVariant != null && x.ProductVariant.CostPrice > 0 ? x.ProductVariant.CostPrice : 0);
                    return (x.UnitPrice - cost) * x.Quantity;
                });

                return new TopProductDto
                {
                    ProductId = g.Key,
                    ProductName = productName,
                    ThumbnailUrl = firstItem.ProductVariant?.Product?.ThumbnailUrl,
                    UnitsSold = units,
                    TotalRevenue = rev,
                    TotalProfit = prof
                };
            })
            .OrderByDescending(tp => tp.TotalRevenue)
            .Take(query.TopProductsLimit)
            .ToList();

        // Bổ sung thumbnail nếu thiếu
        var missingThumbIds = topSellingProducts
            .Where(tp => string.IsNullOrEmpty(tp.ThumbnailUrl) && tp.ProductId != Guid.Empty)
            .Select(tp => tp.ProductId)
            .ToList();

        if (missingThumbIds.Count > 0)
        {
            var thumbnails = await _context.Products
                .AsNoTracking()
                .Where(p => missingThumbIds.Contains(p.Id))
                .Select(p => new { p.Id, p.ThumbnailUrl })
                .ToDictionaryAsync(p => p.Id, p => p.ThumbnailUrl);

            foreach (var tp in topSellingProducts)
            {
                if (string.IsNullOrEmpty(tp.ThumbnailUrl) && thumbnails.TryGetValue(tp.ProductId, out var thumb))
                {
                    tp.ThumbnailUrl = thumb;
                }
            }
        }

        // 7. Cảnh báo sắp hết hàng / hết hàng
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
                DeliveredOrders = canonicalOrderGroups.GetValueOrDefault(CanonicalOrderStatus.Completed, 0),
                PendingOrders = canonicalOrderGroups.GetValueOrDefault(CanonicalOrderStatus.Pending, 0),
                CancelledOrders = canonicalOrderGroups.GetValueOrDefault(CanonicalOrderStatus.Cancelled, 0),
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
        var nowVn = DateTimeOffset.UtcNow.ToOffset(VnTimeZoneOffset);
        var endUtc = (query.EndDate ?? DateTimeOffset.UtcNow).ToUniversalTime();

        DateTimeOffset startUtc;
        switch (query.Period.ToLowerInvariant())
        {
            case "today":
                startUtc = new DateTimeOffset(nowVn.Year, nowVn.Month, nowVn.Day, 0, 0, 0, VnTimeZoneOffset).ToUniversalTime();
                break;
            case "7days":
                startUtc = new DateTimeOffset(nowVn.Year, nowVn.Month, nowVn.Day, 0, 0, 0, VnTimeZoneOffset).AddDays(-6).ToUniversalTime();
                break;
            case "this_month":
                startUtc = new DateTimeOffset(nowVn.Year, nowVn.Month, 1, 0, 0, 0, VnTimeZoneOffset).ToUniversalTime();
                break;
            case "this_year":
                startUtc = new DateTimeOffset(nowVn.Year, 1, 1, 0, 0, 0, VnTimeZoneOffset).ToUniversalTime();
                break;
            case "all":
                startUtc = DateTimeOffset.MinValue;
                break;
            case "custom":
                startUtc = (query.StartDate ?? nowVn.AddDays(-30)).ToUniversalTime();
                break;
            case "30days":
            default:
                startUtc = new DateTimeOffset(nowVn.Year, nowVn.Month, nowVn.Day, 0, 0, 0, VnTimeZoneOffset).AddDays(-29).ToUniversalTime();
                break;
        }

        return (startUtc, endUtc);
    }

    private static List<RevenueProfitChartPointDto> GenerateChartData(
        List<Order> orders,
        DateTimeOffset start,
        DateTimeOffset end)
    {
        var result = new List<RevenueProfitChartPointDto>();

        // Giới hạn ngày theo múi giờ Việt Nam
        var startVnDate = start == DateTimeOffset.MinValue
            ? DateTimeOffset.UtcNow.ToOffset(VnTimeZoneOffset).Date.AddMonths(-11)
            : start.ToOffset(VnTimeZoneOffset).Date;
        var endVnDate = end.ToOffset(VnTimeZoneOffset).Date;

        var spanDays = (endVnDate - startVnDate).TotalDays;

        if (spanDays <= 60 && start != DateTimeOffset.MinValue)
        {
            var dayCount = (int)spanDays + 1;
            for (int i = 0; i < dayCount; i++)
            {
                var curDate = startVnDate.AddDays(i);
                var ordersOnDay = orders.Where(o =>
                {
                    var orderDate = (o.PaidAt ?? o.CreatedAt).ToOffset(VnTimeZoneOffset).Date;
                    return orderDate == curDate;
                }).ToList();

                var dayRevenue = ordersOnDay.Sum(o => o.TotalAmount);
                decimal dayProfit = 0;
                foreach (var o in ordersOnDay)
                {
                    foreach (var item in o.OrderItems)
                    {
                        var cost = item.CostPrice > 0
                            ? item.CostPrice
                            : (item.ProductVariant != null && item.ProductVariant.CostPrice > 0 ? item.ProductVariant.CostPrice : 0);
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
            // Nhóm theo từng tháng thực tế
            var monthlyGroup = orders
                .GroupBy(o =>
                {
                    var orderVn = (o.PaidAt ?? o.CreatedAt).ToOffset(VnTimeZoneOffset);
                    return new { orderVn.Year, orderVn.Month };
                })
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
                            : (item.ProductVariant != null && item.ProductVariant.CostPrice > 0 ? item.ProductVariant.CostPrice : 0);
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
                var nowVn = DateTimeOffset.UtcNow.ToOffset(VnTimeZoneOffset);
                result.Add(new RevenueProfitChartPointDto
                {
                    Date = nowVn.ToString("yyyy-MM-01"),
                    Label = $"T{nowVn.Month}/{nowVn.Year}",
                    Revenue = 0,
                    Profit = 0,
                    OrderCount = 0
                });
            }
        }

        return result;
    }

    private static string CleanProductName(string rawName)
    {
        if (string.IsNullOrWhiteSpace(rawName)) return "Sản phẩm";
        var idx = rawName.IndexOf(" - ", StringComparison.Ordinal);
        return idx > 0 ? rawName.Substring(0, idx).Trim() : rawName.Trim();
    }

    private static string GetCanonicalStatusNameVi(CanonicalOrderStatus status) => status switch
    {
        CanonicalOrderStatus.Pending => "Chờ duyệt",
        CanonicalOrderStatus.Confirmed => "Đã xác nhận",
        CanonicalOrderStatus.Shipping => "Đang giao hàng",
        CanonicalOrderStatus.Completed => "Hoàn thành",
        CanonicalOrderStatus.Cancelled => "Đã hủy",
        _ => status.ToString()
    };
}
