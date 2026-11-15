import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/order_provider.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/local_notification_service.dart';
import 'utils/app_navigator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Supabase client toàn cục
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Cảnh báo: Chưa cấu hình thông tin Supabase thực tế trong config/supabase_config.dart: $e');
  }

  // Thông báo hệ thống: chạm vào thông báo → mở chi tiết đơn hàng
  LocalNotificationService.onTap = (orderId) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    final isAdmin = navigator.context.read<AuthProvider>().isAdmin;
    openOrderFromNotification(navigator, orderId: orderId, isAdmin: isAdmin);
  };
  await LocalNotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        // Thông báo gắn theo người dùng đang đăng nhập: tự bắt đầu / dừng hỏi server khi đăng nhập / đăng xuất
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, notifications) => notifications!
            ..bind(userId: auth.currentUser?.id, tokenGetter: () => auth.accessToken),
        ),
      ],
      child: MaterialApp(
        title: 'Tech Gadget Store',
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.light,
          ),
        ),
        // Khách vẫn xem được sản phẩm; chỉ yêu cầu đăng nhập khi dùng tính năng cần tài khoản
        home: const HomeScreen(),
      ),
    );
  }
}
