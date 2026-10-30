import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../utils/formatters.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final String orderId;

  const AdminOrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
  AdminOrderModel? _order;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUpdatingStatus = false;
  bool _hasChanged = false;

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
      final data = await orderProvider.getAdminOrderDetails(token, widget.orderId);
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

  void _showChangeStatusSheet() {
    final order = _order;
    if (order == null) return;

    final allowedStatuses = order.statusEnum.allowedNextStatuses;
    if (allowedStatuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đơn hàng ở trạng thái "${order.statusLabel}" là trạng thái cuối cùng, không thể chuyển tiếp.'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chuyển trạng thái đơn hàng',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                Text(
                  'Trạng thái hiện tại: ${order.statusLabel}',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const Divider(height: 24),
                ...allowedStatuses.map((target) {
                  return ListTile(
                    leading: Icon(
                      target == OrderStatusEnum.cancelled ? Icons.cancel_outlined : Icons.check_circle_outline,
                      color: target.color,
                    ),
                    title: Text(
                      target.labelVi,
                      style: TextStyle(fontWeight: FontWeight.bold, color: target.color),
                    ),
                    subtitle: Text(
                      target == OrderStatusEnum.cancelled
                          ? 'Hủy đơn hàng và hoàn lại số lượng tồn kho'
                          : 'Cập nhật tiến trình đơn hàng',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmUpdateStatus(target);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmUpdateStatus(OrderStatusEnum targetStatus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận cập nhật trạng thái'),
        content: Text(
          'Bạn có chắc muốn chuyển trạng thái đơn hàng sang "${targetStatus.labelVi}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: targetStatus == OrderStatusEnum.cancelled ? Colors.red.shade600 : null,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final token = auth.accessToken;
    if (token == null) return;

    setState(() => _isUpdatingStatus = true);

    try {
      final orderProvider = context.read<OrderProvider>();
      final updated = await orderProvider.updateOrderStatus(
        token,
        widget.orderId,
        targetStatus.backendString,
      );

      if (mounted) {
        setState(() {
          _order = updated;
          _isUpdatingStatus = false;
          _hasChanged = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật trạng thái đơn hàng sang "${targetStatus.labelVi}".'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết đơn hàng (Admin)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_hasChanged),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Tải lại',
              onPressed: _isLoading ? null : _fetchDetail,
            ),
          ],
        ),
        body: _buildBody(theme),
      ),
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
            // 1. Banner "Cần kiểm tra" (Chỉ hiển thị khi needsReview == true)
            if (order.needsReview) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade400, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ĐƠN HÀNG CẦN KIỂM TRA (NEEDS REVIEW)',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Đơn hàng có thanh toán cần hoàn tiền thủ công hoặc giao dịch sau khi hủy. Vui lòng đối soát.',
                            style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 2. Ghi chú nội bộ (internalNote - Chỉ Admin xem)
            if (order.internalNote != null && order.internalNote!.isNotEmpty) ...[
              Card(
                elevation: 0,
                color: const Color(0xFFFFFBEB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber.shade400),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, color: Colors.amber.shade900, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ghi chú nội bộ (Chỉ Admin xem):',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.internalNote!,
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3. Header trạng thái & nút Cập nhật trạng thái
            _buildStatusHeaderCard(order, theme),
            const SizedBox(height: 16),

            // Nút cập nhật trạng thái đơn hàng
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isUpdatingStatus || order.statusEnum.allowedNextStatuses.isEmpty
                    ? null
                    : _showChangeStatusSheet,
                icon: _isUpdatingStatus
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.edit_note_outlined),
                label: Text(
                  order.statusEnum.allowedNextStatuses.isEmpty
                      ? 'Trạng thái cuối cùng (${order.statusLabel})'
                      : 'Cập nhật trạng thái đơn hàng',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 4. Thông tin định danh hệ thống (Admin metadata)
            _buildSectionHeader('Định danh hệ thống', theme),
            const SizedBox(height: 8),
            _buildAdminMetaCard(order, theme),
            const SizedBox(height: 16),

            // 5. Thông tin người nhận
            _buildSectionHeader('Thông tin nhận hàng', theme),
            const SizedBox(height: 8),
            _buildShippingCard(order, theme),
            const SizedBox(height: 16),

            // 6. Danh sách sản phẩm
            _buildSectionHeader('Sản phẩm (${order.items.length})', theme),
            const SizedBox(height: 8),
            _buildItemsCard(order, theme),
            const SizedBox(height: 16),

            // 7. Chi tiết tài chính
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

  Widget _buildStatusHeaderCard(AdminOrderModel order, ThemeData theme) {
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
                    order.payosOrderCode != null
                        ? 'Đơn hàng #${order.payosOrderCode}'
                        : 'Đơn hàng #${order.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    'Đã thanh toán lúc: ${_dateFormat.format(order.paidAt!)}',
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

  Widget _buildAdminMetaCard(AdminOrderModel order, ThemeData theme) {
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
              icon: Icons.tag,
              label: 'Mã OrderId (UUID)',
              value: order.id,
            ),
            if (order.payosOrderCode != null) ...[
              const Divider(height: 16),
              _buildDetailRow(
                icon: Icons.qr_code,
                label: 'PayOS OrderCode',
                value: order.payosOrderCode.toString(),
              ),
            ],
            if (order.paymentLinkId != null) ...[
              const Divider(height: 16),
              _buildDetailRow(
                icon: Icons.link,
                label: 'Payment Link ID',
                value: order.paymentLinkId!,
              ),
            ],
            if (order.userId != null) ...[
              const Divider(height: 16),
              _buildDetailRow(
                icon: Icons.badge_outlined,
                label: 'Mã khách hàng (UserId)',
                value: order.userId!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShippingCard(AdminOrderModel order, ThemeData theme) {
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
              label: 'Người nhận',
              value: order.shippingName ?? 'Chưa cập nhật',
            ),
            const Divider(height: 16),
            _buildDetailRow(
              icon: Icons.phone_outlined,
              label: 'Số điện thoại',
              value: order.shippingPhone ?? 'Chưa cập nhật',
            ),
            const Divider(height: 16),
            _buildDetailRow(
              icon: Icons.location_on_outlined,
              label: 'Địa chỉ nhận',
              value: order.shippingAddress.isEmpty ? 'Chưa cập nhật' : order.shippingAddress,
            ),
            if (order.note != null && order.note!.isNotEmpty) ...[
              const Divider(height: 16),
              _buildDetailRow(
                icon: Icons.note_outlined,
                label: 'Khách ghi chú',
                value: order.note!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(AdminOrderModel order, ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: order.items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Không có thông tin chi tiết sản phẩm.'),
            )
          : ListView.separated(
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

  Widget _buildPaymentDetailCard(AdminOrderModel order, ThemeData theme) {
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
            if (order.items.isNotEmpty) ...[
              _buildSummaryLine('Tạm tính sản phẩm', formatVnd(subtotal)),
              const SizedBox(height: 8),
            ],
            _buildSummaryLine(
              'Phí vận chuyển',
              order.shippingFee == 0 ? 'Miễn phí' : formatVnd(order.shippingFee),
              valueColor: order.shippingFee == 0 ? Colors.green : null,
            ),
            const SizedBox(height: 8),
            _buildSummaryLine('Hình thức thanh toán', order.paymentMethodLabel),
            const Divider(height: 20),
            _buildSummaryLine(
              'Tổng cộng đơn hàng',
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
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
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
