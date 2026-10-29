import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/cart.dart';

/// Service gọi 5 API Cart của .NET:
///   GET    /api/cart              → getCart
///   POST   /api/cart/items        → addItem
///   PUT    /api/cart/items/{id}   → updateItem
///   DELETE /api/cart/items/{id}   → removeItem
///   DELETE /api/cart              → clearCart
class CartApiService {
  final String _baseUrl;

  CartApiService({String? baseUrl})
      : _baseUrl = baseUrl ?? SupabaseConfig.apiBaseUrl;

  Map<String, String> _headers(String accessToken) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

  void _throwIfError(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) return;
    if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập không hợp lệ hoặc đã hết hạn (401).');
    }
    if (response.statusCode == 404) {
      final msg = _parseMessage(response.body) ?? 'Không tìm thấy tài nguyên.';
      throw Exception(msg);
    }
    if (response.statusCode == 400) {
      final msg = _parseMessage(response.body) ?? 'Yêu cầu không hợp lệ.';
      throw Exception(msg);
    }
    throw Exception('Lỗi server: ${response.statusCode} - ${response.body}');
  }

  String? _parseMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// GET /api/cart – Lấy giỏ hàng của người dùng hiện tại
  Future<CartModel> getCart(String accessToken) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/cart'),
      headers: _headers(accessToken),
    );
    _throwIfError(response);
    return CartModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// POST /api/cart/items – Thêm sản phẩm vào giỏ hàng
  Future<CartModel> addItem(
    String accessToken, {
    required String productVariantId,
    int quantity = 1,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/cart/items'),
      headers: _headers(accessToken),
      body: jsonEncode({
        'productVariantId': productVariantId,
        'quantity': quantity,
      }),
    );
    _throwIfError(response);
    return CartModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// PUT /api/cart/items/{itemId} – Cập nhật số lượng một mục trong giỏ
  Future<CartModel> updateItem(
    String accessToken, {
    required String itemId,
    required int quantity,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/cart/items/$itemId'),
      headers: _headers(accessToken),
      body: jsonEncode({'quantity': quantity}),
    );
    _throwIfError(response);
    return CartModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// DELETE /api/cart/items/{itemId} – Xóa một mục khỏi giỏ hàng
  Future<CartModel> removeItem(
    String accessToken, {
    required String itemId,
  }) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/cart/items/$itemId'),
      headers: _headers(accessToken),
    );
    _throwIfError(response);
    return CartModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// DELETE /api/cart – Xóa toàn bộ giỏ hàng
  Future<CartModel> clearCart(String accessToken) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/cart'),
      headers: _headers(accessToken),
    );
    _throwIfError(response);
    return CartModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
