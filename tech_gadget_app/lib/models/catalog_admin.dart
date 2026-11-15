int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Danh mục cho Admin (GET /api/admin/categories)
class AdminCategory {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final int productCount;

  AdminCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    required this.productCount,
  });

  bool get canDelete => productCount == 0;

  factory AdminCategory.fromJson(Map<String, dynamic> json) => AdminCategory(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        productCount: _toInt(json['productCount']),
      );
}

/// Thương hiệu cho Admin (GET /api/admin/brands)
class AdminBrand {
  final String id;
  final String name;
  final String? logoUrl;
  final int productCount;

  AdminBrand({required this.id, required this.name, this.logoUrl, required this.productCount});

  bool get canDelete => productCount == 0;

  factory AdminBrand.fromJson(Map<String, dynamic> json) => AdminBrand(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        logoUrl: json['logoUrl'] as String?,
        productCount: _toInt(json['productCount']),
      );
}
