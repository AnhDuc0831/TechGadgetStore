import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tech_gadget_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Gõ chữ từ từ mô phỏng hành vi người dùng thật (Tham khảo module11)
  Future<void> enterTextSlowly(
    WidgetTester tester,
    Finder finder,
    String text, {
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    await tester.tap(finder);
    await tester.pump();

    String currentText = '';
    for (int i = 0; i < text.length; i++) {
      currentText += text[i];
      await tester.enterText(finder, currentText);
      await tester.pump();
      await Future.delayed(delay);
    }
  }

  group('End-to-End Integration Test (Tham khảo Module 11 integrationtest.dart)', () {
    testWidgets('Full app flow: Launch, search input, navigate to Profile & Login screens',
        (WidgetTester tester) async {
      // BƯỚC 1: Khởi chạy toàn bộ ứng dụng
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // BƯỚC 2: Kiểm tra màn hình chính (HomeScreen)
      final searchFieldFinder = find.byType(TextField).first;
      expect(searchFieldFinder, findsOneWidget);
      expect(find.text('Tư vấn AI'), findsOneWidget);

      // BƯỚC 3: Nhập từ khóa tìm kiếm chậm rãi mô phỏng người dùng
      await enterTextSlowly(tester, searchFieldFinder, 'MacBook');
      await tester.pumpAndSettle();

      final searchTextField = tester.widget<TextField>(searchFieldFinder);
      expect(searchTextField.controller?.text, 'MacBook');

      // BƯỚC 4: Điều hướng sang màn hình Tài khoản (ProfileScreen)
      final profileButton = find.byIcon(Icons.person_outline);
      expect(profileButton, findsOneWidget);
      await tester.tap(profileButton);
      await tester.pumpAndSettle();

      // Kiểm tra giao diện Profile khi chưa đăng nhập
      expect(find.text('Tài khoản'), findsOneWidget);
      expect(find.textContaining('Tech Gadget Store'), findsWidgets);
      final loginRegisterButton = find.text('Đăng nhập / Đăng ký');
      expect(loginRegisterButton, findsOneWidget);

      // BƯỚC 5: Điều hướng sang màn hình Đăng nhập (LoginScreen)
      await tester.tap(loginRegisterButton);
      await tester.pumpAndSettle();

      // Kiểm tra giao diện LoginScreen
      expect(find.text('Đăng nhập'), findsWidgets);
      expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
      expect(find.text('hoặc với email'), findsOneWidget);

      // BƯỚC 6: Quay lại màn hình Profile và màn hình chính
      final backButton = find.byIcon(Icons.arrow_back);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle();
      }

      // Quay lại HomeScreen nếu đang ở ProfileScreen
      final profileBackButton = find.byType(BackButton);
      if (profileBackButton.evaluate().isNotEmpty) {
        await tester.tap(profileBackButton);
        await tester.pumpAndSettle();
      }

      // Xác nhận đã trở về HomeScreen
      expect(find.text('Tư vấn AI'), findsOneWidget);
    });
  });
}
