import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../services/product_api_service.dart';
import '../widgets/product_card.dart';
import '../widgets/product_filter_sheet.dart';
import 'admin_dashboard_screen.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _pageSize = 20;

  final ProductApiService _productApiService = ProductApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Category> _categories = [];
  List<Brand> _brands = [];

  // Bộ lọc hiện tại
  String? _selectedCategoryId;
  ProductFilter _filter = const ProductFilter();
  ProductSort _sort = ProductSort.newest;
  String _search = '';

  // Trạng thái danh sách sản phẩm
  final List<ProductListItem> _products = [];
  int _page = 0;
  int _totalCount = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Tăng mỗi lần đổi bộ lọc để bỏ qua kết quả của các request cũ
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFilters();
    _reloadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    try {
      final results = await Future.wait([
        _productApiService.getCategories(),
        _productApiService.getBrands(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<Category>;
        _brands = results[1] as List<Brand>;
      });
    } catch (e) {
      debugPrint('Không thể tải danh mục/thương hiệu: $e');
    }
  }

  Future<void> _reloadProducts() async {
    _requestId++;
    setState(() {
      _products.clear();
      _page = 0;
      _totalCount = 0;
      _hasMore = true;
      _isLoading = false;
      _errorMessage = null;
    });
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;

    final requestId = _requestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _productApiService.getProducts(
        page: _page + 1,
        pageSize: _pageSize,
        categoryIds: _selectedCategoryId == null ? [] : [_selectedCategoryId!],
        brandIds: _filter.brandIds.toList(),
        search: _search,
        sort: _sort,
        minPrice: _filter.minPrice,
        maxPrice: _filter.maxPrice,
      );
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _products.addAll(result.items);
        _page = result.page;
        _totalCount = result.totalCount;
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 400) {
      _loadNextPage();
    }
  }

  void _submitSearch(String value) {
    _search = value.trim();
    _reloadProducts();
  }

  void _clearSearch() {
    _searchController.clear();
    if (_search.isNotEmpty) _submitSearch('');
    setState(() {});
  }

  void _selectCategory(String? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    _reloadProducts();
  }

  void _selectSort(ProductSort sort) {
    if (_sort == sort) return;
    _sort = sort;
    _reloadProducts();
  }

  void _openProduct(ProductListItem product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id)),
    );
  }

  Future<void> _showFilterSheet() async {
    final result = await showModalBottomSheet<ProductFilter>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ProductFilterSheet(brands: _brands, initialFilter: _filter),
    );

    if (result == null || !mounted) return;
    _filter = result;
    _reloadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        titleSpacing: 12,
        title: _buildSearchField(theme),
        actions: [
          // Nút Dashboard nhanh cho Admin trên AppBar
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (!auth.isAdmin) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Bảng Điều Khiển Admin (Dashboard)',
                icon: const Icon(Icons.analytics_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                ),
              );
            },
          ),
          // Icon Giỏ hàng kèm badge số lượng
          Consumer2<AuthProvider, CartProvider>(
            builder: (context, auth, cart, _) {
              if (!auth.isAuthenticated) return const SizedBox.shrink();
              final count = cart.itemCount;
              return IconButton(
                tooltip: 'Giỏ hàng',
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Hồ sơ cá nhân',
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildCategoryBar(theme),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reloadProducts,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Banner chào mừng và lối tắt vào Admin Dashboard
            SliverToBoxAdapter(
              child: Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (!auth.isAdmin) return const SizedBox.shrink();
                  return _buildAdminQuickBanner(context);
                },
              ),
            ),
            SliverToBoxAdapter(child: _buildResultsHeader(theme)),
            if (_products.isEmpty && !_isLoading)
              SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState(theme))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisExtent: 320,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = _products[index];
                      return ProductCard(product: product, onTap: () => _openProduct(product));
                    },
                    childCount: _products.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(child: _buildFooter()),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminQuickBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insights_rounded, color: Colors.blueAccent, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quản Trị Viên (Admin)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Xem thống kê sản phẩm, đơn hàng & lợi nhuận',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.arrow_forward, size: 14),
            label: const Text(
              'Dashboard',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: _submitSearch,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm sản phẩm...',
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.close), onPressed: _clearSearch),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBar(ThemeData theme) {
    Widget chip(String label, String? categoryId) {
      final selected = _selectedCategoryId == categoryId;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => _selectCategory(categoryId),
        ),
      );
    }

    return Container(
      height: 48,
      color: theme.colorScheme.primaryContainer,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          chip('Tất cả', null),
          ..._categories.map((c) => chip(c.name, c.id)),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(ThemeData theme) {
    final filterCount = _filter.activeCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _search.isEmpty ? '$_totalCount sản phẩm' : '$_totalCount kết quả cho "$_search"',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<ProductSort>(
            initialValue: _sort,
            onSelected: _selectSort,
            itemBuilder: (_) => ProductSort.values
                .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 18),
                  const SizedBox(width: 4),
                  Text(_sort.label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _showFilterSheet,
            icon: Badge(
              isLabelVisible: filterCount > 0,
              label: Text('$filterCount'),
              child: const Icon(Icons.tune, size: 18),
            ),
            label: const Text('Lọc'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _errorMessage != null ? Icons.cloud_off : Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage != null ? 'Không thể tải sản phẩm' : 'Không tìm thấy sản phẩm phù hợp',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _reloadProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null && _products.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: TextButton.icon(
            onPressed: _loadNextPage,
            icon: const Icon(Icons.refresh),
            label: const Text('Tải thêm thất bại, thử lại'),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}
