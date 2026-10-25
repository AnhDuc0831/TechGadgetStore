import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/user_profile.dart';

class ProfileApiService {
  final String _baseUrl;

  ProfileApiService({String? baseUrl})
      : _baseUrl = baseUrl ?? SupabaseConfig.apiBaseUrl;

  /// Gọi .NET API: GET /api/profiles/me (yêu cầu Bearer JWT token từ Supabase)
  Future<UserProfile> getMyProfile(String accessToken) async {
    final url = Uri.parse('$_baseUrl/api/profiles/me');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập không hợp lệ hoặc đã hết hạn (401).');
    } else if (response.statusCode == 404) {
      throw Exception('Không tìm thấy thông tin hồ sơ người dùng trong hệ thống (404).');
    } else {
      throw Exception('Lỗi khi lấy thông tin hồ sơ: ${response.statusCode} - ${response.body}');
    }
  }

  /// Gọi .NET API: PUT /api/profiles/me để cập nhật họ tên, ảnh đại diện, SĐT
  Future<UserProfile> updateMyProfile(
    String accessToken, {
    String? fullName,
    String? avatarUrl,
    String? phone,
  }) async {
    final url = Uri.parse('$_baseUrl/api/profiles/me');

    final payload = <String, dynamic>{};
    if (fullName != null) payload['fullName'] = fullName;
    if (avatarUrl != null) payload['avatarUrl'] = avatarUrl;
    if (phone != null) payload['phone'] = phone;

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    } else {
      throw Exception('Lỗi cập nhật hồ sơ: ${response.statusCode} - ${response.body}');
    }
  }
}
