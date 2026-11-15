import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/catalog_admin.dart';

/// Service gọi API quản lý Danh mục & Thương hiệu (Admin):
///   GET/POST        /api/admin/categories      PUT/DELETE /api/admin/categories/{id}
///   GET/POST        /api/admin/brands          PUT/DELETE /api/admin/brands/{id}
class CatalogAdminApiService {
  final String _baseUrl;

  CatalogAdminApiService({String? baseUrl}) : _baseUrl = baseUrl ?? SupabaseConfig.apiBaseUrl;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập không hợp lệ hoặc đã hết hạn (401).');
    }
    if (response.statusCode == 413) {
      throw Exception('Ảnh quá lớn. Vui lòng chọn ảnh nhỏ hơn 5MB.');
    }
    String? msg;
    try {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) {
        msg = json['message'] as String? ?? json['title'] as String?;
      }
    } catch (_) {}
    throw Exception(msg ?? 'Lỗi server: ${response.statusCode}');
  }

  Future<http.Response> _sendMultipart(
    String method,
    String path,
    String token,
    Map<String, String> fields, {
    String? fileField,
    String? filePath,
  }) async {
    final request = http.MultipartRequest(method, Uri.parse('$_baseUrl$path'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);
    if (fileField != null && filePath != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    }
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  // ===================== DANH MỤC =====================

  Future<List<AdminCategory>> getCategories(String token) async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/categories'), headers: _headers(token));
    _throwIfError(res);
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => AdminCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// [id] null → tạo mới; ngược lại → cập nhật
  Future<AdminCategory> saveCategory(
    String token, {
    String? id,
    required String name,
    String? slug,
    String? description,
    String? imagePath,
    bool removeImage = false,
  }) async {
    final fields = <String, String>{'Name': name.trim()};
    if (slug != null && slug.trim().isNotEmpty) fields['Slug'] = slug.trim();
    if (description != null && description.trim().isNotEmpty) fields['Description'] = description.trim();
    if (removeImage) fields['RemoveImage'] = 'true';

    final res = await _sendMultipart(
      id == null ? 'POST' : 'PUT',
      id == null ? '/api/admin/categories' : '/api/admin/categories/$id',
      token,
      fields,
      fileField: 'ImageFile',
      filePath: imagePath,
    );
    _throwIfError(res);
    return AdminCategory.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String token, String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/categories/$id'), headers: _headers(token));
    _throwIfError(res);
  }

  // ===================== THƯƠNG HIỆU =====================

  Future<List<AdminBrand>> getBrands(String token) async {
    final res = await http.get(Uri.parse('$_baseUrl/api/admin/brands'), headers: _headers(token));
    _throwIfError(res);
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => AdminBrand.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminBrand> saveBrand(
    String token, {
    String? id,
    required String name,
    String? logoPath,
    bool removeLogo = false,
  }) async {
    final fields = <String, String>{'Name': name.trim()};
    if (removeLogo) fields['RemoveLogo'] = 'true';

    final res = await _sendMultipart(
      id == null ? 'POST' : 'PUT',
      id == null ? '/api/admin/brands' : '/api/admin/brands/$id',
      token,
      fields,
      fileField: 'LogoFile',
      filePath: logoPath,
    );
    _throwIfError(res);
    return AdminBrand.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteBrand(String token, String id) async {
    final res = await http.delete(Uri.parse('$_baseUrl/api/admin/brands/$id'), headers: _headers(token));
    _throwIfError(res);
  }
}
