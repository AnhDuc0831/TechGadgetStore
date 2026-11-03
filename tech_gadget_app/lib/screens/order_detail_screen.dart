import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../utils/formatters.dart';
import 'order_tracking_map_screen.dart';
import 'payos_payment_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
  OrderModel? _order;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isCancelling = false;
  bool _isConfirmingReceived = false;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final auth = context.read<AuthProvider>();
    final token = auth.accessToken;
    if (token == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orderProvider = context.read<OrderProvider>();
      final data = await orderProvider.getOrderDetails(token, widget.orderId);
      if (mounted) {
        setState(() {
          _order = data;
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

  Future<void> _confirmCancel() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận hủy đơn hàng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn có chắc chắn muốn hủy đơn hàng này? Số lượng sản phẩm sẽ được hoàn lại vào kho.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Lý do hủy (tuỳ chọn)',
                hintText: 'VD: Thay đổi địa chỉ, không còn nhu cầu...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy đơn hàng'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final token = auth.accessToken;
    if (token == null) return;

    setState(() => _isCancelling = true);

    try {
      final orderProvider = context.read<OrderProvider>();
      final ok = await orderProvider.cancelOrder(
        token,
        widget.orderId,
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );

      if (mounted) {
        setState(() => _isCancelling = false);
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hủy đơn hàng thành công và đã hoàn lại tồn kho.'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchDetail();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _confirmReceivedOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 26),
            SizedBox(width: 8),
            Expanded(child: Text('Xác nhận đã nhận hàng', style: TextStyle(fontSize: 18))),
          ],
        ),
        content: const Text(
          'Bạn đã nhận được kiện hàng và kiểm tra đầy đủ sản phẩm chưa?\n\n'
          'Sau khi xác nhận, đơn hàng sẽ được chuyển sang trạng thái Hoàn thành.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Để sau', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Đã nhận hàng'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final token = auth.accessToken;
    if (token == null) return;

    setState(() => _isConfirmingReceived = true);

    try {
      final orderProvider = context.read<OrderProvider>();
      final updated = await orderProvider.confirmReceived(token, widget.orderId);
      if (mounted) {
        setState(() {
          _order = updated;
          _isConfirmingReceived = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xác nhận đã nhận hàng thành công! Cảm ơn bạn đã mua sắm.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConfirmingReceived = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  void _reopenPayment() {
    if (_order != null && _order!.checkoutUrl != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PayOSPaymentScreen(
            orderId: _order!.id,
            checkoutUrl: _order!.checkoutUrl!,
          ),
        ),
      ).then((_) => _fetchDetail());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _isLoading ? null : _fetchDetail,
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Lỗi khi tải đơn hàng',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _fetchDetail,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final order = _order;
    if (order == null) {
      return const Center(child: Text('Không tìm thấy thông tin đơn hàng'));
    }

    return RefreshIndicator(
      onRefresh: _fetchDetail,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusHeaderCard(order, theme),
            const SizedBox(height: 16),

            // Banner đã hoàn thành hoặc các nút thao tác
            if (order.statusEnum == OrderStatusEnum.completed) ...[
              _buildCompletedBanner(theme),
              const SizedBox(height: 16),
            ] else if (order.canConfirmReceived || order.canReopenPayment || order.canCancel) ...[
              _buildActionRow(order, theme),
              const SizedBox(height: 16),
            ],

            // Thông tin người nhận & giao hàng
            _buildSectionHeader('Thông tin nhận hàng', theme),
            const SizedBox(height: 8),
            _buildShippingCard(order, theme),
            const SizedBox(height: 16),

            // Danh sách sản phẩm
            _buildSectionHeader('Sản phẩm (${order.items.length})', theme),
            const SizedBox(height: 8),
            _buildItemsCard(order, theme),
            const SizedBox(height: 16),

            // Chi tiết thanh toán & chi phí
            _buildSectionHeader('Chi tiết thanh toán', theme),
            const SizedBox(height: 8),
            _buildPaymentDetailCard(order, theme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildStatusHeaderCard(OrderModel order, ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Đơn hàng #${order.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _dateFormat.format(order.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Text('Trạng thái đơn: ', style: TextStyle(color: Colors.black54)),
                _buildChip(order.statusLabel, order.statusColor),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Thanh toán: ', style: TextStyle(color: Colors.black54)),
                _buildChip(order.paymentStatusLabel, order.paymentStatusColor, isOutlined: true),
              ],
            ),
            if (order.paidAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Thời gian thanh toán: ${_dateFormat.format(order.paidAt!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified, color: Color(0xFF16A34A), size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đơn hàng đã hoàn thành',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF15803D),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Đã nhận được hàng thành công.',
                  style: TextStyle(
                    color: Color(0xFF166534),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(OrderModel order, ThemeData theme) {
    return Column(
      children: [
        if (order.canConfirmReceived) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isConfirmingReceived ? null : _confirmReceivedOrder,
              icon: _isConfirmingReceived
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: const Text(
                'Đã nhận được hàng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
              ),
            ),
          ),
          if (order.canReopenPayment || order.canCancel) const SizedBox(height: 10),
        ],
        if (order.canReopenPayment || order.canCancel)
          Row(
            children: [
              if (order.canReopenPayment)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _reopenPayment,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Thanh toán lại'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              if (order.canReopenPayment && order.canCancel) const SizedBox(width: 12),
              if (order.canCancel)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isCancelling ? null : _confirmCancel,
                    icon: _isCancelling
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cancel_outlined, color: Colors.red),
                    label: const Text('Hủy đơn hàng', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildShippingCard(OrderModel order, ThemeData theme) {
    final hasName = order.shippingName != null && order.shippingName!.trim().isNotEmpty;
    final hasPhone = order.shippingPhone != null && order.shippingPhone!.trim().isNotEmpty;
    final displayAddress = order.formattedShippingAddress;
    final hasAddress = displayAddress.isNotEmpty && displayAddress != 'Chưa cập nhật địa chỉ';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDetailRow(
              icon: Icons.person_outline,
              iconColor: const Color(0xFF2563EB),
              label: 'Người nhận',
              value: hasName ? order.shippingName! : 'Chưa cập nhật tên',
              isBold: true,
            ),
            const Divider(height: 18),
            _buildDetailRow(
              icon: Icons.phone_outlined,
              iconColor: const Color(0xFF16A34A),
              label: 'Số điện thoại',
              value: hasPhone ? order.shippingPhone! : 'Chưa cập nhật SĐT',
              isBold: true,
            ),
            const Divider(height: 18),
            _buildDetailRow(
              icon: Icons.location_on_outlined,
              iconColor: const Color(0xFFDC2626),
              label: 'Địa chỉ nhận',
              value: hasAddress ? displayAddress : 'Chưa cập nhật địa chỉ',
            ),
            if (order.note != null && order.note!.trim().isNotEmpty) ...[
              const Divider(height: 18),
              _buildDetailRow(
                icon: Icons.chat_bubble_outline,
                iconColor: Colors.amber.shade800,
                label: 'Ghi chú',
                value: order.note!,
              ),
            ],
            if (hasAddress) ...[
              const Divider(height: 18),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderTrackingMapScreen(order: order),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_outlined, size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      const Text(
                        'Xem lộ trình giao hàng trên bản đồ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 16, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(OrderModel order, ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: order.items.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final item = order.items[index];
          return Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text('SKU: ${item.sku}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text(
                        '${formatVnd(item.unitPrice)} x ${item.quantity}',
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatVnd(item.totalPrice),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentDetailCard(OrderModel order, ThemeData theme) {
    final subtotal = order.items.fold(0.0, (sum, i) => sum + i.totalPrice);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSummaryLine('Tạm tính sản phẩm', formatVnd(subtotal)),
            const SizedBox(height: 8),
            _buildSummaryLine(
              'Phí vận chuyển',
              order.shippingFee == 0 ? 'Miễn phí' : formatVnd(order.shippingFee),
              valueColor: order.shippingFee == 0 ? Colors.green : null,
            ),
            const SizedBox(height: 8),
            _buildSummaryLine('Hình thức thanh toán', order.paymentMethodLabel),
            const Divider(height: 20),
            _buildSummaryLine(
              'Tổng cộng thanh toán',
              formatVnd(order.totalAmount),
              isBold: true,
              valueColor: Colors.red.shade700,
              fontSize: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    Color? iconColor,
    required String label,
    required String value,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor ?? Colors.grey.shade600),
        const SizedBox(width: 10),
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryLine(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    double fontSize = 13,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: isBold ? Colors.black87 : Colors.black54,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, Color color, {bool isOutlined = false}) {
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
