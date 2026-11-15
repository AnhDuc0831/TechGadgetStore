import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/review.dart';

/// Service gọi API Đánh giá sản phẩm của .NET:
///   GET  /api/products/{id}/reviews        → getProductReviews (công khai)
///   GET  /api/products/{id}/reviews/me     → getMyStatus
///   POST /api/products/{id}/reviews        → submitReview (multipart)
///   GET  /api/reviews/pending              → getPendingReviews
///   GET  /api/admin/reviews                → getAdminReviews
///   PUT  /api/admin/reviews/{id}/reply     → reply
class ReviewApiService {
  final String _baseUrl;

  ReviewApiService({String? baseUrl}) : _baseUrl = baseUrl ?? SupabaseConfig.apiBaseUrl;

  Map<String, String> _headers(String? accessToken) => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập không hợp lệ hoặc đã hết hạn (401).');
    }
    if (response.statusCode == 413) {
      throw Exception('Ảnh quá lớn. Vui lòng chọn ảnh nhỏ hơn.');
    }
    final msg = _parseMessage(response.body);
    throw Exception(msg ?? 'Lỗi server: ${response.statusCode}');
  }

  String? _parseMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        if (json['message'] is String) return json['message'] as String;
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

  /// [accessToken] tuỳ chọn: nếu có, server đánh dấu được đánh giá nào là của mình (isMine)
  Future<ProductReviewsPage> getProductReviews(
    String productId, {
    String? accessToken,
    int page = 1,
    int pageSize = 10,
    int? rating,
    bool hasImages = false,
  }) async {
    final params = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
    if (rating != null) params['rating'] = '$rating';
    if (hasImages) params['hasImages'] = 'true';

    final response = await http.get(
      Uri.parse('$_baseUrl/api/products/$productId/reviews').replace(queryParameters: params),
      headers: _headers(accessToken),
    );
    _throwIfError(response);
    return ProductReviewsPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<MyReviewStatus> getMyStatus(String accessToken, String productId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/products/$productId/reviews/me'),
      headers: _headers(accessToken),
    );
    _throwIfError(response);
    return MyReviewStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Gửi mới / cập nhật đánh giá.
  /// [newImagePaths]: đường dẫn ảnh mới chọn từ máy; [keepImageUrls]: ảnh cũ muốn giữ (khi sửa).
  Future<Review> submitReview(
    String accessToken,
    String productId, {
    required int rating,
    String? comment,
    List<String> newImagePaths = const [],
    List<String> keepImageUrls = const [],
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/products/$productId/reviews'));
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.fields['Rating'] = '$rating';
    if (comment != null && comment.trim().isNotEmpty) {
      request.fields['Comment'] = comment.trim();
    }
    // ASP.NET bind List<string> từ form qua tên có chỉ số: KeepImageUrls[0], KeepImageUrls[1]...
    for (var i = 0; i < keepImageUrls.length; i++) {
      request.fields['KeepImageUrls[$i]'] = keepImageUrls[i];
    }
    for (final path in newImagePaths) {
      request.files.add(await http.MultipartFile.fromPath('Images', path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _throwIfError(response);
    return Review.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<PendingReviewItem>> getPendingReviews(String accessToken) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/reviews/pending'), headers: _headers(accessToken));
    _throwIfError(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => PendingReviewItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ===================== ADMIN =====================

  Future<PagedAdminReviews> getAdminReviews(
    String accessToken, {
    int page = 1,
    int pageSize = 20,
    int? rating,
    bool? hasReply,
    String? search,
  }) async {
    final params = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
    if (rating != null) params['rating'] = '$rating';
    if (hasReply != null) params['hasReply'] = '$hasReply';
    if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();

    final response = await http.get(
      Uri.parse('$_baseUrl/api/admin/reviews').replace(queryParameters: params),
      headers: _headers(accessToken),
    );
    _throwIfError(response);
    return PagedAdminReviews.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AdminReview> reply(String accessToken, String reviewId, String? reply) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/admin/reviews/$reviewId/reply'),
      headers: _headers(accessToken),
      body: jsonEncode({'reply': reply}),
    );
    _throwIfError(response);
    return AdminReview.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Admin: ẩn / hiện nội dung (bình luận + ảnh) của đánh giá khiếm nhã. Số sao luôn được giữ.
  Future<AdminReview> setContentHidden(String accessToken, String reviewId, bool hidden, {String? reason}) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/admin/reviews/$reviewId/visibility'),
      headers: _headers(accessToken),
      body: jsonEncode({'hidden': hidden, 'reason': reason}),
    );
    _throwIfError(response);
    return AdminReview.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
