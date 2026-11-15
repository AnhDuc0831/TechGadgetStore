import 'package:flutter/material.dart';

DateTime _parseDate(dynamic v) {
  if (v is String && v.isNotEmpty) {
    try {
      return DateTime.parse(v).toLocal();
    } catch (_) {}
  }
  return DateTime.now();
}

/// Thông báo trong app (khớp NotificationDto bên .NET)
class AppNotification {
  final String id;

  /// new_order | order_paid | order_status | order_cancelled | order_received
  final String type;
  final String title;
  final String message;
  final String? orderId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.orderId,
    required this.isRead,
    required this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        message: message,
        orderId: orderId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  IconData get icon {
    switch (type) {
      case 'new_order':
        return Icons.shopping_cart_checkout;
      case 'order_paid':
        return Icons.payments_outlined;
      case 'order_received':
        return Icons.inventory_2_outlined;
      case 'order_cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.local_shipping_outlined;
    }
  }

  Color get color {
    switch (type) {
      case 'new_order':
        return Colors.indigo;
      case 'order_paid':
        return Colors.green;
      case 'order_received':
        return Colors.teal;
      case 'order_cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  /// "Vừa xong", "5 phút trước", "2 giờ trước", "3 ngày trước", hoặc ngày cụ thể
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(createdAt.day)}/${two(createdAt.month)}/${createdAt.year}';
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'order_status',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        orderId: json['orderId'] as String?,
        isRead: json['isRead'] as bool? ?? false,
        createdAt: _parseDate(json['createdAt']),
      );
}

class UnreadInfo {
  final int unreadCount;
  final DateTime? latestAt;

  UnreadInfo({required this.unreadCount, this.latestAt});

  factory UnreadInfo.fromJson(Map<String, dynamic> json) => UnreadInfo(
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        latestAt: json['latestAt'] is String ? DateTime.tryParse(json['latestAt'] as String)?.toLocal() : null,
      );
}
