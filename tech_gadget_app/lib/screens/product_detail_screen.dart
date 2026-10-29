import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';
import '../services/product_api_service.dart';
import '../utils/formatters.dart';
import '../widgets/product_card.dart';
import '../widgets/product_image.dart';
import '../widgets/rating_stars.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductApiService _productApiService = ProductApiService();

  ProductDetail? _product;
  bool _isLoading = true;
  String? _errorMessage;

  // Giá trị thuộc tính đang chọn, vd: {Color: Black, Storage: 128GB}
  Map<String, String> _selectedValues = {};
  int _quantity = 1;
  bool _isFavorite = false;

  List<ProductListItem> _sameBrandProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final product = await _productApiService.getProductById(widget.productId);
      if (!mounted) return;

      // Mặc định chọn biến thể còn hàng đầu tiên
      final variants = product.variants;
      final defaultVariant = variants.isEmpty
          ? null
          : variants.firstWhere((v) => v.inStock, orElse: () => variants.first);

      setState(() {
        _product = product;
        _selectedValues = Map.of(defaultVariant?.attributes ?? {});
        _quantity = 1;
        _isLoading = false;
      });
      _loadSameBrandProducts(product);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSameBrandProducts(ProductDetail product) async {
    try {
      // Lấy dư 1 sản phẩm để vẫn đủ 10 sau khi bỏ sản phẩm đang xem
      final result = await _productApiService.getProducts(
        pageSize: 11,
        brandIds: [product.brand.id],
      );
      if (!mounted) return;
      setState(() {
        _sameBrandProducts = result.items.where((p) => p.id != product.id).take(10).toList();
      });
    } catch (e) {
      debugPrint('Không thể tải sản phẩm cùng thương hiệu: $e');
    }
  }

  void _openProduct(ProductListItem product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id)),
    );
  }

  ProductVariant? get _selectedVariant {
    final variants = _product?.variants ?? [];
    for (final variant in variants) {
      if (_matches(variant, _selectedValues)) return variant;
    }
    return null;
  }

  bool _matches(ProductVariant variant, Map<String, String> values) {
    return values.entries.every((e) => variant.attributes[e.key] == e.value);
  }

  /// Giá trị có tồn tại biến thể khớp với các lựa chọn hiện tại của những thuộc tính khác hay không
  bool _isOptionAvailable(String key, String value) {
    final candidate = {..._selectedValues, key: value};
    return _product!.variants.any((v) => _matches(v, candidate));
  }

  void _selectOption(String key, String value) {
    final candidate = {..._selectedValues, key: value};
    final variants = _product!.variants;

    if (variants.any((v) => _matches(v, candidate))) {
      setState(() {
        _selectedValues = candidate;
        _quantity = 1;
      });
      return;
    }

    // Tổ hợp không tồn tại: chuyển sang biến thể đầu tiên có giá trị vừa chọn (ưu tiên còn hàng)
    final withValue = variants.where((v) => v.attributes[key] == value).toList();
    if (withValue.isEmpty) return;
    final fallback = withValue.firstWhere((v) => v.inStock, orElse: () => withValue.first);
    setState(() {
      _selectedValues = Map.of(fallback.attributes);
      _quantity = 1;
    });
  }

  Future<void> _addToCart() async {
    final variant = _selectedVariant;
    if (variant == null) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để thêm vào giỏ hàng.')),
      );
      return;
    }

    final token = auth.accessToken!;
    final cartProvider = context.read<CartProvider>();

    final ok = await cartProvider.addItem(
      token,
      productVariantId: variant.id,
      quantity: _quantity,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã thêm vào giỏ hàng!'),
          action: SnackBarAction(
            label: 'Xem giỏ hàng',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cartProvider.errorMessage ?? 'Không thể thêm vào giỏ hàng.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _toggleFavorite() {
    // TODO: Gọi API thêm/xóa sản phẩm khỏi danh sách yêu thích
    setState(() => _isFavorite = !_isFavorite);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFavorite ? 'Đã thêm vào yêu thích.' : 'Đã bỏ khỏi yêu thích.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_product?.name ?? 'Chi tiết sản phẩm', overflow: TextOverflow.ellipsis),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null || _product == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('Không thể tải sản phẩm', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? '',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadProduct,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final product = _product!;

    return RefreshIndicator(
      onRefresh: _loadProduct,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;

          final image = ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: AspectRatio(
              aspectRatio: 1,
              child: ProductImage(url: product.thumbnailUrl, iconSize: 96),
            ),
          );

          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isWide) ...[
                _buildTitleSection(product, theme),
                const SizedBox(height: 12),
                Center(child: image),
                const SizedBox(height: 16),
              ] else
                _buildTitleSection(product, theme),
              const Divider(height: 24),
              _buildPriceSection(product, theme),
              const SizedBox(height: 16),
              ..._buildVariantSelectors(product, theme),
              _buildBuyBox(product, theme),
              const SizedBox(height: 24),
              _buildDescription(product, theme),
              const SizedBox(height: 24),
              _buildSpecifications(product, theme),
            ],
          );

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: image),
                              const SizedBox(width: 32),
                              Expanded(flex: 6, child: info),
                            ],
                          )
                        : info,
                    if (_sameBrandProducts.isNotEmpty) ...[
                      const Divider(height: 40),
                      _buildSameBrandProducts(product, theme),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitleSection(ProductDetail product, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thương hiệu: ${product.brand.name}',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 4),
        Text(
          product.name,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (product.reviewCount > 0) ...[
              Text(product.averageRating.toStringAsFixed(1), style: theme.textTheme.bodyMedium),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: RatingStars(
                rating: product.averageRating,
                reviewCount: product.reviewCount,
                size: 18,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceSection(ProductDetail product, ThemeData theme) {
    final variant = _selectedVariant;
    final price = variant?.finalPrice ?? product.minPrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatVnd(price),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
          ),
        ),
        if (product.hasPriceRange)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Khoảng giá: ${formatVnd(product.minPrice)} - ${formatVnd(product.maxPrice)}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildVariantSelectors(ProductDetail product, ThemeData theme) {
    final widgets = <Widget>[];

    product.attributeOptions.forEach((key, values) {
      widgets.add(
        Text.rich(
          TextSpan(
            text: '$key: ',
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(
                text: _selectedValues[key] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((value) {
            final selected = _selectedValues[key] == value;
            final available = _isOptionAvailable(key, value);
            return ChoiceChip(
              label: Text(value),
              selected: selected,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: available ? null : Colors.grey.shade500,
                decoration: available ? null : TextDecoration.lineThrough,
              ),
              side: BorderSide(
                color: selected ? theme.colorScheme.primary : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
              onSelected: (_) => _selectOption(key, value),
            );
          }).toList(),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    });

    return widgets;
  }

  Widget _buildBuyBox(ProductDetail product, ThemeData theme) {
    final variant = _selectedVariant;
    final canBuy = variant != null && variant.inStock;
    final maxQuantity = variant == null ? 1 : variant.stockQuantity.clamp(1, 10);

    final String stockText;
    final Color stockColor;
    if (variant == null) {
      stockText = product.variants.isEmpty ? 'Sản phẩm chưa có phiên bản để bán' : 'Vui lòng chọn phiên bản';
      stockColor = Colors.grey.shade700;
    } else if (!variant.inStock) {
      stockText = 'Tạm hết hàng';
      stockColor = Colors.red.shade700;
    } else if (variant.stockQuantity < 10) {
      stockText = 'Chỉ còn ${variant.stockQuantity} sản phẩm';
      stockColor = Colors.orange.shade800;
    } else {
      stockText = 'Còn hàng';
      stockColor = Colors.green.shade700;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              stockText,
              style: theme.textTheme.titleMedium?.copyWith(
                color: stockColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (variant != null) ...[
              const SizedBox(height: 4),
              Text(
                'SKU: ${variant.sku}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
            if (canBuy) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Số lượng:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _quantity.clamp(1, maxQuantity),
                    items: List.generate(
                      maxQuantity,
                      (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                    ),
                    onChanged: (value) => setState(() => _quantity = value ?? 1),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: canBuy ? _addToCart : null,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Thêm vào giỏ hàng'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _isFavorite ? Colors.red.shade600 : null,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _toggleFavorite,
              icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
              label: Text(_isFavorite ? 'Đã yêu thích' : 'Thêm vào yêu thích'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription(ProductDetail product, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mô tả sản phẩm',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          (product.description?.trim().isNotEmpty ?? false)
              ? product.description!
              : 'Chưa có mô tả cho sản phẩm này.',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  Widget _buildSameBrandProducts(ProductDetail product, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sản phẩm khác của ${product.brand.name}',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _sameBrandProducts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = _sameBrandProducts[index];
              return SizedBox(
                width: 170,
                child: ProductCard(product: item, onTap: () => _openProduct(item)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpecifications(ProductDetail product, ThemeData theme) {
    final variant = _selectedVariant;
    final rows = <MapEntry<String, String>>[
      MapEntry('Thương hiệu', product.brand.name),
      MapEntry('Danh mục', product.category.name),
      if (variant != null) ...variant.attributes.entries,
      if (variant != null) MapEntry('SKU', variant.sku),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông tin sản phẩm',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(3)},
          border: TableBorder.all(color: Colors.grey.shade300),
          children: rows.map((row) {
            return TableRow(
              children: [
                Container(
                  color: Colors.grey.shade100,
                  padding: const EdgeInsets.all(10),
                  child: Text(row.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(row.value),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
