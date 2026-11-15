import 'package:flutter_test/flutter_test.dart';
import 'package:tech_gadget_app/models/cart.dart';
import 'package:tech_gadget_app/utils/formatters.dart';

void main() {
  group('Cart Model & Formatters – Unit Test (Tham khảo Module 11 Demo 11.1 & Demo 11.2)', () {
    test('CartModel should calculate totalQuantity and totalAmount correctly', () {
      // STEP 1 – Arrange
      final item1 = CartItemModel(
        id: 'c1',
        productId: 'p1',
        productVariantId: 'v1',
        productName: 'iPhone 15 Pro Max',
        sku: 'IP15PM-256',
        unitPrice: 25000000.0,
        quantity: 2,
        stockQuantity: 10,
        status: CartItemStatus.available,
      );

      final item2 = CartItemModel(
        id: 'c2',
        productId: 'p2',
        productVariantId: 'v2',
        productName: 'Củ sạc nhanh 30W',
        sku: 'CHARGER-30W',
        unitPrice: 500000.0,
        quantity: 1,
        stockQuantity: 20,
        status: CartItemStatus.available,
      );

      final outOfStockItem = CartItemModel(
        id: 'c3',
        productId: 'p3',
        productVariantId: 'v3',
        productName: 'Bàn phím cơ Bluetooth',
        sku: 'KB-BT-01',
        unitPrice: 1500000.0,
        quantity: 1,
        stockQuantity: 0,
        status: CartItemStatus.outOfStock,
      );

      final cart = CartModel(id: 'cart-123', items: [item1, item2, outOfStockItem]);

      // STEP 2 – Act
      final totalQuantity = cart.totalQuantity;
      final totalAmount = cart.totalAmount;

      // STEP 3 – Assert
      // Tổng số lượng item trong giỏ (bao gồm cả hàng hết hàng trong giỏ)
      expect(totalQuantity, 4); // 2 + 1 + 1 = 4
      // Tổng tiền chỉ tính các item còn hàng (isAvailable == true)
      // (25000000 * 2) + (500000 * 1) = 50500000.0
      expect(totalAmount, 50500000.0);
    });

    test('CartItemModel should correctly parse attributes JSON into Map', () {
      // STEP 1 – Arrange
      final item = CartItemModel(
        id: 'c4',
        productId: 'p4',
        productVariantId: 'v4',
        productName: 'Laptop Gaming RTX 4060',
        sku: 'LAPTOP-G15',
        attributes: '{"color":"Xám Không Gian","ram":"32GB","ssd":"1TB"}',
        unitPrice: 32000000.0,
        quantity: 1,
        stockQuantity: 5,
        status: CartItemStatus.available,
      );

      // STEP 2 – Act
      final attributeMap = item.attributeMap;

      // STEP 3 – Assert
      expect(attributeMap.length, 3);
      expect(attributeMap['color'], 'Xám Không Gian');
      expect(attributeMap['ram'], '32GB');
      expect(attributeMap['ssd'], '1TB');
    });

    test('formatVnd() should format Vietnamese currency accurately', () {
      // STEP 1 – Arrange
      const double price1 = 19990000.0;
      const double price2 = 500000.0;
      const double zeroPrice = 0.0;

      // STEP 2 – Act
      final formatted1 = formatVnd(price1);
      final formatted2 = formatVnd(price2);
      final formattedZero = formatVnd(zeroPrice);

      // STEP 3 – Assert
      expect(formatted1, '19.990.000 ₫');
      expect(formatted2, '500.000 ₫');
      expect(formattedZero, '0 ₫');
    });

    test('CartItemStatus.fromString() should map raw status strings and provide localized labels', () {
      // STEP 1 – Arrange & Act
      final available = CartItemStatus.fromString('available');
      final outOfStock = CartItemStatus.fromString('outofstock');
      final discontinued = CartItemStatus.fromString('discontinued');
      final unknown = CartItemStatus.fromString('other_status');

      // STEP 3 – Assert
      expect(available, CartItemStatus.available);
      expect(available.label, 'Còn hàng');

      expect(outOfStock, CartItemStatus.outOfStock);
      expect(outOfStock.label, 'Hết hàng');

      expect(discontinued, CartItemStatus.discontinued);
      expect(discontinued.label, 'Ngừng kinh doanh');

      expect(unknown, CartItemStatus.variantNotFound);
      expect(unknown.label, 'Phiên bản không còn tồn tại');
    });
  });
}
