import '../utils/formatters.dart';

double _toDouble(dynamic value) => (value as num?)?.toDouble() ?? 0.0;
double? _toNullableDouble(dynamic value) => (value as num?)?.toDouble();
int _toInt(dynamic value) => (value as num?)?.toInt() ?? 0;

DateTime _parseDate(dynamic value) {
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {}
  }
  return DateTime.now();
}

DateTime? _parseNullableDate(dynamic value) {
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {}
  }
  return null;
}

String _two(int n) => n.toString().padLeft(2, '0');
String formatVoucherDate(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

/// Thông tin chung để hiển thị nội dung giảm giá của một voucher
mixin VoucherDisplay {
  String get code;
  String get discountType; // 'percent' | 'fixed'
  double get discountValue;
  double? get maxDiscount;
  double get minOrderValue;
  DateTime get endsAt;

  bool get isPercent => discountType.toLowerCase() == 'percent';

  /// VD: "Giảm 10%" hoặc "Giảm 50K"
  String get discountTitle {
    if (isPercent) {
      final v = discountValue % 1 == 0 ? discountValue.toInt().toString() : discountValue.toString();
      return 'Giảm $v%';
    }
    return 'Giảm ${formatShortVnd(discountValue)}';
  }

  /// VD: "Đơn tối thiểu 500K · Giảm tối đa 200K"
  String get conditionText {
    final parts = <String>[];
    parts.add(minOrderValue > 0 ? 'Đơn tối thiểu ${formatShortVnd(minOrderValue)}' : 'Mọi đơn hàng');
    if (isPercent && maxDiscount != null && maxDiscount! > 0) {
      parts.add('Giảm tối đa ${formatShortVnd(maxDiscount!)}');
    }
    return parts.join(' · ');
  }

  String get expiryText => 'HSD: ${formatVoucherDate(endsAt)}';
}

/// "1500000" → "1,5Tr", "50000" → "50K"
String formatShortVnd(double amount) {
  if (amount >= 1000000) {
    final m = amount / 1000000;
    final s = m % 1 == 0 ? m.toInt().toString() : m.toStringAsFixed(1).replaceAll('.', ',');
    return '${s}Tr';
  }
  if (amount >= 1000) {
    final k = amount / 1000;
    final s = k % 1 == 0 ? k.toInt().toString() : k.toStringAsFixed(1).replaceAll('.', ',');
    return '${s}K';
  }
  return formatVnd(amount);
}

/// Voucher trong "Kho voucher" (GET /api/vouchers)
class PublicVoucher with VoucherDisplay {
  final String id;
  @override
  final String code;
  final String name;
  final String? description;
  @override
  final String discountType;
  @override
  final double discountValue;
  @override
  final double? maxDiscount;
  @override
  final double minOrderValue;
  final int totalQuantity;
  final int remainingQuantity;
  final DateTime startsAt;
  @override
  final DateTime endsAt;
  final bool isClaimed;

  PublicVoucher({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscount,
    required this.minOrderValue,
    required this.totalQuantity,
    required this.remainingQuantity,
    required this.startsAt,
    required this.endsAt,
    required this.isClaimed,
  });

  bool get isSoldOut => remainingQuantity <= 0;
  bool get isUpcoming => DateTime.now().isBefore(startsAt);

  /// Tỉ lệ đã được lưu (0..1) để vẽ thanh tiến độ
  double get claimedRatio =>
      totalQuantity <= 0 ? 1 : ((totalQuantity - remainingQuantity) / totalQuantity).clamp(0, 1).toDouble();

  PublicVoucher copyWith({bool? isClaimed, int? remainingQuantity}) => PublicVoucher(
        id: id,
        code: code,
        name: name,
        description: description,
        discountType: discountType,
        discountValue: discountValue,
        maxDiscount: maxDiscount,
        minOrderValue: minOrderValue,
        totalQuantity: totalQuantity,
        remainingQuantity: remainingQuantity ?? this.remainingQuantity,
        startsAt: startsAt,
        endsAt: endsAt,
        isClaimed: isClaimed ?? this.isClaimed,
      );

  factory PublicVoucher.fromJson(Map<String, dynamic> json) => PublicVoucher(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        discountType: json['discountType'] as String? ?? 'fixed',
        discountValue: _toDouble(json['discountValue']),
        maxDiscount: _toNullableDouble(json['maxDiscount']),
        minOrderValue: _toDouble(json['minOrderValue']),
        totalQuantity: _toInt(json['totalQuantity']),
        remainingQuantity: _toInt(json['remainingQuantity']),
        startsAt: _parseDate(json['startsAt']),
        endsAt: _parseDate(json['endsAt']),
        isClaimed: json['isClaimed'] as bool? ?? false,
      );
}

/// Voucher trong ví của khách (GET /api/vouchers/my)
class MyVoucher with VoucherDisplay {
  final String userVoucherId;
  final String voucherId;
  @override
  final String code;
  final String name;
  final String? description;
  @override
  final String discountType;
  @override
  final double discountValue;
  @override
  final double? maxDiscount;
  @override
  final double minOrderValue;
  final DateTime startsAt;
  @override
  final DateTime endsAt;

  /// 'available' | 'used' | 'expired' | 'upcoming' | 'disabled'
  final String status;
  final DateTime claimedAt;
  final DateTime? usedAt;
  final String? orderId;
  final double? usedDiscountAmount;

  // Chỉ có khi gọi API kèm ?subtotal=
  final bool? isApplicable;
  final double? estimatedDiscount;
  final String? ineligibleReason;

  MyVoucher({
    required this.userVoucherId,
    required this.voucherId,
    required this.code,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscount,
    required this.minOrderValue,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.claimedAt,
    this.usedAt,
    this.orderId,
    this.usedDiscountAmount,
    this.isApplicable,
    this.estimatedDiscount,
    this.ineligibleReason,
  });

  bool get isAvailable => status == 'available';
  bool get isUsed => status == 'used';

  /// Hết hạn hoặc bị tắt → xếp vào tab "Hết hạn"
  bool get isInactive => status == 'expired' || status == 'disabled';

  String get statusLabel {
    switch (status) {
      case 'available':
        return 'Có thể dùng';
      case 'used':
        return 'Đã dùng';
      case 'expired':
        return 'Hết hạn';
      case 'upcoming':
        return 'Sắp diễn ra';
      case 'disabled':
        return 'Ngừng áp dụng';
      default:
        return status;
    }
  }

  factory MyVoucher.fromJson(Map<String, dynamic> json) => MyVoucher(
        userVoucherId: json['userVoucherId'] as String? ?? '',
        voucherId: json['voucherId'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        discountType: json['discountType'] as String? ?? 'fixed',
        discountValue: _toDouble(json['discountValue']),
        maxDiscount: _toNullableDouble(json['maxDiscount']),
        minOrderValue: _toDouble(json['minOrderValue']),
        startsAt: _parseDate(json['startsAt']),
        endsAt: _parseDate(json['endsAt']),
        status: json['status'] as String? ?? 'available',
        claimedAt: _parseDate(json['claimedAt']),
        usedAt: _parseNullableDate(json['usedAt']),
        orderId: json['orderId'] as String?,
        usedDiscountAmount: _toNullableDouble(json['usedDiscountAmount']),
        isApplicable: json['isApplicable'] as bool?,
        estimatedDiscount: _toNullableDouble(json['estimatedDiscount']),
        ineligibleReason: json['ineligibleReason'] as String?,
      );
}

/// Voucher dành cho Admin (GET /api/admin/vouchers)
class AdminVoucher with VoucherDisplay {
  final String id;
  @override
  final String code;
  final String name;
  final String? description;
  @override
  final String discountType;
  @override
  final double discountValue;
  @override
  final double? maxDiscount;
  @override
  final double minOrderValue;
  final int totalQuantity;
  final int claimedCount;
  final int usedCount;
  final int remainingQuantity;
  final DateTime startsAt;
  @override
  final DateTime endsAt;
  final bool isActive;
  final bool isPublic;

  /// 'running' | 'upcoming' | 'expired' | 'disabled'
  final String displayStatus;
  final bool isLocked;

  AdminVoucher({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscount,
    required this.minOrderValue,
    required this.totalQuantity,
    required this.claimedCount,
    required this.usedCount,
    required this.remainingQuantity,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
    required this.isPublic,
    required this.displayStatus,
    required this.isLocked,
  });

  String get displayStatusLabel {
    switch (displayStatus) {
      case 'running':
        return 'Đang chạy';
      case 'upcoming':
        return 'Sắp diễn ra';
      case 'expired':
        return 'Đã hết hạn';
      case 'disabled':
        return 'Đã tắt';
      default:
        return displayStatus;
    }
  }

  factory AdminVoucher.fromJson(Map<String, dynamic> json) => AdminVoucher(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        discountType: json['discountType'] as String? ?? 'fixed',
        discountValue: _toDouble(json['discountValue']),
        maxDiscount: _toNullableDouble(json['maxDiscount']),
        minOrderValue: _toDouble(json['minOrderValue']),
        totalQuantity: _toInt(json['totalQuantity']),
        claimedCount: _toInt(json['claimedCount']),
        usedCount: _toInt(json['usedCount']),
        remainingQuantity: _toInt(json['remainingQuantity']),
        startsAt: _parseDate(json['startsAt']),
        endsAt: _parseDate(json['endsAt']),
        isActive: json['isActive'] as bool? ?? false,
        isPublic: json['isPublic'] as bool? ?? true,
        displayStatus: json['displayStatus'] as String? ?? 'running',
        isLocked: json['isLocked'] as bool? ?? false,
      );
}

/// Dữ liệu form tạo / sửa voucher (Admin)
class VoucherFormData {
  final String code;
  final String name;
  final String? description;
  final String discountType;
  final double discountValue;
  final double? maxDiscount;
  final double minOrderValue;
  final int totalQuantity;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;
  final bool isPublic;

  VoucherFormData({
    required this.code,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscount,
    required this.minOrderValue,
    required this.totalQuantity,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
    required this.isPublic,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'description': description,
        'discountType': discountType,
        'discountValue': discountValue,
        'maxDiscount': discountType == 'percent' ? maxDiscount : null,
        'minOrderValue': minOrderValue,
        'totalQuantity': totalQuantity,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'isActive': isActive,
        'isPublic': isPublic,
      };
}

class PagedVouchers {
  final List<AdminVoucher> items;
  final int page;
  final int totalPages;
  final int totalCount;

  PagedVouchers({required this.items, required this.page, required this.totalPages, required this.totalCount});

  factory PagedVouchers.fromJson(Map<String, dynamic> json) => PagedVouchers(
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => AdminVoucher.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: _toInt(json['page']),
        totalPages: _toInt(json['totalPages']),
        totalCount: _toInt(json['totalCount']),
      );
}
