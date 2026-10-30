import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/order_service.dart';

class OrderProvider extends ChangeNotifier {
  final OrderService _service;

  OrderProvider({OrderService? service}) : _service = service ?? OrderService();

  // ── Customer State ──
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ── Admin State ──
  PagedOrders? _adminOrders;
  bool _isAdminLoading = false;
  String? _adminErrorMessage;

  PagedOrders? get adminOrders => _adminOrders;
  bool get isAdminLoading => _isAdminLoading;
  String? get adminErrorMessage => _adminErrorMessage;

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _setError(String? msg) {
    _errorMessage = msg;
    _isLoading = false;
    notifyListeners();
  }

  void _setAdminLoading(bool val) {
    _isAdminLoading = val;
    notifyListeners();
  }

  void _setAdminError(String? msg) {
    _adminErrorMessage = msg;
    _isAdminLoading = false;
    notifyListeners();
  }

  void clearErrors() {
    _errorMessage = null;
    _adminErrorMessage = null;
    notifyListeners();
  }

  // ── CUSTOMER METHODS ───────────────────────────────────────────────────────

  /// Tải lịch sử đơn hàng của người dùng hiện tại
  Future<void> loadOrders(String token) async {
    _setLoading(true);
    try {
      _orders = await _service.getUserOrders(token);
      _errorMessage = null;
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Thực hiện đặt hàng
  Future<CheckoutResult> checkout(String token, CheckoutRequest request) async {
    _setLoading(true);
    try {
      final result = await _service.checkout(token, request);
      _errorMessage = null;
      return result;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _setError(msg);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Lấy chi tiết đơn hàng
  Future<OrderModel> getOrderDetails(String token, String orderId) async {
    try {
      return await _service.getOrderById(token, orderId);
    } catch (e) {
      rethrow;
    }
  }

  /// Lấy/đồng bộ trạng thái thanh toán
  Future<PaymentStatusResult> pollPaymentStatus(
    String token,
    String orderId,
  ) async {
    try {
      return await _service.getPaymentStatus(token, orderId);
    } catch (e) {
      rethrow;
    }
  }

  /// Khách hàng hủy đơn hàng chưa thanh toán
  Future<bool> cancelOrder(
    String token,
    String orderId, {
    String? reason,
  }) async {
    _setLoading(true);
    try {
      final success = await _service.cancelOrder(token, orderId, reason: reason);
      if (success) {
        // Tải lại danh sách đơn hàng
        await loadOrders(token);
      }
      return success;
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── ADMIN METHODS ──────────────────────────────────────────────────────────

  /// Admin tải danh sách đơn hàng có phân trang và lọc theo trạng thái
  Future<void> loadAdminOrders(
    String token, {
    int page = 1,
    int pageSize = 10,
    String? status,
  }) async {
    _setAdminLoading(true);
    try {
      _adminOrders = await _service.getAdminOrders(
        token,
        page: page,
        pageSize: pageSize,
        status: status,
      );
      _adminErrorMessage = null;
    } catch (e) {
      _setAdminError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _isAdminLoading = false;
      notifyListeners();
    }
  }

  /// Admin lấy chi tiết đơn hàng (bao gồm internalNote, needsReview)
  Future<AdminOrderModel> getAdminOrderDetails(
    String token,
    String orderId,
  ) async {
    try {
      return await _service.getAdminOrderById(token, orderId);
    } catch (e) {
      rethrow;
    }
  }

  /// Admin cập nhật trạng thái đơn hàng
  Future<AdminOrderModel> updateOrderStatus(
    String token,
    String orderId,
    String newStatus,
  ) async {
    _setAdminLoading(true);
    try {
      final updated = await _service.updateOrderStatus(token, orderId, newStatus);
      _adminErrorMessage = null;

      // Cập nhật trong danh sách adminOrders nếu đang có
      if (_adminOrders != null) {
        final index = _adminOrders!.items.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          _adminOrders!.items[index] = updated;
        }
      }
      return updated;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _setAdminError(msg);
      rethrow;
    } finally {
      _isAdminLoading = false;
      notifyListeners();
    }
  }
}

