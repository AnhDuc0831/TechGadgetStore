import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/order.dart';

/// Service kết nối các API Đơn hàng của .NET Web API
class OrderService {
  final String _baseUrl;

  OrderService({String? baseUrl})
      : _baseUrl = baseUrl ?? SupabaseConfig.apiBaseUrl;

  Map<String, String> _headers(String accessToken) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

  String? _parseMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        return json['message'] as String? ?? json['error'] as String?;
      }
    } catch (_) {}
    return null;
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final msg = _parseMessage(response.body);

    if (response.statusCode == 400) {
      throw Exception(msg ?? 'Yêu cầu không hợp lệ.');
    }
    if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }
    if (response.statusCode == 403) {
      throw Exception(msg ?? 'Bạn không có quyền thực hiện thao tác này.');
    }
    if (response.statusCode == 404) {
      throw Exception(msg ?? 'Không tìm thấy đơn hàng yêu cầu.');
    }
    if (response.statusCode >= 500) {
      throw Exception(msg ?? 'Máy chủ đang gặp lỗi (${response.statusCode}). Vui lòng thử lại sau.');
    }

    throw Exception(msg ?? 'Lỗi không xác định (${response.statusCode}).');
  }

  /// POST /api/orders/checkout – Đặt hàng và tính toán thanh toán
  Future<CheckoutResult> checkout(
    String accessToken,
    CheckoutRequest request,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/orders/checkout'),
        headers: _headers(accessToken),
        body: jsonEncode(request.toJson()),
      );
      _throwIfError(response);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return CheckoutResult.fromJson(json);
    } on SocketException {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng hoặc địa chỉ API.');
    } on http.ClientException {
      throw Exception('Lỗi kết nối HTTP. Vui lòng thử lại.');
    }
  }

  /// GET /api/orders – Lấy danh sách đơn hàng của người dùng hiện tại
  Future<List<OrderModel>> getUserOrders(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/orders'),
        headers: _headers(accessToken),
      );
      _throwIfError(response);
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on SocketException {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.');
    }
  }

  /// GET /api/orders/{id} – Xem chi tiết đơn hàng (khách hàng hoặc admin)
  Future<OrderModel> getOrderById(String accessToken, String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/orders/$orderId'),
        headers: _headers(accessToken),
      );
      _throwIfError(response);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return OrderModel.fromJson(json);
    } on SocketException {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.');
    }
  }

  /// GET /api/orders/{id}/payment-status – Đồng bộ và lấy trạng thái thanh toán từ PayOS
  Future<PaymentStatusResult> getPaymentStatus(
    String accessToken,
    String orderId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/orders/$orderId/payment-status'),
        headers: _headers(accessToken),
      );
      _throwIfError(response);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PaymentStatusResult.fromJson(json);
    } on SocketException {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.');
    }
  }

  /// POST /api/orders/{id}/cancel?reason=... – Khách hàng hủy đơn khi chưa thanh toán
  Future<bool> cancelOrder(
    String accessToken,
    String orderId, {
    String? reason,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/orders/$orderId/cancel').replace(
        queryParameters: reason != null && reason.trim().isNotEmpty
            ? {'reason': reason.trim()}
            : null,
      );

      final response = await http.post(
        uri,
        headers: _headers(accessToken),
      );
      _throwIfError(response);
      return true;
    } on SocketException {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.');
    }
  }

  // ── ADMIN ENDPOINTS ────────────────────────────────────────────────────────

  /// GET /api/admin/orders?page=&pageSize=&status= – Admin xem danh sách đơn hàng có phân trang
  Future<PagedOrders> getAdminOrders(
    String accessToken, {
    int page = 1,
    int pageSize = 10,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      };
      if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$_baseUrl/api/admin/orders').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: _headers(accessToken),
      );
      _throwIfError(response);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PagedOrders.fromJson(json);
    } on SocketException {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.');
    }
  }

  /// GET /api/orders/{id} – Admin xem chi tiết đơn hàng (bao gồm internalNote, needsReview)
  Future<AdminOrderModel> getAdminOrderById(
    String accessToken,
    String orderId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/orders/$orderId'),
        headers: _headers(accessToken),
      );
      _throwIfError(response);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return AdminOrderModel.fromJson(json);
    } on SocketException {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.');
    }
  }

  /// PUT /api/admin/orders/{id}/status – Admin cập nhật trạng thái đơn hàng
  Future<AdminOrderModel> updateOrderStatus(
    String accessToken,
    String orderId,
    String newStatus,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/admin/orders/$orderId/status'),
        headers: _headers(accessToken),
        body: jsonEncode({'status': newStatus}),
      );
      _throwIfError(response);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return AdminOrderModel.fromJson(json);
    } on SocketException {
      throw Exception('Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.');
    }
  }
}

