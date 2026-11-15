int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;
double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

DateTime _parseDate(dynamic v) {
  if (v is String && v.isNotEmpty) {
    try {
      return DateTime.parse(v).toLocal();
    } catch (_) {}
  }
  return DateTime.now();
}

DateTime? _parseNullableDate(dynamic v) {
  if (v is String && v.isNotEmpty) {
    try {
      return DateTime.parse(v).toLocal();
    } catch (_) {}
  }
  return null;
}

String _two(int n) => n.toString().padLeft(2, '0');
String formatReviewDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// Một đánh giá sản phẩm (khớp ReviewDto bên .NET)
class Review {
  final String id;
  final String productId;
  final int rating;
  final String? comment;
  final List<String> images;
  final String reviewerName;
  final String? reviewerAvatarUrl;
  final String? variantSku;
  final bool isVerifiedPurchase;
  final DateTime createdAt;
  final DateTime? editedAt;
  final String? adminReply;
  final DateTime? repliedAt;
  final bool isMine;

  Review({
    required this.id,
    required this.productId,
    required this.rating,
    this.comment,
    required this.images,
    required this.reviewerName,
    this.reviewerAvatarUrl,
    this.variantSku,
    required this.isVerifiedPurchase,
    required this.createdAt,
    this.editedAt,
    this.adminReply,
    this.repliedAt,
    required this.isMine,
  });

  bool get isEdited => editedAt != null;
  bool get hasReply => adminReply != null && adminReply!.trim().isNotEmpty;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String? ?? '',
        productId: json['productId'] as String? ?? '',
        rating: _toInt(json['rating']),
        comment: json['comment'] as String?,
        images: (json['images'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        reviewerName: json['reviewerName'] as String? ?? 'Khách hàng',
        reviewerAvatarUrl: json['reviewerAvatarUrl'] as String?,
        variantSku: json['variantSku'] as String?,
        isVerifiedPurchase: json['isVerifiedPurchase'] as bool? ?? false,
        createdAt: _parseDate(json['createdAt']),
        editedAt: _parseNullableDate(json['editedAt']),
        adminReply: json['adminReply'] as String?,
        repliedAt: _parseNullableDate(json['repliedAt']),
        isMine: json['isMine'] as bool? ?? false,
      );
}

/// Đánh giá kèm thông tin sản phẩm (cho Admin)
class AdminReview extends Review {
  final String productName;
  final String? productThumbnailUrl;

  AdminReview({
    required super.id,
    required super.productId,
    required super.rating,
    super.comment,
    required super.images,
    required super.reviewerName,
    super.reviewerAvatarUrl,
    super.variantSku,
    required super.isVerifiedPurchase,
    required super.createdAt,
    super.editedAt,
    super.adminReply,
    super.repliedAt,
    required this.productName,
    this.productThumbnailUrl,
  }) : super(isMine: false);

  factory AdminReview.fromJson(Map<String, dynamic> json) {
    final b = Review.fromJson(json);
    return AdminReview(
      id: b.id,
      productId: b.productId,
      rating: b.rating,
      comment: b.comment,
      images: b.images,
      reviewerName: b.reviewerName,
      reviewerAvatarUrl: b.reviewerAvatarUrl,
      variantSku: b.variantSku,
      isVerifiedPurchase: b.isVerifiedPurchase,
      createdAt: b.createdAt,
      editedAt: b.editedAt,
      adminReply: b.adminReply,
      repliedAt: b.repliedAt,
      productName: json['productName'] as String? ?? '',
      productThumbnailUrl: json['productThumbnailUrl'] as String?,
    );
  }
}

class ReviewSummary {
  final double averageRating;
  final int totalCount;
  final int withImagesCount;

  /// key: 5,4,3,2,1
  final Map<int, int> ratingCounts;

  ReviewSummary({
    required this.averageRating,
    required this.totalCount,
    required this.withImagesCount,
    required this.ratingCounts,
  });

  int countFor(int star) => ratingCounts[star] ?? 0;
  double ratioFor(int star) => totalCount == 0 ? 0 : countFor(star) / totalCount;

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['ratingCounts'] as Map<String, dynamic>? ?? {};
    return ReviewSummary(
      averageRating: _toDouble(json['averageRating']),
      totalCount: _toInt(json['totalCount']),
      withImagesCount: _toInt(json['withImagesCount']),
      ratingCounts: raw.map((k, v) => MapEntry(int.tryParse(k) ?? 0, _toInt(v))),
    );
  }

  static ReviewSummary empty() =>
      ReviewSummary(averageRating: 0, totalCount: 0, withImagesCount: 0, ratingCounts: {});
}

class ProductReviewsPage {
  final ReviewSummary summary;
  final List<Review> items;
  final int page;
  final int totalPages;
  final int totalCount;

  ProductReviewsPage({
    required this.summary,
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalCount,
  });

  factory ProductReviewsPage.fromJson(Map<String, dynamic> json) {
    final reviews = json['reviews'] as Map<String, dynamic>? ?? {};
    return ProductReviewsPage(
      summary: ReviewSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
      items: (reviews['items'] as List<dynamic>? ?? [])
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: _toInt(reviews['page']),
      totalPages: _toInt(reviews['totalPages']),
      totalCount: _toInt(reviews['totalCount']),
    );
  }
}

class MyReviewStatus {
  final bool canReview;
  final String? reason;
  final Review? myReview;

  MyReviewStatus({required this.canReview, this.reason, this.myReview});

  factory MyReviewStatus.fromJson(Map<String, dynamic> json) => MyReviewStatus(
        canReview: json['canReview'] as bool? ?? false,
        reason: json['reason'] as String?,
        myReview: json['myReview'] is Map<String, dynamic>
            ? Review.fromJson(json['myReview'] as Map<String, dynamic>)
            : null,
      );
}

class PendingReviewItem {
  final String productId;
  final String productName;
  final String? thumbnailUrl;
  final String? variantSku;
  final String orderId;
  final DateTime purchasedAt;

  PendingReviewItem({
    required this.productId,
    required this.productName,
    this.thumbnailUrl,
    this.variantSku,
    required this.orderId,
    required this.purchasedAt,
  });

  factory PendingReviewItem.fromJson(Map<String, dynamic> json) => PendingReviewItem(
        productId: json['productId'] as String? ?? '',
        productName: json['productName'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String?,
        variantSku: json['variantSku'] as String?,
        orderId: json['orderId'] as String? ?? '',
        purchasedAt: _parseDate(json['purchasedAt']),
      );
}

class PagedAdminReviews {
  final List<AdminReview> items;
  final int page;
  final int totalPages;
  final int totalCount;

  PagedAdminReviews({required this.items, required this.page, required this.totalPages, required this.totalCount});

  factory PagedAdminReviews.fromJson(Map<String, dynamic> json) => PagedAdminReviews(
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => AdminReview.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: _toInt(json['page']),
        totalPages: _toInt(json['totalPages']),
        totalCount: _toInt(json['totalCount']),
      );
}
