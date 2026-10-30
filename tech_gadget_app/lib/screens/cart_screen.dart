import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../utils/formatters.dart';
import '../widgets/product_image.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  /// Tập hợp các id item đang được chọn để thanh toán
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    // Tải giỏ hàng ngay khi màn hình được mở
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCart());
  }

  Future<void> _fetchCart() async {
    final auth = context.read<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    final token = auth.accessToken;
    if (token == null) return;
    await cartProvider.fetchCart(token);

    // Sau khi tải xong, mặc định chọn tất cả item khả dụng
    if (!mounted) return;
    final items = cartProvider.cart.items.where((i) => i.isAvailable);
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(items.map((i) => i.id));
    });
  }

  Future<void> _removeItem(CartItemModel item) async {
    final auth = context.read<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    final token = auth.accessToken;
    if (token == null) return;

    setState(() => _selectedIds.remove(item.id));

    final ok = await cartProvider.removeItem(token, itemId: item.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cartProvider.errorMessage ?? 'Không thể xóa sản phẩm.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _updateQuantity(CartItemModel item, int newQty) async {
    final auth = context.read<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    final token = auth.accessToken;
    if (token == null) return;

    final ok = await cartProvider.updateItem(
      token,
      itemId: item.id,
      quantity: newQty,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cartProvider.errorMessage ?? 'Không thể cập nhật số lượng.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _clearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa toàn bộ giỏ hàng'),
        content: const Text('Bạn có chắc muốn xóa tất cả sản phẩm khỏi giỏ hàng không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    final token = auth.accessToken;
    if (token == null) return;

    final ok = await cartProvider.clearCart(token);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cartProvider.errorMessage ?? 'Không thể xóa giỏ hàng.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } else {
      setState(() => _selectedIds.clear());
    }
  }

  // ── Checkbox helpers ───────────────────────────────────────────────────────

  void _toggleItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<CartItemModel> availableItems) {
    final allIds = availableItems.map((i) => i.id).toSet();
    setState(() {
      if (_selectedIds.containsAll(allIds) && allIds.isNotEmpty) {
        // Bỏ chọn tất cả
        _selectedIds.removeAll(allIds);
      } else {
        // Chọn tất cả
        _selectedIds.addAll(allIds);
      }
    });
  }

  // ── Tổng tiền chỉ tính các item được chọn ─────────────────────────────────

  double _selectedTotal(List<CartItemModel> items) {
    return items
        .where((i) => i.isAvailable && _selectedIds.contains(i.id))
        .fold(0, (sum, i) => sum + i.lineTotal);
  }

  int _selectedCount() => _selectedIds.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Consumer<CartProvider>(
          builder: (_, cart, _) {
            final count = cart.cart.totalQuantity;
            return Text(count > 0 ? 'Giỏ hàng ($count)' : 'Giỏ hàng');
          },
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (_, cart, _) {
              if (cart.isEmpty) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: cart.isLoading ? null : _clearCart,
                icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                label: const Text('Xóa tất cả'),
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
              );
            },
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, _) {
          if (cartProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (cartProvider.errorMessage != null && cartProvider.isEmpty) {
            return _buildError(cartProvider.errorMessage!, theme);
          }

          if (cartProvider.isEmpty) {
            return _buildEmpty(theme);
          }

          return _buildCartList(cartProvider.cart, theme);
        },
      ),
    );
  }

  // ── Empty / Error ─────────────────────────────────────────────────────────

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Giỏ hàng trống',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy thêm sản phẩm yêu thích vào giỏ hàng.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Tiếp tục mua sắm'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Không thể tải giỏ hàng', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _fetchCart,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cart List ─────────────────────────────────────────────────────────────

  Widget _buildCartList(CartModel cart, ThemeData theme) {
    final availableItems = cart.items.where((i) => i.isAvailable).toList();
    final unavailableItems = cart.items.where((i) => !i.isAvailable).toList();

    final allAvailableSelected =
        availableItems.isNotEmpty && _selectedIds.containsAll(availableItems.map((i) => i.id));
    final someAvailableSelected =
        !allAvailableSelected && availableItems.any((i) => _selectedIds.contains(i.id));

    return RefreshIndicator(
      onRefresh: _fetchCart,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (availableItems.isNotEmpty) ...[
                  // Header "Sản phẩm" kèm checkbox chọn tất cả
                  _buildSectionHeaderWithCheckbox(
                    'Sản phẩm',
                    availableItems.length,
                    theme,
                    tristate: someAvailableSelected,
                    checked: allAvailableSelected,
                    onChanged: (_) => _toggleSelectAll(availableItems),
                  ),
                  ...availableItems.map((item) => _buildCartItem(item, theme)),
                ],
                if (unavailableItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildSectionHeader(
                    'Không thể mua',
                    unavailableItems.length,
                    theme,
                    color: Colors.red.shade700,
                  ),
                  ...unavailableItems.map((item) => _buildCartItem(item, theme, unavailable: true)),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          _buildSummaryBar(cart, theme),
        ],
      ),
    );
  }

  /// Header có checkbox "Chọn tất cả"
  Widget _buildSectionHeaderWithCheckbox(
    String title,
    int count,
    ThemeData theme, {
    required bool tristate,
    required bool checked,
    required ValueChanged<bool?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
      child: Row(
        children: [
          Checkbox(
            tristate: true,
            value: tristate ? null : checked,
            onChanged: onChanged,
            visualDensity: VisualDensity.compact,
            activeColor: theme.colorScheme.primary,
          ),
          Text(
            '$title ($count)',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            'Chọn tất cả',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    ThemeData theme, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        '$title ($count)',
        style: theme.textTheme.labelLarge?.copyWith(
          color: color ?? Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCartItem(CartItemModel item, ThemeData theme, {bool unavailable = false}) {
    final maxQty = item.stockQuantity.clamp(1, 99);
    final isSelected = _selectedIds.contains(item.id);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade100,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: Colors.red.shade700),
      ),
      confirmDismiss: (_) async {
        await _removeItem(item);
        return false; // provider đã cập nhật list, không cần dismiss thủ công
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: unavailable
                ? Colors.red.shade200
                : (isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.4)
                    : Colors.grey.shade200),
          ),
        ),
        child: Opacity(
          opacity: unavailable ? 0.6 : 1.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Checkbox chọn sản phẩm ──
                if (!unavailable)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleItem(item.id),
                    visualDensity: VisualDensity.compact,
                    activeColor: theme.colorScheme.primary,
                  )
                else
                  const SizedBox(width: 12),

                // ── Ảnh sản phẩm ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: ProductImage(url: item.thumbnailUrl, iconSize: 32),
                  ),
                ),
                const SizedBox(width: 12),

                // ── Thông tin sản phẩm ──
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
                      // Thuộc tính (màu, ram, ...)
                      if (item.attributeMap.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          children: item.attributeMap.entries.map((e) {
                            return Text(
                              '${e.key}: ${e.value}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            );
                          }).toList(),
                        ),
                      // Trạng thái không khả dụng
                      if (unavailable)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            item.status.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Giá
                          Expanded(
                            child: Text(
                              formatVnd(item.unitPrice),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Điều chỉnh số lượng
                          if (!unavailable)
                            _buildQuantityControl(item, maxQty, theme)
                          else
                            // Nút xóa nhanh cho item không khả dụng
                            TextButton.icon(
                              onPressed: () => _removeItem(item),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Xóa'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade600,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityControl(CartItemModel item, int maxQty, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QtyButton(
          icon: Icons.remove,
          onTap: item.quantity <= 1
              ? () => _removeItem(item)
              : () => _updateQuantity(item, item.quantity - 1),
          color: item.quantity <= 1 ? Colors.red.shade400 : null,
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 32),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${item.quantity}',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        _QtyButton(
          icon: Icons.add,
          onTap: item.quantity >= maxQty ? null : () => _updateQuantity(item, item.quantity + 1),
        ),
      ],
    );
  }

  // ── Summary Bar ───────────────────────────────────────────────────────────

  Widget _buildSummaryBar(CartModel cart, ThemeData theme) {
    final selectedTotal = _selectedTotal(cart.items);
    final selectedCount = _selectedCount();

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedCount > 0
                        ? 'Tổng ($selectedCount sản phẩm)'
                        : 'Chưa chọn sản phẩm',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatVnd(selectedTotal),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: selectedCount > 0
                  ? () async {
                      final selectedItems = cart.items
                          .where((i) => i.isAvailable && _selectedIds.contains(i.id))
                          .toList();
                      if (selectedItems.isEmpty) return;

                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CheckoutScreen(selectedItems: selectedItems),
                        ),
                      );
                      // Tải lại giỏ hàng khi quay lại
                      _fetchCart();
                    }
                  : null,
              icon: const Icon(Icons.payment_outlined),
              label: const Text('Đặt hàng'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small reusable quantity button ───────────────────────────────────────────

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _QtyButton({required this.icon, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? Colors.grey.shade400 : (color ?? Colors.black87),
        ),
      ),
    );
  }
}
