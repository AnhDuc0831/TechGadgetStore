import 'dart:convert';

double _toDouble(dynamic value) => (value as num?)?.toDouble() ?? 0;

/// Trạng thái của một CartItem (khớp với enum CartItemStatus bên .NET)
enum CartItemStatus {
  available,
  outOfStock,
  discontinued,
  variantNotFound;

  static CartItemStatus fromString(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'available':
        return CartItemStatus.available;
      case 'outofstock':
        return CartItemStatus.outOfStock;
      case 'discontinued':
        return CartItemStatus.discontinued;
      default:
        return CartItemStatus.variantNotFound;
    }
  }

  String get label {
    switch (this) {
      case CartItemStatus.available:
        return 'Còn hàng';
      case CartItemStatus.outOfStock:
        return 'Hết hàng';
      case CartItemStatus.discontinued:
        return 'Ngừng kinh doanh';
      case CartItemStatus.variantNotFound:
        return 'Phiên bản không còn tồn tại';
    }
  }
}

class CartItemModel {
  final String id;
  final String productId;
  final String productVariantId;
  final String productName;
  final String? thumbnailUrl;
  final String sku;

  /// Chuỗi JSON thuộc tính, vd: {"color":"Black","ram":"8GB"}
  final String? attributes;
  final double unitPrice;
  final int quantity;
  final int stockQuantity;
  final CartItemStatus status;

  CartItemModel({
    required this.id,
    required this.productId,
    required this.productVariantId,
    required this.productName,
    this.thumbnailUrl,
    required this.sku,
    this.attributes,
    required this.unitPrice,
    required this.quantity,
    required this.stockQuantity,
    required this.status,
  });

  bool get isAvailable => status == CartItemStatus.available;
  double get lineTotal => unitPrice * quantity;

  /// Parse chuỗi JSON attributes thành Map, vd: {"color":"Black","ram":"8GB"}
  Map<String, String> get attributeMap {
    if (attributes == null || attributes!.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(attributes!) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id'] as String,
      productId: json['productId'] as String,
      productVariantId: json['productVariantId'] as String,
      productName: json['productName'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      sku: json['sku'] as String? ?? '',
      attributes: json['attributes'] as String?,
      unitPrice: _toDouble(json['unitPrice']),
      quantity: json['quantity'] as int? ?? 1,
      stockQuantity: json['stockQuantity'] as int? ?? 0,
      status: CartItemStatus.fromString(json['status'] as String?),
    );
  }
}

class CartModel {
  final String? id;
  final List<CartItemModel> items;

  CartModel({this.id, required this.items});

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);
  double get totalAmount =>
      items.where((i) => i.isAvailable).fold(0, (sum, i) => sum + i.lineTotal);

  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      id: json['id'] as String?,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Giỏ hàng rỗng
  static CartModel empty() => CartModel(id: null, items: []);
}
