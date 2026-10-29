import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../services/cart_api_service.dart';

/// Provider quản lý trạng thái giỏ hàng. Phải được cung cấp token từ AuthProvider.
class CartProvider extends ChangeNotifier {
  final CartApiService _service = CartApiService();

  CartModel _cart = CartModel.empty();
  bool _isLoading = false;
  String? _errorMessage;

  CartModel get cart => _cart;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get itemCount => _cart.totalQuantity;
  bool get isEmpty => _cart.items.isEmpty;

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setCart(CartModel cart) {
    _cart = cart;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  /// Xóa giỏ hàng khi đăng xuất
  void clearLocal() {
    _cart = CartModel.empty();
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  // ── API Actions ───────────────────────────────────────────────────────────

  /// Tải giỏ hàng từ server
  Future<void> fetchCart(String accessToken) async {
    _setLoading(true);
    try {
      final cart = await _service.getCart(accessToken);
      _setCart(cart);
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Thêm sản phẩm vào giỏ hàng
  /// Trả về true nếu thành công, false nếu lỗi.
  Future<bool> addItem(
    String accessToken, {
    required String productVariantId,
    int quantity = 1,
  }) async {
    _setLoading(true);
    try {
      final cart = await _service.addItem(
        accessToken,
        productVariantId: productVariantId,
        quantity: quantity,
      );
      _setCart(cart);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Cập nhật số lượng một mục trong giỏ
  Future<bool> updateItem(
    String accessToken, {
    required String itemId,
    required int quantity,
  }) async {
    _setLoading(true);
    try {
      final cart = await _service.updateItem(
        accessToken,
        itemId: itemId,
        quantity: quantity,
      );
      _setCart(cart);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Xóa một mục khỏi giỏ hàng
  Future<bool> removeItem(
    String accessToken, {
    required String itemId,
  }) async {
    _setLoading(true);
    try {
      final cart = await _service.removeItem(accessToken, itemId: itemId);
      _setCart(cart);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Xóa toàn bộ giỏ hàng
  Future<bool> clearCart(String accessToken) async {
    _setLoading(true);
    try {
      final cart = await _service.clearCart(accessToken);
      _setCart(cart);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }
}
