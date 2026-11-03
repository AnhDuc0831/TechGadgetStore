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

  /// Gọi .NET API: GET /api/admin/products (Admin xem toàn bộ sản phẩm gồm cả đang kinh doanh và ngừng kinh doanh)
  Future<PagedResult<ProductListItem>> getAdminProducts({
    required String accessToken,
    int page = 1,
    int pageSize = 20,
    String? search,
    String? categoryId,
    String? brandId,
    bool? isActive,
    String sortBy = 'newest',
  }) async {
    final queryParameters = <String, dynamic>{
      'page': '$page',
      'pageSize': '$pageSize',
      'sortBy': sortBy,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
      if (brandId != null && brandId.isNotEmpty) 'brandId': brandId,
      if (isActive != null) 'isActive': '$isActive',
    };

    final uri = Uri.parse('$_baseUrl/api/admin/products').replace(queryParameters: queryParameters);
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $accessToken',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PagedResult.fromJson(data, ProductListItem.fromJson);
    } else {
      String errorMsg = 'Lỗi khi tải danh sách quản lý (${response.statusCode})';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map<String, dynamic>) {
          errorMsg = errJson['message'] ?? errJson['error'] ?? response.body;
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  /// Gọi .NET API: GET /api/admin/products/{id} (Admin lấy chi tiết sản phẩm)
  Future<ProductDetail> getAdminProductById(String id, {required String accessToken}) async {
    final url = Uri.parse('$_baseUrl/api/admin/products/$id');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $accessToken',
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ProductDetail.fromJson(data);
    } else {
      throw Exception('Lỗi khi tải sản phẩm ($id): ${response.statusCode}');
    }
  }

  /// Gọi .NET API: POST /api/admin/products (Admin đăng sản phẩm mới kèm upload ảnh lên Cloudinary)
  Future<ProductDetail> createProduct(
    String accessToken,
    CreateProductDto dto,
    List<String> imagePaths,
  ) async {
    final uri = Uri.parse('$_baseUrl/api/admin/products');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $accessToken';

    request.fields['Name'] = dto.name;
    request.fields['CategoryId'] = dto.categoryId;
    request.fields['BrandId'] = dto.brandId;
    request.fields['BasePrice'] = dto.basePrice.toString();
    if (dto.discountPrice != null) {
      request.fields['DiscountPrice'] = dto.discountPrice.toString();
    }
    request.fields['StockQuantity'] = dto.stockQuantity.toString();
    if (dto.sku != null && dto.sku!.isNotEmpty) {
      request.fields['Sku'] = dto.sku!;
    }
    if (dto.description != null && dto.description!.isNotEmpty) {
      request.fields['Description'] = dto.description!;
    }
    request.fields['Specifications'] = dto.specifications;
    request.fields['IsActive'] = dto.isActive.toString();

    for (final path in imagePaths) {
      request.files.add(await http.MultipartFile.fromPath('ImageFiles', path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ProductDetail.fromJson(data);
    } else {
      String errorMsg = 'Lỗi khi tạo sản phẩm (${response.statusCode})';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map<String, dynamic>) {
          errorMsg = errJson['message'] ?? errJson['error'] ?? response.body;
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  /// Gọi .NET API: PUT /api/admin/products/{id} (Admin cập nhật thông tin sản phẩm)
  Future<ProductDetail> updateProduct(
    String accessToken,
    String productId,
    UpdateProductDto dto,
    List<String> newImagePaths,
  ) async {
    final uri = Uri.parse('$_baseUrl/api/admin/products/$productId');
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer $accessToken';

    request.fields['Name'] = dto.name;
    request.fields['CategoryId'] = dto.categoryId;
    request.fields['BrandId'] = dto.brandId;
    request.fields['BasePrice'] = dto.basePrice.toString();
    if (dto.discountPrice != null) {
      request.fields['DiscountPrice'] = dto.discountPrice.toString();
    }
    request.fields['StockQuantity'] = dto.stockQuantity.toString();
    if (dto.sku != null && dto.sku!.isNotEmpty) {
      request.fields['Sku'] = dto.sku!;
    }
    if (dto.description != null && dto.description!.isNotEmpty) {
      request.fields['Description'] = dto.description!;
    }
    request.fields['Specifications'] = dto.specifications;
    request.fields['IsActive'] = dto.isActive.toString();

    // Gửi danh sách ảnh cũ
    for (int i = 0; i < dto.existingImages.length; i++) {
      request.fields['ExistingImages[$i]'] = dto.existingImages[i];
    }

    // Gửi ảnh mới upload
    for (final path in newImagePaths) {
      request.files.add(await http.MultipartFile.fromPath('NewImageFiles', path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ProductDetail.fromJson(data);
    } else {
      String errorMsg = 'Lỗi khi cập nhật sản phẩm (${response.statusCode})';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map<String, dynamic>) {
          errorMsg = errJson['message'] ?? errJson['error'] ?? response.body;
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  /// Gọi .NET API: DELETE /api/admin/products/{id} (Admin xoá mềm/ẩn sản phẩm)
  Future<void> softDeleteProduct(String accessToken, String productId) async {
    final url = Uri.parse('$_baseUrl/api/admin/products/$productId');
    final response = await http.delete(url, headers: {
      'Authorization': 'Bearer $accessToken',
    });

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      String errorMsg = 'Lỗi khi ẩn sản phẩm (${response.statusCode})';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map<String, dynamic>) {
          errorMsg = errJson['message'] ?? errJson['error'] ?? response.body;
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  /// Gọi .NET API: PATCH /api/admin/products/{id}/restore (Admin khôi phục sản phẩm)
  Future<void> restoreProduct(String accessToken, String productId) async {
    final url = Uri.parse('$_baseUrl/api/admin/products/$productId/restore');
    final response = await http.patch(url, headers: {
      'Authorization': 'Bearer $accessToken',
    });

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      String errorMsg = 'Lỗi khi khôi phục sản phẩm (${response.statusCode})';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson is Map<String, dynamic>) {
          errorMsg = errJson['message'] ?? errJson['error'] ?? response.body;
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }
}
