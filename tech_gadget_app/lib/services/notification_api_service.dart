import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/app_notification.dart';

/// Service gọi API Thông báo của .NET:
///   GET   /api/notifications?page=&pageSize=&unreadOnly=
///   GET   /api/notifications/unread-count
///   PATCH /api/notifications/{id}/read
///   PATCH /api/notifications/read-all
class NotificationApiService {
  final String _baseUrl;

  NotificationApiService({String? baseUrl}) : _baseUrl = baseUrl ?? SupabaseConfig.apiBaseUrl;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  void _throwIfError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    if (res.statusCode == 401) throw Exception('Phiên đăng nhập đã hết hạn (401).');
    String? msg;
    try {
      final json = jsonDecode(res.body);
      if (json is Map<String, dynamic>) msg = json['message'] as String?;
    } catch (_) {}
    throw Exception(msg ?? 'Lỗi server: ${res.statusCode}');
  }

  Future<List<AppNotification>> getNotifications(
    String token, {
    int page = 1,
    int pageSize = 20,
    bool unreadOnly = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/notifications').replace(queryParameters: {
      'page': '$page',
      'pageSize': '$pageSize',
      if (unreadOnly) 'unreadOnly': 'true',
    });
    final res = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 15));
    _throwIfError(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['items'] as List<dynamic>? ?? [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UnreadInfo> getUnreadInfo(String token) async {
    final res = await http
        .get(Uri.parse('$_baseUrl/api/notifications/unread-count'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    _throwIfError(res);
    return UnreadInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> markAsRead(String token, String id) async {
    final res = await http.patch(Uri.parse('$_baseUrl/api/notifications/$id/read'), headers: _headers(token));
    _throwIfError(res);
  }

  Future<void> markAllAsRead(String token) async {
    final res = await http.patch(Uri.parse('$_baseUrl/api/notifications/read-all'), headers: _headers(token));
    _throwIfError(res);
  }
}
