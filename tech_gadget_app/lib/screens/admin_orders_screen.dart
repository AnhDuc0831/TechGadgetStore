import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../utils/formatters.dart';
import 'admin_order_detail_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  int _currentPage = 1;
  static const int _pageSize = 10;
  String _selectedStatusFilter = 'all';

  final Map<String, String> _statusFilterOptions = {
    'all': 'Tất cả',
    'Pending': 'Chờ xử lý',
    'Confirmed': 'Đã xác nhận',
    'Shipping': 'Đang giao hàng',
    'Completed': 'Hoàn thành',
    'Cancelled': 'Đã hủy',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAdminOrders());
  }

  Future<void> _fetchAdminOrders({int page = 1}) async {
    final auth = context.read<AuthProvider>();
    final token = auth.accessToken;
    if (token == null) return;

    setState(() => _currentPage = page);

    await context.read<OrderProvider>().loadAdminOrders(
      token,
      page: page,
      pageSize: _pageSize,
      status: _selectedStatusFilter == 'all' ? null : _selectedStatusFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    // Kiểm tra quyền Quản trị viên
    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý đơn hàng')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Chỉ tài khoản Quản trị viên (Admin) mới có quyền truy cập màn hình này.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quản lý đơn hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Toàn bộ đơn hàng trên hệ thống', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: () => _fetchAdminOrders(page: _currentPage),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          _buildFilterBar(theme),

          // Danh sách đơn hàng
          Expanded(
            child: Consumer<OrderProvider>(
              builder: (context, orderProvider, _) {
                if (orderProvider.isAdminLoading && orderProvider.adminOrders == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (orderProvider.adminErrorMessage != null && orderProvider.adminOrders == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 56, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(
                            orderProvider.adminErrorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => _fetchAdminOrders(page: _currentPage),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final paged = orderProvider.adminOrders;
                if (paged == null || paged.items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Không có đơn hàng nào',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => _fetchAdminOrders(page: _currentPage),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: paged.items.length,
                    itemBuilder: (context, index) {
                      final order = paged.items[index];
                      return _buildAdminOrderCard(order, theme);
                    },
                  ),
                );
              },
            ),
          ),

          // Pagination Bar
          Consumer<OrderProvider>(
            builder: (context, orderProvider, _) {
              final paged = orderProvider.adminOrders;
              if (paged == null || paged.totalPages <= 1) {
                return const SizedBox.shrink();
              }
              return _buildPaginationBar(paged, theme);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _statusFilterOptions.entries.map((entry) {
            final isSelected = _selectedStatusFilter == entry.key;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: isSelected,
                selectedColor: theme.colorScheme.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: (selected) {
                  if (selected && _selectedStatusFilter != entry.key) {
                    setState(() {
                      _selectedStatusFilter = entry.key;
                    });
                    _fetchAdminOrders(page: 1);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAdminOrderCard(AdminOrderModel order, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: order.needsReview ? Colors.red.shade400 : Colors.grey.shade200,
          width: order.needsReview ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => AdminOrderDetailScreen(orderId: order.id),
            ),
          );
          if (changed == true) {
            _fetchAdminOrders(page: _currentPage);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Mã & Thời gian & Badge "Cần kiểm tra"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_outlined, size: 18, color: Colors.indigo),
                        const SizedBox(width: 6),
                        Text(
                          order.payosOrderCode != null
                              ? '#${order.payosOrderCode}'
                              : '#${order.id.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (order.needsReview) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Cần kiểm tra',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    _dateFormat.format(order.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Người nhận
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    order.shippingName ?? 'Khách hàng',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  if (order.shippingPhone != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${order.shippingPhone})',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Chips trạng thái
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildStatusChip(order.statusLabel, order.statusColor),
                  _buildStatusChip(order.paymentStatusLabel, order.paymentStatusColor, isOutlined: true),
                ],
              ),
              const SizedBox(height: 10),

              // Footer: Hình thức & Tổng tiền
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.paymentMethodLabel,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    formatVnd(order.totalAmount),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationBar(PagedOrders paged, ThemeData theme) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Trang ${paged.page}/${paged.totalPages} (${paged.totalCount} đơn)',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: paged.hasPreviousPage
                    ? () => _fetchAdminOrders(page: paged.page - 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: paged.hasNextPage
                    ? () => _fetchAdminOrders(page: paged.page + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, {bool isOutlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOutlined ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: isOutlined ? Border.all(color: color.withValues(alpha: 0.4)) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

