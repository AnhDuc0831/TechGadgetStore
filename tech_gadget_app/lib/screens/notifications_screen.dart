import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_notification.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import 'admin_order_detail_screen.dart';
import 'order_detail_screen.dart';

/// Mở màn hình chi tiết đơn tương ứng với thông báo (Admin → màn Admin, Khách → màn Khách).
void openOrderFromNotification(NavigatorState navigator, {required String? orderId, required bool isAdmin}) {
  if (orderId == null || orderId.isEmpty) return;
  navigator.push(
    MaterialPageRoute(
      builder: (_) => isAdmin ? AdminOrderDetailScreen(orderId: orderId) : OrderDetailScreen(orderId: orderId),
    ),
  );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NotificationProvider>().refresh());
  }

  void _open(AppNotification n) {
    final provider = context.read<NotificationProvider>();
    provider.markAsRead(n);
    openOrderFromNotification(Navigator.of(context),
        orderId: n.orderId, isAdmin: context.read<AuthProvider>().isAdmin);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final items = provider.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton.icon(
              onPressed: provider.markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Đọc tất cả'),
            ),
        ],
      ),
      body: provider.isLoading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(provider.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: provider.refresh, child: const Text('Thử lại')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: items.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Icon(Icons.notifications_none, size: 72, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('Chưa có thông báo nào.',
                                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (_, i) {
                            final n = items[i];
                            return Material(
                              color: n.isRead ? Colors.white : Colors.blue.shade50.withValues(alpha: 0.6),
                              child: ListTile(
                                onTap: () => _open(n),
                                leading: CircleAvatar(
                                  backgroundColor: n.color.withValues(alpha: 0.12),
                                  child: Icon(n.icon, color: n.color, size: 22),
                                ),
                                title: Text(
                                  n.title,
                                  style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(n.message, style: const TextStyle(fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(n.timeAgo, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                                trailing: n.isRead
                                    ? null
                                    : Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                      ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
