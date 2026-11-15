import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/voucher.dart';

/// Service gọi API Voucher của .NET:
///   Khách hàng:
///     GET    /api/vouchers                 → getPublicVouchers (Kho voucher)
///     GET    /api/vouchers/my?subtotal=    → getMyVouchers (Ví voucher)
///     POST   /api/vouchers/{id}/claim      → claim
///     POST   /api/vouchers/claim-by-code   → claimByCode
///   Admin:
///     GET    /api/admin/vouchers           → getAdminVouchers
///     POST   /api/admin/vouchers           → createVoucher
///     PUT    /api/admin/vouchers/{id}      → updateVoucher
///     PATCH  /api/admin/vouchers/{id}/toggle → toggleVoucher
///     DELETE /api/admin/vouchers/{id}      → deleteVoucher
class VoucherApiService {
  final String _baseUrl;

  VoucherApiService({String? baseUrl}) : _baseUrl = baseUrl ?? SupabaseConfig.apiBaseUrl;

  Map<String, String> _headers(String accessToken) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập không hợp lệ hoặc đã hết hạn (401).');
    }
    if (response.statusCode == 403) {
      throw Exception(_parseMessage(response.body) ?? 'Bạn không có quyền thực hiện thao tác này.');
    }
    final msg = _parseMessage(response.body);
    if (msg != null) throw Exception(msg);
    throw Exception('Lỗi server: ${response.statusCode}');
  }

  String? _parseMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        if (json['message'] is String) return json['message'] as String;
        // ModelState validation errors: { errors: { Field: ["msg"] } }
        final errors = json['errors'];
        if (errors is Map<String, dynamic>) {
          for (final v in errors.values) {
            if (v is List && v.isNotEmpty) return v.first.toString();
          }
        }
        if (json['title'] is String) return json['title'] as String;
      }
    } catch (_) {}
    return null;
  }

  // ===================== KHÁCH HÀNG =====================

  Future<List<PublicVoucher>> getPublicVouchers(String accessToken) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/vouchers'), headers: _headers(accessToken));
    _throwIfError(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => PublicVoucher.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [subtotal]: tiền hàng của đơn đang thanh toán → server tính sẵn voucher nào dùng được
  Future<List<MyVoucher>> getMyVouchers(String accessToken, {double? subtotal}) async {
    final uri = Uri.parse('$_baseUrl/api/vouchers/my').replace(
      queryParameters: subtotal != null ? {'subtotal': subtotal.round().toString()} : null,
    );
    final response = await http.get(uri, headers: _headers(accessToken));
    _throwIfError(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => MyVoucher.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MyVoucher> claim(String accessToken, String voucherId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/vouchers/$voucherId/claim'),
      headers: _headers(accessToken),
    );
    _throwIfError(response);
    return MyVoucher.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<MyVoucher> claimByCode(String accessToken, String code) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/vouchers/claim-by-code'),
      headers: _headers(accessToken),
      body: jsonEncode({'code': code.trim()}),
    );
    _throwIfError(response);
    return MyVoucher.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ===================== ADMIN =====================

  Future<PagedVouchers> getAdminVouchers(
    String accessToken, {
    int page = 1,
    int pageSize = 20,
    String? search,
    String? status,
  }) async {
    final params = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
    if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
    if (status != null && status.isNotEmpty) params['status'] = status;

    final response = await http.get(
      Uri.parse('$_baseUrl/api/admin/vouchers').replace(queryParameters: params),
      headers: _headers(accessToken),
    );
    _throwIfError(response);
    return PagedVouchers.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AdminVoucher> createVoucher(String accessToken, VoucherFormData data) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/admin/vouchers'),
      headers: _headers(accessToken),
      body: jsonEncode(data.toJson()),
    );
    _throwIfError(response);
    return AdminVoucher.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AdminVoucher> updateVoucher(String accessToken, String id, VoucherFormData data) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/admin/vouchers/$id'),
      headers: _headers(accessToken),
      body: jsonEncode(data.toJson()),
    );
    _throwIfError(response);
    return AdminVoucher.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AdminVoucher> toggleVoucher(String accessToken, String id) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/api/admin/vouchers/$id/toggle'),
      headers: _headers(accessToken),
    );
    _throwIfError(response);
    return AdminVoucher.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteVoucher(String accessToken, String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/admin/vouchers/$id'),
      headers: _headers(accessToken),
    );
    _throwIfError(response);
  }
}
