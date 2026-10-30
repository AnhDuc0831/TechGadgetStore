import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../utils/formatters.dart';
import '../widgets/product_image.dart';
import 'cod_success_screen.dart';
import 'payos_payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItemModel> selectedItems;

  const CheckoutScreen({
    super.key,
    required this.selectedItems,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();

  String _paymentMethod = 'PayOS'; // 'PayOS' | 'Cod'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().userProfile;
    if (profile != null) {
      if (profile.fullName != null && profile.fullName!.isNotEmpty) {
        _nameController.text = profile.fullName!;
      }
      if (profile.phone != null && profile.phone!.isNotEmpty) {
        _phoneController.text = profile.phone!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _subtotal => widget.selectedItems.fold(
        0.0,
        (sum, item) => sum + item.lineTotal,
      );

  // Ước tính phí ship: 30,000đ; miễn phí nếu đơn hàng từ 500,000đ
  double get _estimatedShippingFee => _subtotal >= 500000 ? 0.0 : 30000.0;
  double get _estimatedTotal => _subtotal + _estimatedShippingFee;

  Future<void> _handleCheckout() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một sản phẩm để thanh toán.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final token = auth.accessToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final request = CheckoutRequest(
      shippingName: _nameController.text.trim(),
      shippingPhone: _phoneController.text.trim(),
      shippingAddress: _addressController.text.trim(),
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      paymentMethod: _paymentMethod,
      selectedCartItemIds: widget.selectedItems.map((e) => e.id).toList(),
    );

    try {
      final orderProvider = context.read<OrderProvider>();
      final cartProvider = context.read<CartProvider>();

      final result = await orderProvider.checkout(token, request);

      // Refresh giỏ hàng sau khi đặt hàng thành công (server đã tự xóa các item đã mua)
      await cartProvider.fetchCart(token);

      if (!mounted) return;

      if (result.isPayOS && result.checkoutUrl != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PayOSPaymentScreen(
              orderId: result.orderId,
              orderCode: result.orderCode,
              checkoutUrl: result.checkoutUrl!,
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CodSuccessScreen(result: result),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận đặt hàng'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Danh sách sản phẩm được chọn
                      _buildSectionTitle('Sản phẩm đã chọn (${widget.selectedItems.length})', theme),
                      const SizedBox(height: 8),
                      _buildItemsList(theme),
                      const SizedBox(height: 20),

                      // Thông tin giao hàng
                      _buildSectionTitle('Thông tin nhận hàng', theme),
                      const SizedBox(height: 8),
                      _buildShippingForm(theme),
                      const SizedBox(height: 20),

                      // Phương thức thanh toán
                      _buildSectionTitle('Phương thức thanh toán', theme),
                      const SizedBox(height: 8),
                      _buildPaymentMethodSelector(theme),
                      const SizedBox(height: 20),

                      // Tóm tắt chi phí
                      _buildSectionTitle('Chi tiết thanh toán', theme),
                      const SizedBox(height: 8),
                      _buildPriceSummary(theme),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildItemsList(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.selectedItems.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final item = widget.selectedItems[index];
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: ProductImage(url: item.thumbnailUrl, iconSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${item.sku}',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatVnd(item.unitPrice),
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'x${item.quantity}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShippingForm(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Họ và tên người nhận *',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Vui lòng nhập họ tên người nhận';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại nhận hàng *',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
                hintText: 'VD: 0987654321',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Vui lòng nhập số điện thoại';
                }
                final cleaned = v.trim();
                final phoneRegex = RegExp(r'^0[3|5|7|8|9][0-9]{8}$');
                if (!phoneRegex.hasMatch(cleaned)) {
                  return 'Số điện thoại không hợp lệ (10 số, bắt đầu bằng 03, 05, 07, 08, 09)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ giao hàng chi tiết *',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
                hintText: 'Số nhà, đường, phường/xã, quận/huyện, tỉnh/thành phố',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Vui lòng nhập địa chỉ giao hàng';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Ghi chú cho đơn hàng (tuỳ chọn)',
                prefixIcon: Icon(Icons.note_alt_outlined),
                border: OutlineInputBorder(),
                hintText: 'VD: Giao trong giờ hành chính, gọi trước khi giao...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // ignore: deprecated_member_use
          RadioListTile<String>(
            value: 'PayOS',
            // ignore: deprecated_member_use
            groupValue: _paymentMethod,
            // ignore: deprecated_member_use
            onChanged: (val) {
              if (val != null) setState(() => _paymentMethod = val);
            },
            title: const Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: Colors.blue),
                SizedBox(width: 8),
                Text('Chuyển khoản QR (payOS)', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            subtitle: const Text('Thanh toán tức thì qua mã VietQR hoặc ứng dụng ngân hàng'),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          // ignore: deprecated_member_use
          RadioListTile<String>(
            value: 'Cod',
            // ignore: deprecated_member_use
            groupValue: _paymentMethod,
            // ignore: deprecated_member_use
            onChanged: (val) {
              if (val != null) setState(() => _paymentMethod = val);
            },
            title: const Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: Colors.green),
                SizedBox(width: 8),
                Text('Thanh toán khi nhận hàng (COD)', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            subtitle: const Text('Kiểm tra hàng và thanh toán tiền mặt cho nhân viên giao hàng'),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tạm tính sản phẩm:', style: theme.textTheme.bodyMedium),
                Text(formatVnd(_subtotal), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('Phí vận chuyển (ước tính):'),
                    SizedBox(width: 4),
                    Tooltip(
                      message: 'Phí cố định 30.000đ, miễn phí cho đơn từ 500.000đ (Máy chủ tính lại chính xác)',
                      child: Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    ),
                  ],
                ),
                Text(
                  _estimatedShippingFee == 0 ? 'Miễn phí' : formatVnd(_estimatedShippingFee),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _estimatedShippingFee == 0 ? Colors.green : Colors.black87,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng ước tính:',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  formatVnd(_estimatedTotal),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '* Giá và phí vận chuyển thực tế được tính toán và khóa bảo mật bởi máy chủ.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tổng thanh toán:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  formatVnd(_estimatedTotal),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton(
            onPressed: _isSubmitting ? null : _handleCheckout,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Đặt hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
