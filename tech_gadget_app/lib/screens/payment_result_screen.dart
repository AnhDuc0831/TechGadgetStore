import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../utils/formatters.dart';
import 'home_screen.dart';
import 'order_detail_screen.dart';
import 'payos_payment_screen.dart';

class PaymentResultScreen extends StatefulWidget {
  final String orderId;
  final int? orderCode;

  const PaymentResultScreen({
    super.key,
    required this.orderId,
    this.orderCode,
  });

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  Timer? _pollingTimer;
  int _pollCount = 0;
  static const int _maxPolls = 15; // 15 x 2s = 30s
  static const Duration _pollInterval = Duration(seconds: 2);

  PaymentStatusResult? _statusResult;
  bool _isPolling = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollCount = 0;
    setState(() {
      _isPolling = true;
      _errorMessage = null;
    });

    // Check ngay lập tức lần đầu
    _checkStatus();

    // Thiết lập timer định kỳ mỗi 2 giây
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollInterval, (timer) {
      _pollCount++;
      if (_pollCount >= _maxPolls) {
        timer.cancel();
        if (mounted) setState(() => _isPolling = false);
      } else {
        _checkStatus();
      }
    });
  }

  Future<void> _checkStatus() async {
    final auth = context.read<AuthProvider>();
    final token = auth.accessToken;
    if (token == null) {
      _pollingTimer?.cancel();
      if (mounted) {
        setState(() {
          _isPolling = false;
          _errorMessage = 'Phiên đăng nhập đã hết hạn.';
        });
      }
      return;
    }

    try {
      final orderProvider = context.read<OrderProvider>();
      final result = await orderProvider.pollPaymentStatus(token, widget.orderId);

      if (!mounted) return;

      setState(() {
        _statusResult = result;
      });

      // Nếu đã thanh toán thành công hoặc đã hủy/thất bại thì dừng poll
      if (result.isPaid || result.isCancelledOrFailed) {
        _pollingTimer?.cancel();
        setState(() => _isPolling = false);
      }
    } catch (e) {
      if (!mounted) return;
      // Trong quá trình polling, lỗi tạm thời không hủy timer trừ khi đã quá số lần
      if (_pollCount >= _maxPolls) {
        setState(() {
          _isPolling = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _goToOrderDetail() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: widget.orderId),
      ),
    );
  }

  void _reopenPayment() {
    if (_statusResult?.checkoutUrl != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PayOSPaymentScreen(
            orderId: widget.orderId,
            orderCode: _statusResult?.orderCode ?? widget.orderCode,
            checkoutUrl: _statusResult!.checkoutUrl!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goToHome();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kết quả thanh toán'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Về trang chủ',
              onPressed: _goToHome,
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: _buildContent(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final result = _statusResult;

    // Trạng thái đang kiểm tra lần đầu
    if (result == null && _isPolling) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            'Đang kiểm tra giao dịch PayOS...',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Hệ thống đang đồng bộ với cổng thanh toán. Vui lòng chờ trong giây lát...',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      );
    }

    // Trường hợp 1: THANH TOÁN THÀNH CÔNG (PAID)
    if (result != null && result.isPaid) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, size: 72, color: Colors.green.shade600),
          ),
          const SizedBox(height: 20),
          Text(
            'Thanh toán thành công!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đơn hàng của bạn đã được thanh toán và xác nhận tự động.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          _buildSummaryCard(result, theme),
          const SizedBox(height: 32),
          _buildActionButtons(theme),
        ],
      );
    }

    // Trường hợp 2: ĐÃ HỦY / THẤT BẠI / HẾT HẠN (CANCELLED / FAILED / EXPIRED)
    if (result != null && result.isCancelledOrFailed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cancel_outlined, size: 72, color: Colors.red.shade600),
          ),
          const SizedBox(height: 20),
          Text(
            'Thanh toán chưa hoàn tất',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Giao dịch ${result.paymentStatusEnum.labelVi.toLowerCase()}. Số lượng sản phẩm đã được hoàn trả.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          _buildSummaryCard(result, theme),
          const SizedBox(height: 32),
          _buildActionButtons(theme),
        ],
      );
    }

    // Trường hợp 3: ĐANG CHỜ XỬ LÝ (PENDING)
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: _isPolling
              ? const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.orange),
                )
              : Icon(Icons.hourglass_top_rounded, size: 72, color: Colors.orange.shade600),
        ),
        const SizedBox(height: 20),
        Text(
          _isPolling ? 'Đang chờ xác nhận từ PayOS...' : 'Đơn hàng đang chờ thanh toán',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ??
              (_isPolling
                  ? 'Hệ thống đang tự động kiểm tra mỗi 2 giây...'
                  : 'Nếu bạn đã quét mã chuyển khoản, ngân hàng có thể mất 1-2 phút để xử lý. Bạn có thể bấm "Kiểm tra lại" hoặc thanh toán lại.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _errorMessage != null ? Colors.red.shade700 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 24),
        if (result != null) _buildSummaryCard(result, theme),
        const SizedBox(height: 32),
        _buildActionButtons(theme),
      ],
    );
  }

  Widget _buildSummaryCard(PaymentStatusResult result, ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (result.orderCode != null) ...[
              _buildRow('Mã đơn hàng:', '#${result.orderCode}'),
              const Divider(height: 16),
            ],
            _buildRow('Tổng số tiền:', formatVnd(result.totalAmount), isBold: true, valueColor: Colors.red.shade700),
            const Divider(height: 16),
            _buildRow('Trạng thái đơn hàng:', result.orderStatusEnum.labelVi),
            const Divider(height: 16),
            _buildRow('Trạng thái thanh toán:', result.paymentStatusEnum.labelVi, valueColor: result.paymentStatusEnum.color),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    final result = _statusResult;
    final isPending = result?.isPending ?? true;
    final canReopen = isPending && result?.checkoutUrl != null;

    return Column(
      children: [
        // Nút Thanh toán lại (chỉ hiển thị khi đang Pending và có checkoutUrl)
        if (canReopen) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _reopenPayment,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Thanh toán lại (Mở trang PayOS)'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Nút Kiểm tra lại thủ công (nếu đang Pending và không tự động poll nữa)
        if (isPending && !_isPolling) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _startPolling,
              icon: const Icon(Icons.refresh),
              label: const Text('Kiểm tra lại trạng thái'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Nút Xem chi tiết đơn hàng
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _goToOrderDetail,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Xem chi tiết đơn hàng'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Nút Về trang chủ
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _goToHome,
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Về trang chủ mua sắm'),
          ),
        ),
      ],
    );
  }
}
