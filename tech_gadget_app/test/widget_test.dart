import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tech_gadget_app/models/product.dart';
import 'package:tech_gadget_app/widgets/product_card.dart';
import 'package:tech_gadget_app/widgets/rating_stars.dart';
import 'package:tech_gadget_app/widgets/product_filter_sheet.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('Widget Tests – UI & Interaction (Tham khảo Module 11 Demo 11.2 & Demo 11.3)', () {
    testWidgets('RatingStars should display correct stars and review count', (WidgetTester tester) async {
      // STEP 1 – Arrange & Act: Render with 4.5 rating and 28 reviews
      await tester.pumpWidget(createTestApp(
        const RatingStars(rating: 4.5, reviewCount: 28),
      ));

      // STEP 3 – Assert
      expect(find.text('(28)'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(4));
      expect(find.byIcon(Icons.star_half), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNothing);

      // Arrange & Act with 0 reviews
      await tester.pumpWidget(createTestApp(
        const RatingStars(rating: 0.0, reviewCount: 0),
      ));

      // Assert
      expect(find.text('Chưa có đánh giá'), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    });

    testWidgets('ProductCard should render product details and trigger onTap', (WidgetTester tester) async {
      // STEP 1 – Arrange
      bool wasTapped = false;
      final product = ProductListItem(
        id: 'prod-001',
        name: 'iPhone 15 Pro Max 256GB',
        slug: 'iphone-15-pro-max-256gb',
        basePrice: 29990000.0,
        minPrice: 29990000.0,
        maxPrice: 29990000.0,
        inStock: true,
        totalStockQuantity: 15,
        isActive: true,
        category: Category(id: 'cat-phone', name: 'Điện thoại', slug: 'dien-thoai'),
        brand: Brand(id: 'brand-apple', name: 'Apple'),
        averageRating: 4.8,
        reviewCount: 99,
      );

      // STEP 2 – Act: Pump widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 340,
              child: ProductCard(
                product: product,
                onTap: () => wasTapped = true,
              ),
            ),
          ),
        ),
      );

      // STEP 3 – Assert UI components
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('iPhone 15 Pro Max 256GB'), findsOneWidget);
      expect(find.text('29.990.000 ₫'), findsOneWidget);
      expect(find.text('Còn hàng'), findsOneWidget);
      expect(find.text('(99)'), findsOneWidget);

      // Act: Tap card
      await tester.tap(find.byType(ProductCard));
      await tester.pump();

      // Assert callback invoked
      expect(wasTapped, isTrue);
    });

    testWidgets('ProductFilterSheet allows selecting price preset, resetting, and validates min > max', (WidgetTester tester) async {
      final brands = [
        Brand(id: 'b1', name: 'Apple'),
        Brand(id: 'b2', name: 'Samsung'),
      ];

      // STEP 1 – Arrange: Pump ProductFilterSheet inside MaterialApp
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductFilterSheet(
              brands: brands,
              initialFilter: const ProductFilter(),
            ),
          ),
        ),
      );

      expect(find.text('Khoảng giá (₫)'), findsOneWidget);
      expect(find.text('Thương hiệu'), findsOneWidget);

      // STEP 2 – Act: Tap preset chip '5 - 10 triệu'
      final presetChip = find.text('5 - 10 triệu');
      expect(presetChip, findsOneWidget);
      await tester.tap(presetChip);
      await tester.pump();

      // Assert preset values filled into text fields
      expect(find.text('5000000'), findsOneWidget);
      expect(find.text('10000000'), findsOneWidget);

      // Act: Tap 'Bỏ chọn tất cả' (Reset button)
      final resetButton = find.text('Bỏ chọn tất cả');
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      await tester.pump();

      // Assert text fields cleared
      expect(find.text('5000000'), findsNothing);
      expect(find.text('10000000'), findsNothing);

      // Act: Enter invalid price range where min > max
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.first, '20000000');
      await tester.enterText(textFields.last, '5000000');
      await tester.pump();

      // Tap 'Áp dụng' button
      final applyButton = find.text('Áp dụng');
      await tester.tap(applyButton);
      await tester.pump();

      // STEP 3 – Assert: Validation error message appears
      expect(find.text('Giá "Từ" không được lớn hơn giá "Đến".'), findsOneWidget);
    });
  });
}
