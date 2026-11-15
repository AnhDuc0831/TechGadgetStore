import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../services/local_notification_service.dart';
import '../services/notification_api_service.dart';

/// Quản lý thông báo trong app:
///  - Hỏi server định kỳ ([pollInterval]) số thông báo chưa đọc → hiện badge trên chuông.
///  - Khi phát hiện thông báo MỚI → bật thông báo hệ thống (thanh trạng thái).
///  - Lần hỏi đầu tiên sau khi đăng nhập chỉ ghi nhận mốc, không bắn lại thông báo cũ.
class NotificationProvider extends ChangeNotifier {
  static const pollInterval = Duration(seconds: 20);

  final NotificationApiService _api;

  NotificationProvider({NotificationApiService? api}) : _api = api ?? NotificationApiService();

  String? _userId;
  String? Function()? _tokenGetter;
  Timer? _timer;
  DateTime? _lastSeenLatest;
  bool _baselineSet = false;
  bool _polling = false;

  int _unreadCount = 0;
  List<AppNotification> _items = [];
  bool _loading = false;
  String? _error;

  int get unreadCount => _unreadCount;
  List<AppNotification> get items => _items;
  bool get isLoading => _loading;
  String? get error => _error;

  /// Gắn với người dùng hiện tại. Được gọi mỗi khi AuthProvider thay đổi.
  /// [tokenGetter] luôn trả về access token mới nhất (Supabase tự làm mới token).
  void bind({required String? userId, required String? Function() tokenGetter}) {
    _tokenGetter = tokenGetter;
    if (userId == _userId) return;

    _userId = userId;
    _timer?.cancel();
    _timer = null;
    _lastSeenLatest = null;
    _baselineSet = false;

    // Không notifyListeners trực tiếp vì bind có thể được gọi trong lúc build
    final boundUser = userId;
    scheduleMicrotask(() {
      if (boundUser != _userId) return; // đã đổi tài khoản trước khi microtask chạy
      _timer?.cancel();
      if (_userId == null) {
        _unreadCount = 0;
        _items = [];
        notifyListeners();
        return;
      }
      _poll();
      _timer = Timer.periodic(pollInterval, (_) => _poll());
    });
  }

  Future<void> _poll() async {
    final token = _tokenGetter?.call();
    if (token == null || _userId == null || _polling) return;
    _polling = true;
    try {
      final info = await _api.getUnreadInfo(token);
      final latest = info.latestAt;

      if (!_baselineSet) {
        _baselineSet = true;
        _lastSeenLatest = latest;
      } else if (latest != null && (_lastSeenLatest == null || latest.isAfter(_lastSeenLatest!))) {
        final since = _lastSeenLatest;
        _lastSeenLatest = latest;
        await _announceNew(token, since);
      }

      if (info.unreadCount != _unreadCount) {
        _unreadCount = info.unreadCount;
        notifyListeners();
      }
    } catch (_) {
      // Mất mạng / server chậm: bỏ qua, lần sau hỏi lại
    } finally {
      _polling = false;
    }
  }

  /// Bật thông báo hệ thống cho các thông báo mới hơn [since]
  Future<void> _announceNew(String token, DateTime? since) async {
    final fresh = await _api.getNotifications(token, pageSize: 10, unreadOnly: true);
    final newOnes = fresh.where((n) => since == null || n.createdAt.isAfter(since)).toList();
    if (newOnes.isEmpty) return;

    // Cập nhật danh sách đang hiển thị (nếu màn thông báo đang mở)
    if (_items.isNotEmpty) {
      final existing = _items.map((e) => e.id).toSet();
      _items = [...newOnes.where((n) => !existing.contains(n.id)), ..._items];
      notifyListeners();
    }

    if (newOnes.length <= 3) {
      for (final n in newOnes.reversed) {
        await LocalNotificationService.show(
          id: n.id.hashCode,
          title: n.title,
          body: n.message,
          payload: n.orderId,
        );
      }
    } else {
      await LocalNotificationService.show(
        id: 'summary'.hashCode,
        title: 'Bạn có ${newOnes.length} thông báo mới',
        body: newOnes.first.title,
      );
    }
  }

  /// Tải danh sách thông báo (màn hình Thông báo)
  Future<void> refresh() async {
    final token = _tokenGetter?.call();
    if (token == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _api.getNotifications(token, pageSize: 50);
      final info = await _api.getUnreadInfo(token);
      _unreadCount = info.unreadCount;
      _lastSeenLatest = info.latestAt ?? _lastSeenLatest;
      _baselineSet = true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(AppNotification n) async {
    if (n.isRead) return;
    final token = _tokenGetter?.call();
    if (token == null) return;

    // Cập nhật giao diện trước, gọi API sau
    _items = _items.map((x) => x.id == n.id ? x.copyWith(isRead: true) : x).toList();
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();
    try {
      await _api.markAsRead(token, n.id);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final token = _tokenGetter?.call();
    if (token == null || _unreadCount == 0) return;
    _items = _items.map((x) => x.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();
    try {
      await _api.markAllAsRead(token);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
