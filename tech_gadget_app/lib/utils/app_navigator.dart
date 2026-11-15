import 'package:flutter/material.dart';

/// NavigatorKey toàn cục: cho phép mở màn hình từ nơi không có BuildContext
/// (VD: khi người dùng chạm vào thông báo trên thanh trạng thái).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
