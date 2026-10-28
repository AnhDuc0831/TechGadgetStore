class DashboardOverview {
  final DashboardSummary summary;
  final List<ChartDataPoint> chartData;
  final List<OrderStatusCount> orderStatusDistribution;
  final List<TopSellingProduct> topSellingProducts;
  final List<LowStockItem> lowStockAlerts;

  DashboardOverview({
    required this.summary,
    required this.chartData,
    required this.orderStatusDistribution,
    required this.topSellingProducts,
    required this.lowStockAlerts,
  });

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    return DashboardOverview(
      summary: DashboardSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
      chartData: (json['chartData'] as List<dynamic>? ?? [])
          .map((e) => ChartDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      orderStatusDistribution: (json['orderStatusDistribution'] as List<dynamic>? ?? [])
          .map((e) => OrderStatusCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      topSellingProducts: (json['topSellingProducts'] as List<dynamic>? ?? [])
          .map((e) => TopSellingProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      lowStockAlerts: (json['lowStockAlerts'] as List<dynamic>? ?? [])
          .map((e) => LowStockItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DashboardSummary {
  final double totalRevenue;
  final double totalProfit;
  final double profitMarginPercentage;
  final int totalOrders;
  final int deliveredOrders;
  final int pendingOrders;
  final int cancelledOrders;
  final int totalProducts;
  final int lowStockProductsCount;
  final int outOfStockProductsCount;
  final String period;

  DashboardSummary({
    required this.totalRevenue,
    required this.totalProfit,
    required this.profitMarginPercentage,
    required this.totalOrders,
    required this.deliveredOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.totalProducts,
    required this.lowStockProductsCount,
    required this.outOfStockProductsCount,
    required this.period,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (json['totalProfit'] as num?)?.toDouble() ?? 0.0,
      profitMarginPercentage: (json['profitMarginPercentage'] as num?)?.toDouble() ?? 0.0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      deliveredOrders: (json['deliveredOrders'] as num?)?.toInt() ?? 0,
      pendingOrders: (json['pendingOrders'] as num?)?.toInt() ?? 0,
      cancelledOrders: (json['cancelledOrders'] as num?)?.toInt() ?? 0,
      totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
      lowStockProductsCount: (json['lowStockProductsCount'] as num?)?.toInt() ?? 0,
      outOfStockProductsCount: (json['outOfStockProductsCount'] as num?)?.toInt() ?? 0,
      period: json['period'] as String? ?? '30days',
    );
  }
}

class ChartDataPoint {
  final String date;
  final String label;
  final double revenue;
  final double profit;
  final int orderCount;

  ChartDataPoint({
    required this.date,
    required this.label,
    required this.revenue,
    required this.profit,
    required this.orderCount,
  });

  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    return ChartDataPoint(
      date: json['date'] as String? ?? '',
      label: json['label'] as String? ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0.0,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class OrderStatusCount {
  final String status;
  final String statusNameVi;
  final int count;
  final double percentage;

  OrderStatusCount({
    required this.status,
    required this.statusNameVi,
    required this.count,
    required this.percentage,
  });

  factory OrderStatusCount.fromJson(Map<String, dynamic> json) {
    return OrderStatusCount(
      status: json['status'] as String? ?? '',
      statusNameVi: json['statusNameVi'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TopSellingProduct {
  final String productId;
  final String productName;
  final String? thumbnailUrl;
  final int unitsSold;
  final double totalRevenue;
  final double totalProfit;

  TopSellingProduct({
    required this.productId,
    required this.productName,
    this.thumbnailUrl,
    required this.unitsSold,
    required this.totalRevenue,
    required this.totalProfit,
  });

  factory TopSellingProduct.fromJson(Map<String, dynamic> json) {
    return TopSellingProduct(
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      unitsSold: (json['unitsSold'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (json['totalProfit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LowStockItem {
  final String variantId;
  final String productId;
  final String productName;
  final String sku;
  final int stockQuantity;
  final double price;

  LowStockItem({
    required this.variantId,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.stockQuantity,
    required this.price,
  });

  factory LowStockItem.fromJson(Map<String, dynamic> json) {
    return LowStockItem(
      variantId: json['variantId'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

