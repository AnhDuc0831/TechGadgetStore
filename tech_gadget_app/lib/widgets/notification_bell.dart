import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../screens/notifications_screen.dart';

/// Nút chuông thông báo kèm badge số chưa đọc. Ẩn khi chưa đăng nhập.
class NotificationBell extends StatelessWidget {
  final Color? color;

  const NotificationBell({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.select<AuthProvider, bool>((a) => a.isAuthenticated);
    if (!isLoggedIn) return const SizedBox.shrink();

    final count = context.select<NotificationProvider, int>((p) => p.unreadCount);

    return IconButton(
      tooltip: 'Thông báo',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: Icon(count > 0 ? Icons.notifications_active_outlined : Icons.notifications_none, color: color),
      ),
    );
  }
}
