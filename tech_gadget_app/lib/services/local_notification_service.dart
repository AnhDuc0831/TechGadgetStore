import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Hiển thị thông báo hệ thống (thanh trạng thái Android / iOS) cho thông báo mới từ server.
///
/// Lưu ý: app lấy thông báo bằng cách hỏi server định kỳ (polling) nên chỉ hiện được khi app
/// đang mở hoặc chạy nền. Muốn nhận cả khi app đã tắt hẳn cần tích hợp Firebase Cloud Messaging.
class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Gọi khi người dùng chạm vào thông báo. Payload = "orderId" (có thể rỗng).
  static void Function(String? payload)? onTap;

  static const _channel = AndroidNotificationDetails(
    'orders_channel',
    'Đơn hàng',
    channelDescription: 'Thông báo đơn hàng mới và cập nhật trạng thái đơn hàng',
    importance: Importance.high,
    priority: Priority.high,
  );

  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) => onTap?.call(response.payload),
      );

      // Android 13+ cần xin quyền hiển thị thông báo lúc chạy
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _ready = true;
    } catch (e) {
      debugPrint('Không khởi tạo được thông báo hệ thống: $e');
    }
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Không hiển thị được thông báo: $e');
    }
  }
}
