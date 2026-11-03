import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../services/product_api_service.dart';
import 'admin_add_product_screen.dart';
import 'admin_edit_product_screen.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _productService = ProductApiService();
  final _searchCtrl = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  Timer? _debounceTimer;

  // Trạng thái bộ lọc
  String? _selectedCategoryId;
  String? _selectedBrandId;
  bool? _selectedIsActive; // null = tất cả, true = đang bán, false = đã ẩn
  String _selectedSort = 'newest';

  // Dữ liệu
  List<ProductListItem> _products = [];
  List<Category> _categories = [];
  List<Brand> _brands = [];

  int _page = 1;
  int _totalCount = 0;
  bool _isLoading = false;
  bool _isInitDataLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetadataAndProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMetadataAndProducts() async {
    setState(() {
      _isInitDataLoading = true;
    });

    try {
      final results = await Future.wait([
        _productService.getCategories(),
        _productService.getBrands(),
      ]);

      if (!mounted) return;

      setState(() {
        _categories = results[0] as List<Category>;
        _brands = results[1] as List<Brand>;
        _isInitDataLoading = false;
      });

      await _fetchProducts(page: 1);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitDataLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải danh mục & thương hiệu: $e')),
      );
    }
  }

  Future<void> _fetchProducts({int page = 1}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;

      if (token == null) {
        throw Exception('Vui lòng đăng nhập để tiếp tục.');
      }

      final result = await _productService.getAdminProducts(
        accessToken: token,
        page: page,
        pageSize: 30,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        categoryId: _selectedCategoryId,
        brandId: _selectedBrandId,
        isActive: _selectedIsActive,
        sortBy: _selectedSort,
      );

      if (!mounted) return;

      setState(() {
        _products = result.items;
        _page = result.page;
        _totalCount = result.totalCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải sản phẩm: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _fetchProducts(page: 1);
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _fetchProducts(page: 1);
  }

  void _resetFilters() {
    setState(() {
      _selectedCategoryId = null;
      _selectedBrandId = null;
      _selectedIsActive = null;
      _selectedSort = 'newest';
      _searchCtrl.clear();
    });
    _fetchProducts(page: 1);
  }

  Future<void> _confirmSoftDelete(ProductListItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.visibility_off_outlined, color: Colors.amber.shade800),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Ẩn sản phẩm (Xoá mềm)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc muốn ẩn sản phẩm "${item.name}" khỏi cửa hàng?\n\nKhách hàng sẽ không thể tìm thấy hay mua sản phẩm này nữa. Bạn có thể khôi phục lại bất kỳ lúc nào.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ẩn sản phẩm'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken ?? '';

      await _productService.softDeleteProduct(token, item.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã ẩn sản phẩm "${item.name}" thành công.'),
          backgroundColor: Colors.amber.shade900,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _fetchProducts(page: _page);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi ẩn: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmRestore(ProductListItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restore_from_trash, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Khôi phục sản phẩm',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Khôi phục sản phẩm "${item.name}" hiển thị trở lại trên cửa hàng để khách hàng có thể mua?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken ?? '';

      await _productService.restoreProduct(token, item.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã khôi phục sản phẩm "${item.name}".'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _fetchProducts(page: _page);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi khôi phục: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openAddProduct() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminAddProductScreen()),
    );
    if (created == true) {
      _fetchProducts(page: 1);
    }
  }

  void _openEditProduct(ProductListItem item) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminEditProductScreen(productId: item.id)),
    );
    if (updated == true) {
      _fetchProducts(page: _page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = _selectedCategoryId != null ||
        _selectedBrandId != null ||
        _selectedIsActive != null ||
        _selectedSort != 'newest' ||
        _searchCtrl.text.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản lý sản phẩm',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Thêm, sửa, xoá mềm, tìm kiếm & phân loại',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0.5,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _openAddProduct,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Thêm mới'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProduct,
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text(
          'Đăng sản phẩm mới',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isInitDataLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : Column(
              children: [
                // Khung tìm kiếm
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm theo tên sản phẩm, mã SKU...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                              onPressed: _clearSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Trạng thái (Tất cả / Đang bán / Đã ẩn) Tab Chips
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _buildStatusFilterChip(
                        label: 'Tất cả',
                        isSelected: _selectedIsActive == null,
                        onTap: () {
                          setState(() => _selectedIsActive = null);
                          _fetchProducts(page: 1);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        label: 'Đang bán',
                        isSelected: _selectedIsActive == true,
                        activeColor: const Color(0xFF16A34A),
                        onTap: () {
                          setState(() => _selectedIsActive = true);
                          _fetchProducts(page: 1);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        label: 'Đã ẩn (Xoá mềm)',
                        isSelected: _selectedIsActive == false,
                        activeColor: Colors.amber.shade800,
                        onTap: () {
                          setState(() => _selectedIsActive = false);
                          _fetchProducts(page: 1);
                        },
                      ),
                    ],
                  ),
                ),

                // Thanh chọn Lọc: Danh mục, Thương hiệu, Sắp xếp
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      // Dropdown Danh mục
                      Expanded(
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedCategoryId,
                              isExpanded: true,
                              hint: const Text('Tất cả danh mục', style: TextStyle(fontSize: 12)),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937)),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Tất cả danh mục', style: TextStyle(fontSize: 12)),
                                ),
                                ..._categories.map((c) => DropdownMenuItem<String?>(
                                      value: c.id,
                                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                                    )),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedCategoryId = val);
                                _fetchProducts(page: 1);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Dropdown Thương hiệu
                      Expanded(
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _selectedBrandId,
                              isExpanded: true,
                              hint: const Text('Tất cả hãng', style: TextStyle(fontSize: 12)),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937)),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Tất cả hãng', style: TextStyle(fontSize: 12)),
                                ),
                                ..._brands.map((b) => DropdownMenuItem<String?>(
                                      value: b.id,
                                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                                    )),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedBrandId = val);
                                _fetchProducts(page: 1);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Dropdown Sắp xếp
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSort,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937)),
                            items: const [
                              DropdownMenuItem(value: 'newest', child: Text('Mới nhất')),
                              DropdownMenuItem(value: 'price_asc', child: Text('Giá ↑')),
                              DropdownMenuItem(value: 'price_desc', child: Text('Giá ↓')),
                              DropdownMenuItem(value: 'name', child: Text('Tên A-Z')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedSort = val);
                                _fetchProducts(page: 1);
                              }
                            },
                          ),
                        ),
                      ),

                      if (hasActiveFilter) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Đặt lại bộ lọc',
                          icon: const Icon(Icons.refresh, size: 20, color: Colors.grey),
                          onPressed: _resetFilters,
                        ),
                      ],
                    ],
                  ),
                ),

                // Thống kê kết quả
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    border: Border(
                      top: BorderSide(color: Color(0xFFE5E7EB)),
                      bottom: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hiển thị $_totalCount sản phẩm',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF97316)),
                        ),
                    ],
                  ),
                ),

                // Danh sách sản phẩm
                Expanded(
                  child: _isLoading && _products.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
                      : _products.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Không tìm thấy sản phẩm nào phù hợp',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Hãy thử đổi từ khoá hoặc điều chỉnh lại bộ lọc',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                                  if (hasActiveFilter) ...[
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      onPressed: _resetFilters,
                                      child: const Text('Xoá tất cả bộ lọc'),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => _fetchProducts(page: _page),
                              color: const Color(0xFFF97316),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                                itemCount: _products.length,
                                separatorBuilder: (_, index) => const SizedBox(height: 12),
                                itemBuilder: (ctx, index) {
                                  final item = _products[index];
                                  return _buildProductItemCard(item);
                                },
                              ),
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusFilterChip({
    required String label,
    required bool isSelected,
    Color activeColor = const Color(0xFFF97316),
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildProductItemCard(ProductListItem item) {
    final hasDiscount = item.discountPrice != null && item.discountPrice! < item.basePrice;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isActive ? const Color(0xFFE5E7EB) : const Color(0xFFFECACA),
          width: item.isActive ? 1 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 76,
                        height: 76,
                        color: const Color(0xFFF3F4F6),
                        child: item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty
                            ? Image.network(
                                item.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, p1, p2) => const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey,
                                ),
                              )
                            : const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.isActive ? const Color(0xFF16A34A) : Colors.red.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.isActive ? 'Đang bán' : 'Đã ẩn',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Chi tiết sản phẩm
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.25),
                      ),
                      const SizedBox(height: 4),

                      // Danh mục & Thương hiệu Chips
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.category.name,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.brand.name,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Giá bán
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _currencyFormat.format(hasDiscount ? item.discountPrice : item.basePrice),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF97316),
                            ),
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 6),
                            Text(
                              _currencyFormat.format(item.basePrice),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 8),

            // Kho & Hành động (Sửa, Ẩn/Khôi phục)
            Row(
              children: [
                // Số lượng kho
                Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: item.totalStockQuantity > 0 ? const Color(0xFF16A34A) : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  item.totalStockQuantity > 0 ? 'Kho: ${item.totalStockQuantity}' : 'Hết hàng (0)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: item.totalStockQuantity > 0 ? const Color(0xFF16A34A) : Colors.red,
                  ),
                ),

                const Spacer(),

                // Nút sửa
                TextButton.icon(
                  onPressed: () => _openEditProduct(item),
                  icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                  label: const Text('Sửa', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 4),

                // Nút Xoá mềm (Ẩn) hoặc Khôi phục
                if (item.isActive)
                  TextButton.icon(
                    onPressed: () => _confirmSoftDelete(item),
                    icon: Icon(Icons.visibility_off_outlined, size: 14, color: Colors.amber.shade900),
                    label: Text(
                      'Ẩn',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _confirmRestore(item),
                    icon: const Icon(Icons.restore, size: 14, color: Color(0xFF16A34A)),
                    label: const Text(
                      'Khôi phục',
                      style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
