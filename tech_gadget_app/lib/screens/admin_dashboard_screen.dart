import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/dashboard.dart';
import '../providers/auth_provider.dart';
import '../services/dashboard_api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DashboardApiService _apiService = DashboardApiService();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  String _selectedPeriod = '30days';
  bool _isLoading = true;
  String? _errorMessage;
  DashboardOverview? _overview;

  final Map<String, String> _periodOptions = {
    'today': 'Hôm nay',
    '7days': '7 ngày qua',
    '30days': '30 ngày qua',
    'this_month': 'Tháng này',
    'all': 'Tất cả thời gian',
  };

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.accessToken;

      final data = await _apiService.getOverview(
        period: _selectedPeriod,
        accessToken: token,
      );

      if (mounted) {
        setState(() {
          _overview = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thống Kê Tổng Quan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Bảng điều khiển Quản trị viên (Admin)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDashboardData,
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tổng hợp dữ liệu thống kê...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 15),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final summary = _overview?.summary;
    if (summary == null) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thanh bộ lọc thời gian
            _buildPeriodSelector(),
            const SizedBox(height: 16),

            // 4 thẻ chỉ số nhanh KPI
            _buildKpiGrid(summary),
            const SizedBox(height: 24),

            // Biểu đồ Doanh thu & Lợi nhuận
            _buildRevenueProfitChartCard(theme),
            const SizedBox(height: 24),

            // Biểu đồ Trạng thái Đơn hàng
            _buildOrderStatusDistributionCard(theme),
            const SizedBox(height: 24),

            // Top Sản phẩm bán chạy
            _buildTopProductsCard(theme),
            const SizedBox(height: 24),

            // Cảnh báo tồn kho
            _buildLowStockCard(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS CON ---

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _periodOptions.entries.map((entry) {
            final isSelected = _selectedPeriod == entry.key;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: isSelected,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Colors.transparent,
                side: BorderSide.none,
                onSelected: (selected) {
                  if (selected && _selectedPeriod != entry.key) {
                    setState(() {
                      _selectedPeriod = entry.key;
                    });
                    _loadDashboardData();
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(DashboardSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 650;
        final crossAxisCount = isDesktop ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.4 : 1.35,
          children: [
            _buildKpiCard(
              title: 'Doanh thu',
              value: _formatCompactCurrency(summary.totalRevenue),
              subtitle: 'Đã giao: ${summary.deliveredOrders} đơn',
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
            ),
            _buildKpiCard(
              title: 'Lợi nhuận gộp',
              value: _formatCompactCurrency(summary.totalProfit),
              subtitle: 'Biên LN: ${summary.profitMarginPercentage.toStringAsFixed(1)}%',
              icon: Icons.trending_up,
              iconColor: const Color(0xFF16A34A),
              bgColor: const Color(0xFFF0FDF4),
            ),
            _buildKpiCard(
              title: 'Đơn hàng',
              value: '${summary.totalOrders}',
              subtitle: 'Chờ duyệt: ${summary.pendingOrders} đơn',
              icon: Icons.local_shipping_outlined,
              iconColor: const Color(0xFFEA580C),
              bgColor: const Color(0xFFFFF7ED),
            ),
            _buildKpiCard(
              title: 'Sản phẩm',
              value: '${summary.totalProducts}',
              subtitle: 'Sắp hết: ${summary.lowStockProductsCount} | Hết: ${summary.outOfStockProductsCount}',
              icon: Icons.inventory_2_outlined,
              iconColor: const Color(0xFF9333EA),
              bgColor: const Color(0xFFFAF5FF),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueProfitChartCard(ThemeData theme) {
    final chartPoints = _overview?.chartData ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Biểu Đồ Doanh Thu & Lợi Nhuận',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'So sánh dòng tiền bán hàng và lợi nhuận gộp',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildLegendIndicator(const Color(0xFF2563EB), 'Doanh thu'),
                  const SizedBox(width: 12),
                  _buildLegendIndicator(const Color(0xFF16A34A), 'Lợi nhuận'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 240,
            child: chartPoints.isEmpty
                ? const Center(child: Text('Không có dữ liệu biểu đồ trong khoảng thời gian này'))
                : _buildLineChart(chartPoints),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<ChartDataPoint> points) {
    double maxVal = 0;
    for (var p in points) {
      if (p.revenue > maxVal) maxVal = p.revenue;
      if (p.profit > maxVal) maxVal = p.profit;
    }
    if (maxVal == 0) maxVal = 10000000;
    maxVal = maxVal * 1.15; // Padding đỉnh đồ thị

    final spotsRevenue = <FlSpot>[];
    final spotsProfit = <FlSpot>[];

    for (int i = 0; i < points.length; i++) {
      spotsRevenue.add(FlSpot(i.toDouble(), points[i].revenue));
      spotsProfit.add(FlSpot(i.toDouble(), points[i].profit));
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble().clamp(1.0, double.infinity),
        minY: 0,
        maxY: maxVal,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade100,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: maxVal / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  _formatShortNumber(value),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (points.length / 5).ceilToDouble().clamp(1.0, double.infinity),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < points.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      points[idx].label,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isRev = spot.barIndex == 0;
                final name = isRev ? 'Doanh thu' : 'Lợi nhuận';
                final valStr = _currencyFormat.format(spot.y);
                return LineTooltipItem(
                  '$name\n$valStr',
                  TextStyle(
                    color: isRev ? Colors.blue.shade200 : Colors.green.shade200,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          // Đường Doanh Thu
          LineChartBarData(
            spots: spotsRevenue,
            isCurved: true,
            curveSmoothness: 0.35,
            color: const Color(0xFF2563EB),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            ),
          ),
          // Đường Lợi Nhuận
          LineChartBarData(
            spots: spotsProfit,
            isCurved: true,
            curveSmoothness: 0.35,
            color: const Color(0xFF16A34A),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF16A34A).withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusDistributionCard(ThemeData theme) {
    final statusList = _overview?.orderStatusDistribution ?? [];
    final totalOrders = _overview?.summary.totalOrders ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phân Bố Trạng Thái Đơn Hàng',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            'Tổng cộng $totalOrders đơn hàng phát sinh',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          if (totalOrders == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Text('Chưa có đơn hàng nào'),
              ),
            )
          else
            Row(
              children: [
                // Donut Chart
                SizedBox(
                  width: 140,
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 38,
                      sections: statusList.map((st) {
                        return PieChartSectionData(
                          color: _getOrderStatusColor(st.status),
                          value: st.count.toDouble(),
                          title: '${st.percentage.toStringAsFixed(0)}%',
                          radius: 32,
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          showTitle: st.count > 0,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Legend
                Expanded(
                  child: Column(
                    children: statusList.map((st) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _getOrderStatusColor(st.status),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                st.statusNameVi,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                            ),
                            Text(
                              '${st.count} (${st.percentage.toStringAsFixed(0)}%)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(ThemeData theme) {
    final topProducts = _overview?.topSellingProducts ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Sản Phẩm Bán Chạy',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Xếp hạng theo tổng doanh thu mang về',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Icon(Icons.workspace_premium, color: Colors.amber.shade700),
            ],
          ),
          const SizedBox(height: 16),
          if (topProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: Text('Chưa có dữ liệu bán hàng')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topProducts.length,
              separatorBuilder: (_, _) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final item = topProducts[index];
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: index == 0
                          ? Colors.amber.shade100
                          : (index == 1 ? Colors.grey.shade200 : Colors.brown.shade100),
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: index == 0 ? Colors.amber.shade900 : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Đã bán: ${item.unitsSold} chiếc | Lợi nhuận: ${_currencyFormat.format(item.totalProfit)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _currencyFormat.format(item.totalRevenue),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLowStockCard(ThemeData theme) {
    final lowStockItems = _overview?.lowStockAlerts ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cảnh Báo Tồn Kho Thấp',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Các biến thể còn <= 5 sản phẩm trong kho',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            ],
          ),
          const SizedBox(height: 16),
          if (lowStockItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  'Kho hàng an toàn, không có biến thể nào sắp hết!',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lowStockItems.length,
              separatorBuilder: (_, _) => const Divider(height: 14),
              itemBuilder: (context, index) {
                final item = lowStockItems[index];
                final isOutOfStock = item.stockQuantity == 0;

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOutOfStock ? Colors.red.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isOutOfStock ? Colors.red.shade200 : Colors.orange.shade200,
                        ),
                      ),
                      child: Text(
                        isOutOfStock ? 'HẾT HÀNG' : 'Còn ${item.stockQuantity}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOutOfStock ? Colors.red.shade700 : Colors.orange.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'SKU: ${item.sku}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _currencyFormat.format(item.price),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLegendIndicator(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B); // Amber
      case 'processing':
        return const Color(0xFF3B82F6); // Blue
      case 'shipped':
        return const Color(0xFF06B6D4); // Cyan
      case 'delivered':
        return const Color(0xFF10B981); // Emerald
      case 'cancelled':
        return const Color(0xFFEF4444); // Red
      default:
        return Colors.grey;
    }
  }

  String _formatCompactCurrency(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(2)} Tỷ ₫';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)} Tr ₫';
    } else {
      return _currencyFormat.format(amount);
    }
  }

  String _formatShortNumber(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(0)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toInt().toString();
  }
}
