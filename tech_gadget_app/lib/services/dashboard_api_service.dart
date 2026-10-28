import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/dashboard.dart';

class DashboardApiService {
  final String _baseUrl;

  DashboardApiService({String? baseUrl})
      : _baseUrl = baseUrl ?? SupabaseConfig.apiBaseUrl;

  /// Gọi .NET API: GET /api/dashboard/overview?period={today|7days|30days|this_month|this_year|all}
  Future<DashboardOverview> getOverview({
    String period = '30days',
    String? accessToken,
  }) async {
    final url = Uri.parse('$_baseUrl/api/dashboard/overview').replace(queryParameters: {
      'period': period,
    });

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return DashboardOverview.fromJson(data);
    } else if (response.statusCode == 403) {
      throw Exception('Truy cập bị từ chối: Chỉ tài khoản Quản trị viên (Admin) mới có quyền truy cập trang này.');
    } else {
      throw Exception('Lỗi khi tải dữ liệu thống kê: ${response.statusCode} - ${response.body}');
    }
  }
}

