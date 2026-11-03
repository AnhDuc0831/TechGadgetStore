import 'dart:convert';
import 'package:flutter/material.dart';

double _toDouble(dynamic value) => (value as num?)?.toDouble() ?? 0.0;
int? _toInt(dynamic value) => (value as num?)?.toInt();

/// Trạng thái đơn hàng (khớp với CanonicalOrderStatus bên .NET backend)
enum OrderStatusEnum {
  pending,
  confirmed,
  shipping,
  completed,
  cancelled,
  unknown;

  static OrderStatusEnum fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'pending':
        return OrderStatusEnum.pending;
      case 'confirmed':
        return OrderStatusEnum.confirmed;
      case 'shipping':
        return OrderStatusEnum.shipping;
      case 'completed':
        return OrderStatusEnum.completed;
      case 'cancelled':
        return OrderStatusEnum.cancelled;
      default:
        return OrderStatusEnum.unknown;
    }
  }

  String get labelVi {
    switch (this) {
      case OrderStatusEnum.pending:
        return 'Chờ xử lý';
      case OrderStatusEnum.confirmed:
        return 'Đã xác nhận';
      case OrderStatusEnum.shipping:
        return 'Đang giao hàng';
      case OrderStatusEnum.completed:
        return 'Đã hoàn thành';
      case OrderStatusEnum.cancelled:
        return 'Đã hủy';
      case OrderStatusEnum.unknown:
        return 'Không xác định';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatusEnum.pending:
        return Colors.orange;
      case OrderStatusEnum.confirmed:
        return Colors.blue;
      case OrderStatusEnum.shipping:
        return Colors.purple;
      case OrderStatusEnum.completed:
        return Colors.green;
      case OrderStatusEnum.cancelled:
        return Colors.red;
      case OrderStatusEnum.unknown:
        return Colors.grey;
    }
  }

  /// Trạng thái tiếp theo hợp lệ cho Admin
  List<OrderStatusEnum> get allowedNextStatuses {
    switch (this) {
      case OrderStatusEnum.pending:
        return [OrderStatusEnum.confirmed, OrderStatusEnum.cancelled];
      case OrderStatusEnum.confirmed:
        return [OrderStatusEnum.shipping, OrderStatusEnum.cancelled];
      case OrderStatusEnum.shipping:
        return [OrderStatusEnum.completed];
      case OrderStatusEnum.completed:
      case OrderStatusEnum.cancelled:
      case OrderStatusEnum.unknown:
        return [];
    }
  }

  String get backendString {
    switch (this) {
      case OrderStatusEnum.pending:
        return 'Pending';
      case OrderStatusEnum.confirmed:
        return 'Confirmed';
      case OrderStatusEnum.shipping:
        return 'Shipping';
      case OrderStatusEnum.completed:
        return 'Completed';
      case OrderStatusEnum.cancelled:
        return 'Cancelled';
      case OrderStatusEnum.unknown:
        return 'Pending';
    }
  }
}

/// Trạng thái thanh toán (khớp với CanonicalPaymentStatus bên .NET backend)
enum PaymentStatusEnum {
  pending,
  paid,
  failed,
  cancelled,
  expired,
  refunded,
  unknown;

  static PaymentStatusEnum fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'pending':
        return PaymentStatusEnum.pending;
      case 'paid':
        return PaymentStatusEnum.paid;
      case 'failed':
        return PaymentStatusEnum.failed;
      case 'cancelled':
        return PaymentStatusEnum.cancelled;
      case 'expired':
        return PaymentStatusEnum.expired;
      case 'refunded':
        return PaymentStatusEnum.refunded;
      default:
        return PaymentStatusEnum.unknown;
    }
  }

  String get labelVi {
    switch (this) {
      case PaymentStatusEnum.pending:
        return 'Chờ thanh toán';
      case PaymentStatusEnum.paid:
        return 'Đã thanh toán';
      case PaymentStatusEnum.failed:
        return 'Thanh toán thất bại';
      case PaymentStatusEnum.cancelled:
        return 'Đã hủy thanh toán';
      case PaymentStatusEnum.expired:
        return 'Hết hạn';
      case PaymentStatusEnum.refunded:
        return 'Đã hoàn tiền';
      case PaymentStatusEnum.unknown:
        return 'Không xác định';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatusEnum.pending:
        return Colors.orange;
      case PaymentStatusEnum.paid:
        return Colors.green;
      case PaymentStatusEnum.failed:
        return Colors.red;
      case PaymentStatusEnum.cancelled:
        return Colors.grey;
      case PaymentStatusEnum.expired:
        return Colors.deepOrange;
      case PaymentStatusEnum.refunded:
        return Colors.blueGrey;
      case PaymentStatusEnum.unknown:
        return Colors.grey;
    }
  }
}

/// Chi tiết một sản phẩm trong đơn hàng
class OrderItemModel {
  final String id;
  final String productVariantId;
  final String productName;
  final String sku;
  final double unitPrice;
  final int quantity;
  final double totalPrice;

  OrderItemModel({
    required this.id,
    required this.productVariantId,
    required this.productName,
    required this.sku,
    required this.unitPrice,
    required this.quantity,
    required this.totalPrice,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final unitPrice = _toDouble(json['unitPrice']);
    final quantity = json['quantity'] as int? ?? 1;
    final totalPrice = json['totalPrice'] != null
        ? _toDouble(json['totalPrice'])
        : (unitPrice * quantity);

    return OrderItemModel(
      id: json['id'] as String? ?? '',
      productVariantId: json['productVariantId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      unitPrice: unitPrice,
      quantity: quantity,
      totalPrice: totalPrice,
    );
  }
}

/// Đơn hàng dành cho khách hàng (Customer OrderDto)
/// Tuyệt đối KHÔNG có internalNote, needsReview, hay costPrice
class OrderModel {
  final String id;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double totalAmount;
  final double shippingFee;
  final String? shippingName;
  final String? shippingPhone;
  final String shippingAddress;
  final String? note;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? checkoutUrl;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.totalAmount,
    required this.shippingFee,
    this.shippingName,
    this.shippingPhone,
    required this.shippingAddress,
    this.note,
    required this.createdAt,
    this.paidAt,
    this.checkoutUrl,
    required this.items,
  });

  OrderStatusEnum get statusEnum => OrderStatusEnum.fromString(status);
  PaymentStatusEnum get paymentStatusEnum =>
      PaymentStatusEnum.fromString(paymentStatus);

  String get statusLabel =>
      statusEnum == OrderStatusEnum.unknown ? status : statusEnum.labelVi;
  Color get statusColor => statusEnum.color;

  String get paymentStatusLabel =>
      paymentStatusEnum == PaymentStatusEnum.unknown
          ? paymentStatus
          : paymentStatusEnum.labelVi;
  Color get paymentStatusColor => paymentStatusEnum.color;

  String get paymentMethodLabel {
    final lower = paymentMethod.toLowerCase();
    if (lower == 'payos') return 'Chuyển khoản QR (payOS)';
    if (lower == 'cod') return 'Thanh toán khi nhận hàng (COD)';
    return paymentMethod;
  }

  bool get isPayOS => paymentMethod.toLowerCase() == 'payos';
  bool get isCod => paymentMethod.toLowerCase() == 'cod';

  /// Khách hàng chỉ có thể hủy đơn khi order status là Pending VÀ paymentStatus là Pending
  bool get canCancel =>
      statusEnum == OrderStatusEnum.pending &&
      paymentStatusEnum == PaymentStatusEnum.pending;

  /// Khách hàng có thể xác nhận đã nhận hàng khi trạng thái là Đang giao hàng (Shipping)
  bool get canConfirmReceived => statusEnum == OrderStatusEnum.shipping;

  /// Đơn PayOS chưa thanh toán có thể thanh toán lại nếu có checkoutUrl
  bool get canReopenPayment =>
      isPayOS &&
      paymentStatusEnum == PaymentStatusEnum.pending &&
      statusEnum != OrderStatusEnum.cancelled &&
      checkoutUrl != null &&
      checkoutUrl!.isNotEmpty;

  /// Địa chỉ giao hàng được định dạng tự nhiên, loại bỏ chuỗi JSON nếu có
  String get formattedShippingAddress {
    final parsed = ShippingAddressHelper.parse(shippingAddress);
    if (parsed.address.isNotEmpty) {
      return parsed.address;
    }
    final trimmed = shippingAddress.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return 'Chưa cập nhật địa chỉ';
    }
    return shippingAddress.isEmpty ? 'Chưa cập nhật địa chỉ' : shippingAddress;
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is String) {
        try {
          return DateTime.parse(val).toLocal();
        } catch (_) {}
      }
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        try {
          return DateTime.parse(val).toLocal();
        } catch (_) {}
      }
      return null;
    }

    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    String? shippingName = json['shippingName'] as String? ??
        json['shipping_name'] as String? ??
        json['recipientName'] as String? ??
        json['recipient_name'] as String? ??
        json['receiverName'] as String? ??
        json['customerName'] as String?;

    String? shippingPhone = json['shippingPhone'] as String? ??
        json['shipping_phone'] as String? ??
        json['recipientPhone'] as String? ??
        json['phone'] as String? ??
        json['phoneNumber'] as String?;

    final parsedShipping = ShippingAddressHelper.parse(
      json['shippingAddress'] ?? json['shipping_address'],
      defaultName: shippingName,
      defaultPhone: shippingPhone,
    );

    shippingName = parsedShipping.name;
    shippingPhone = parsedShipping.phone;
    final shippingAddress = parsedShipping.address;

    return OrderModel(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'Pending',
      paymentMethod: json['paymentMethod'] as String? ?? 'Cod',
      paymentStatus: json['paymentStatus'] as String? ?? 'Pending',
      totalAmount: _toDouble(json['totalAmount']),
      shippingFee: _toDouble(json['shippingFee']),
      shippingName: shippingName,
      shippingPhone: shippingPhone,
      shippingAddress: shippingAddress,
      note: json['note'] as String?,
      createdAt: parseDate(json['createdAt']),
      paidAt: parseNullableDate(json['paidAt']),
      checkoutUrl: json['checkoutUrl'] as String?,
      items: items,
    );
  }
}

/// Đơn hàng dành riêng cho Quản trị viên (AdminOrderDto)
/// Bổ sung internalNote, needsReview, userId, payosOrderCode, paymentLinkId
class AdminOrderModel extends OrderModel {
  final String? userId;
  final int? payosOrderCode;
  final String? paymentLinkId;
  final String? internalNote;
  final bool needsReview;

  AdminOrderModel({
    required super.id,
    required super.status,
    required super.paymentMethod,
    required super.paymentStatus,
    required super.totalAmount,
    required super.shippingFee,
    super.shippingName,
    super.shippingPhone,
    required super.shippingAddress,
    super.note,
    required super.createdAt,
    super.paidAt,
    super.checkoutUrl,
    required super.items,
    this.userId,
    this.payosOrderCode,
    this.paymentLinkId,
    this.internalNote,
    this.needsReview = false,
  });

  factory AdminOrderModel.fromJson(Map<String, dynamic> json) {
    final base = OrderModel.fromJson(json);

    return AdminOrderModel(
      id: base.id,
      status: base.status,
      paymentMethod: base.paymentMethod,
      paymentStatus: base.paymentStatus,
      totalAmount: base.totalAmount,
      shippingFee: base.shippingFee,
      shippingName: base.shippingName,
      shippingPhone: base.shippingPhone,
      shippingAddress: base.shippingAddress,
      note: base.note,
      createdAt: base.createdAt,
      paidAt: base.paidAt,
      checkoutUrl: base.checkoutUrl,
      items: base.items,
      userId: json['userId'] as String?,
      payosOrderCode: _toInt(json['payOSOrderCode'] ?? json['payosOrderCode']),
      paymentLinkId: json['paymentLinkId'] as String?,
      internalNote: json['internalNote'] as String?,
      needsReview: json['needsReview'] as bool? ?? false,
    );
  }
}

/// Request gửi lên POST /api/orders/checkout
class CheckoutRequest {
  final String shippingName;
  final String shippingPhone;
  final String shippingAddress;
  final String? note;
  final String paymentMethod; // "Cod" | "PayOS"
  final List<String> selectedCartItemIds;

  CheckoutRequest({
    required this.shippingName,
    required this.shippingPhone,
    required this.shippingAddress,
    this.note,
    required this.paymentMethod,
    required this.selectedCartItemIds,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'shippingName': shippingName,
      'shippingPhone': shippingPhone,
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      'selectedCartItemIds': selectedCartItemIds,
    };
    if (note != null && note!.trim().isNotEmpty) {
      map['note'] = note!.trim();
    }
    return map;
  }
}

/// Kết quả trả về từ POST /api/orders/checkout
class CheckoutResult {
  final String orderId;
  final int? orderCode;
  final double totalAmount;
  final double shippingFee;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;
  final String? checkoutUrl;
  final String? qrCode;
  final String? paymentLinkId;
  final OrderModel? order;

  CheckoutResult({
    required this.orderId,
    this.orderCode,
    required this.totalAmount,
    required this.shippingFee,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    this.checkoutUrl,
    this.qrCode,
    this.paymentLinkId,
    this.order,
  });

  bool get isPayOS => paymentMethod.toLowerCase() == 'payos';

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    OrderModel? parsedOrder;
    if (json['order'] is Map<String, dynamic>) {
      parsedOrder = OrderModel.fromJson(json['order'] as Map<String, dynamic>);
    }

    return CheckoutResult(
      orderId: json['orderId'] as String? ?? parsedOrder?.id ?? '',
      orderCode: _toInt(json['orderCode']),
      totalAmount: _toDouble(json['totalAmount']),
      shippingFee: _toDouble(json['shippingFee']),
      paymentMethod: json['paymentMethod'] as String? ?? 'Cod',
      paymentStatus: json['paymentStatus'] as String? ?? 'Pending',
      orderStatus: json['orderStatus'] as String? ?? 'Pending',
      checkoutUrl: json['checkoutUrl'] as String?,
      qrCode: json['qrCode'] as String?,
      paymentLinkId: json['paymentLinkId'] as String?,
      order: parsedOrder,
    );
  }
}

/// Kết quả trả về từ GET /api/orders/{id}/payment-status
class PaymentStatusResult {
  final String orderId;
  final int? orderCode;
  final String paymentStatus;
  final String orderStatus;
  final double totalAmount;
  final DateTime? paidAt;
  final String? payOSStatus;
  final String? checkoutUrl;

  PaymentStatusResult({
    required this.orderId,
    this.orderCode,
    required this.paymentStatus,
    required this.orderStatus,
    required this.totalAmount,
    this.paidAt,
    this.payOSStatus,
    this.checkoutUrl,
  });

  PaymentStatusEnum get paymentStatusEnum =>
      PaymentStatusEnum.fromString(paymentStatus);
  OrderStatusEnum get orderStatusEnum =>
      OrderStatusEnum.fromString(orderStatus);

  bool get isPaid => paymentStatusEnum == PaymentStatusEnum.paid;
  bool get isPending => paymentStatusEnum == PaymentStatusEnum.pending;
  bool get isCancelledOrFailed =>
      paymentStatusEnum == PaymentStatusEnum.cancelled ||
      paymentStatusEnum == PaymentStatusEnum.failed ||
      paymentStatusEnum == PaymentStatusEnum.expired;

  factory PaymentStatusResult.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        try {
          return DateTime.parse(val).toLocal();
        } catch (_) {}
      }
      return null;
    }

    return PaymentStatusResult(
      orderId: json['orderId'] as String? ?? '',
      orderCode: _toInt(json['orderCode']),
      paymentStatus: json['paymentStatus'] as String? ?? 'Pending',
      orderStatus: json['orderStatus'] as String? ?? 'Pending',
      totalAmount: _toDouble(json['totalAmount']),
      paidAt: parseDate(json['paidAt']),
      payOSStatus: json['payOSStatus'] as String?,
      checkoutUrl: json['checkoutUrl'] as String?,
    );
  }
}

/// Kết quả phân trang danh sách đơn hàng Admin (GET /api/admin/orders)
class PagedOrders {
  final List<AdminOrderModel> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  PagedOrders({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;

  factory PagedOrders.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => AdminOrderModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return PagedOrders(
      items: items,
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 10,
      totalCount: json['totalCount'] as int? ?? items.length,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }
}

/// Helper định dạng và trích xuất thông tin địa chỉ nhận hàng tự nhiên
class ShippingAddressHelper {
  static ParsedShippingInfo parse(dynamic raw, {String? defaultName, String? defaultPhone}) {
    String? name = defaultName;
    String? phone = defaultPhone;
    String address = '';

    if (raw == null) {
      return ParsedShippingInfo(name: name, phone: phone, address: address);
    }

    dynamic current = raw;

    // Giải mã nếu dữ liệu là chuỗi JSON hoặc chuỗi bị escape
    if (current is String) {
      final trimmed = current.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']')) ||
          (trimmed.startsWith('"') && trimmed.endsWith('"'))) {
        try {
          current = jsonDecode(trimmed);
          if (current is String) {
            final secondTrimmed = current.trim();
            if (secondTrimmed.startsWith('{') && secondTrimmed.endsWith('}')) {
              current = jsonDecode(secondTrimmed);
            }
          }
        } catch (_) {}
      }
    }

    if (current is Map) {
      // 1. Tên người nhận
      name ??= _extractString(current, [
        'recipient_name',
        'recipientName',
        'receiver_name',
        'receiverName',
        'name',
        'full_name',
        'fullName',
        'customer_name',
        'customerName',
        'shipping_name',
        'shippingName',
      ]);

      // 2. Số điện thoại
      phone ??= _extractString(current, [
        'phone',
        'phoneNumber',
        'phone_number',
        'sdt',
        'mobile',
        'telephone',
        'recipient_phone',
        'recipientPhone',
        'shipping_phone',
        'shippingPhone',
      ]);

      // 3. Địa chỉ
      address = _formatAddressFromMap(current);
    } else if (current is String) {
      address = current.trim();
    } else {
      address = current.toString();
    }

    // Nếu address vẫn còn dạng JSON (do lồng nhau), giải mã lần nữa
    if (address.trim().startsWith('{') && address.trim().endsWith('}')) {
      try {
        final nested = jsonDecode(address.trim());
        if (nested is Map) {
          final formatted = _formatAddressFromMap(nested);
          if (formatted.isNotEmpty) address = formatted;
        }
      } catch (_) {}
    }

    return ParsedShippingInfo(
      name: name?.trim().isEmpty == true ? null : name?.trim(),
      phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      address: address.trim(),
    );
  }

  static String? _extractString(Map map, List<String> candidateKeys) {
    for (final key in candidateKeys) {
      if (map.containsKey(key) && map[key] != null) {
        final val = map[key].toString().trim();
        if (val.isNotEmpty) return val;
      }
    }
    return null;
  }

  static String _formatAddressFromMap(Map map) {
    // Kiểm tra nếu có trường address trực tiếp
    final directVal = map['address'] ??
        map['shipping_address'] ??
        map['shippingAddress'] ??
        map['full_address'] ??
        map['fullAddress'] ??
        map['dia_chi'];

    if (directVal is Map) {
      return _formatAddressFromMap(directVal);
    }

    String? street = directVal?.toString().trim();
    if (street == null || street.isEmpty || (street.startsWith('{') && street.endsWith('}'))) {
      street = _extractString(map, [
        'street',
        'street_address',
        'streetAddress',
        'address_line_1',
        'address_line1',
        'addressLine1',
        'line1',
        'detail',
        'detail_address',
        'detailAddress',
        'so_nha',
        'house_number',
      ]);
    }

    final ward = _extractString(map, ['ward', 'phuong', 'xa', 'sub_district', 'subDistrict']);
    final district = _extractString(map, ['district', 'quan', 'huyen']);
    final city = _extractString(map, ['city', 'province', 'tinh', 'thanh_pho', 'thanhPho', 'state']);
    final country = _extractString(map, ['country', 'quoc_gia']);

    final parts = <String>[];
    if (street != null && street.isNotEmpty && !street.startsWith('{')) parts.add(street);
    if (ward != null && ward.isNotEmpty && !parts.any((p) => p.contains(ward))) parts.add(ward);
    if (district != null && district.isNotEmpty && !parts.any((p) => p.contains(district))) parts.add(district);
    if (city != null && city.isNotEmpty && !parts.any((p) => p.contains(city))) parts.add(city);
    if (country != null && country.isNotEmpty && !parts.any((p) => p.contains(country))) parts.add(country);

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }

    // Dự phòng: gom các trường địa chỉ còn lại bỏ qua các khóa meta người nhận
    const metaKeys = {
      'recipient_name', 'recipientname', 'receiver_name', 'receivername', 'name', 'full_name', 'fullname',
      'customer_name', 'customername', 'shipping_name', 'shippingname',
      'phone', 'phonenumber', 'phone_number', 'sdt', 'mobile', 'telephone',
      'recipient_phone', 'recipientphone', 'shipping_phone', 'shippingphone',
      'id', 'status', 'email', 'note', 'created_at', 'updated_at'
    };

    final fallbackParts = <String>[];
    map.forEach((k, v) {
      final keyLower = k.toString().toLowerCase().replaceAll('_', '');
      if (!metaKeys.contains(keyLower) && v != null) {
        if (v is Map) {
          final nested = _formatAddressFromMap(v);
          if (nested.isNotEmpty) fallbackParts.add(nested);
        } else {
          final str = v.toString().trim();
          if (str.isNotEmpty && !str.startsWith('{')) {
            fallbackParts.add(str);
          }
        }
      }
    });

    if (fallbackParts.isNotEmpty) {
      return fallbackParts.join(', ');
    }

    return '';
  }
}

class ParsedShippingInfo {
  final String? name;
  final String? phone;
  final String address;

  ParsedShippingInfo({this.name, this.phone, required this.address});
}

