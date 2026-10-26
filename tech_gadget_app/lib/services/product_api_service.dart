import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/product.dart';

/// Các kiểu sắp xếp được .NET API hỗ trợ
enum ProductSort {
  newest('newest', 'Mới nhất'),
  priceAsc('price_asc', 'Giá: Thấp đến cao'),
  priceDesc('price_desc', 'Giá: Cao đến thấp'),
  name('name', 'Tên: A - Z');

  final String value;
  final String label;
  const ProductSort(this.value, this.label);
}

class ProductApiService {
  final String _baseUrl;

  ProductApiService({String? baseUrl})
      : _baseUrl = baseUrl ?? SupabaseConfig.apiBaseUrl;

  /// Gọi .NET API: GET /api/products (phân trang, lọc, tìm kiếm, sắp xếp)
  Future<PagedResult<ProductListItem>> getProducts({
    int page = 1,
    int pageSize = 20,
    List<String> categoryIds = const [],
    List<String> brandIds = const [],
    String? search,
    ProductSort sort = ProductSort.newest,
    int? minPrice,
    int? maxPrice,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': '$page',
      'pageSize': '$pageSize',
      'sortBy': sort.value,
      if (categoryIds.isNotEmpty) 'categoryIds': categoryIds,
      if (brandIds.isNotEmpty) 'brandIds': brandIds,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (minPrice != null) 'minPrice': '$minPrice',
      if (maxPrice != null) 'maxPrice': '$maxPrice',
    };
    final url = Uri.parse('$_baseUrl/api/products').replace(queryParameters: queryParameters);

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PagedResult.fromJson(data, ProductListItem.fromJson);
    } else {
      throw Exception('Lỗi khi tải danh sách sản phẩm: ${response.statusCode} - ${response.body}');
    }
  }

  /// Gọi .NET API: GET /api/products/{id} (chi tiết sản phẩm kèm các biến thể)
  Future<ProductDetail> getProductById(String id) async {
    final url = Uri.parse('$_baseUrl/api/products/$id');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ProductDetail.fromJson(data);
    } else if (response.statusCode == 404) {
      throw Exception('Sản phẩm không tồn tại hoặc đã ngừng kinh doanh (404).');
    } else {
      throw Exception('Lỗi khi tải chi tiết sản phẩm: ${response.statusCode} - ${response.body}');
    }
  }

  /// Gọi .NET API: GET /api/categories
  Future<List<Category>> getCategories() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/categories'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Lỗi khi tải danh mục: ${response.statusCode} - ${response.body}');
    }
  }

  /// Gọi .NET API: GET /api/brands
  Future<List<Brand>> getBrands() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/brands'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => Brand.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Lỗi khi tải thương hiệu: ${response.statusCode} - ${response.body}');
    }
  }
}
