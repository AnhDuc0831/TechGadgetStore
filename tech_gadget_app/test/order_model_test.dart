import 'package:flutter_test/flutter_test.dart';
import 'package:tech_gadget_app/models/order.dart';

void main() {
  group('OrderModel & Enums Unit Tests', () {
    test('OrderModel parses customer DTO correctly with no internal notes', () {
      final json = {
        'id': '7b0d7751-60a3-44f3-8b7c-02cf3c959601',
        'status': 'Confirmed',
        'paymentMethod': 'PayOS',
        'paymentStatus': 'Paid',
        'totalAmount': 25030000.0,
        'shippingFee': 30000.0,
        'shippingName': 'Nguyễn Văn A',
        'shippingPhone': '0987654321',
        'shippingAddress': '123 Đường Lê Lợi, TP. HCM',
        'note': 'Giao giờ hành chính',
        'createdAt': '2026-10-29T14:45:00.123+07:00',
        'paidAt': '2026-10-29T14:46:12.456+07:00',
        'checkoutUrl': null,
        'items': [
          {
            'id': 'e4d28430-84dc-4131-9257-ecfa994f794b',
            'productVariantId': '11111111-2222-3333-4444-555555555555',
            'productName': 'iPhone 15 Pro Max',
            'sku': 'IP15PM-256',
            'unitPrice': 25000000.0,
            'quantity': 1,
            'totalPrice': 25000000.0,
          }
        ],
      };

      final order = OrderModel.fromJson(json);

      expect(order.id, '7b0d7751-60a3-44f3-8b7c-02cf3c959601');
      expect(order.statusEnum, OrderStatusEnum.confirmed);
      expect(order.statusLabel, 'Đã xác nhận');
      expect(order.paymentStatusEnum, PaymentStatusEnum.paid);
      expect(order.paymentStatusLabel, 'Đã thanh toán');
      expect(order.paymentMethodLabel, 'Chuyển khoản QR (payOS)');
      expect(order.totalAmount, 25030000.0);
      expect(order.shippingFee, 30000.0);
      expect(order.shippingName, 'Nguyễn Văn A');
      expect(order.shippingPhone, '0987654321');
      expect(order.items.length, 1);
      expect(order.items.first.productName, 'iPhone 15 Pro Max');
      expect(order.items.first.unitPrice, 25000000.0);
      expect(order.paidAt, isNotNull);
      expect(order.canCancel, isFalse); // Paid orders cannot be cancelled
    });

    test('Unpaid PayOS order allows reopen payment and cancellation', () {
      final json = {
        'id': 'order-123',
        'status': 'Pending',
        'paymentMethod': 'PayOS',
        'paymentStatus': 'Pending',
        'totalAmount': 500000.0,
        'shippingFee': 30000.0,
        'shippingAddress': '456 Tran Phu',
        'createdAt': '2026-10-30T10:00:00Z',
        'checkoutUrl': 'https://pay.payos.vn/web/test',
        'items': [],
      };

      final order = OrderModel.fromJson(json);

      expect(order.statusEnum, OrderStatusEnum.pending);
      expect(order.paymentStatusEnum, PaymentStatusEnum.pending);
      expect(order.canCancel, isTrue);
      expect(order.canReopenPayment, isTrue);
    });

    test('AdminOrderModel parses admin metadata and needsReview badge', () {
      final json = {
        'id': '8c1e8862-71b4-55a4-9c8d-13da4d060712',
        'status': 'Cancelled',
        'paymentMethod': 'PayOS',
        'paymentStatus': 'Paid',
        'totalAmount': 1200000.0,
        'shippingFee': 30000.0,
        'shippingName': 'Trần Thị B',
        'shippingAddress': '456 CMT8',
        'createdAt': '2026-10-29T13:00:00Z',
        'userId': 'aaaa1111-bbbb-2222-cccc-333344445555',
        'payOSOrderCode': 1730182000456,
        'paymentLinkId': 'plink_def456uvw',
        'internalNote': 'admin cancelled paid order - manual refund required',
        'needsReview': true,
        'items': [],
      };

      final adminOrder = AdminOrderModel.fromJson(json);

      expect(adminOrder.id, '8c1e8862-71b4-55a4-9c8d-13da4d060712');
      expect(adminOrder.needsReview, isTrue);
      expect(adminOrder.internalNote, contains('manual refund required'));
      expect(adminOrder.payosOrderCode, 1730182000456);
      expect(adminOrder.userId, 'aaaa1111-bbbb-2222-cccc-333344445555');
    });

    test('Allowed admin status transitions match backend matrix', () {
      expect(OrderStatusEnum.pending.allowedNextStatuses, [
        OrderStatusEnum.confirmed,
        OrderStatusEnum.cancelled,
      ]);
      expect(OrderStatusEnum.confirmed.allowedNextStatuses, [
        OrderStatusEnum.shipping,
        OrderStatusEnum.cancelled,
      ]);
      expect(OrderStatusEnum.shipping.allowedNextStatuses, [
        OrderStatusEnum.completed,
      ]);
      expect(OrderStatusEnum.completed.allowedNextStatuses, isEmpty);
      expect(OrderStatusEnum.cancelled.allowedNextStatuses, isEmpty);
    });

    test('Defensive parsing handles unknown enum strings without crashing', () {
      expect(OrderStatusEnum.fromString('SomethingNew'), OrderStatusEnum.unknown);
      expect(PaymentStatusEnum.fromString('UnderReview'), PaymentStatusEnum.unknown);

      final order = OrderModel.fromJson({
        'id': 'order-test',
        'status': 'FutureStatus',
        'paymentMethod': 'ZaloPay',
        'paymentStatus': 'ProcessingRefund',
        'totalAmount': 100000,
        'shippingFee': 0,
        'shippingAddress': 'Test Address',
        'createdAt': '2026-10-30T10:00:00Z',
        'items': [],
      });

      expect(order.statusLabel, 'FutureStatus');
      expect(order.paymentStatusLabel, 'ProcessingRefund');
      expect(order.paymentMethodLabel, 'ZaloPay');
    });

    test('CheckoutResult parses 64-bit int orderCode and checkoutUrl', () {
      final json = {
        'orderId': 'ord-999',
        'orderCode': 1730188000999,
        'totalAmount': 1500000.0,
        'shippingFee': 0.0,
        'paymentMethod': 'PayOS',
        'paymentStatus': 'Pending',
        'orderStatus': 'Pending',
        'checkoutUrl': 'https://pay.payos.vn/web/test999',
        'qrCode': 'data:image/png;base64,abc...',
      };

      final result = CheckoutResult.fromJson(json);

      expect(result.orderId, 'ord-999');
      expect(result.orderCode, 1730188000999);
      expect(result.isPayOS, isTrue);
      expect(result.checkoutUrl, 'https://pay.payos.vn/web/test999');
      expect(result.totalAmount, 1500000.0);
    });

    test('PaymentStatusResult correctly indicates isPaid and isPending', () {
      final paidResult = PaymentStatusResult.fromJson({
        'orderId': '123',
        'paymentStatus': 'Paid',
        'orderStatus': 'Confirmed',
        'totalAmount': 200000,
      });
      expect(paidResult.isPaid, isTrue);
      expect(paidResult.isPending, isFalse);

      final pendingResult = PaymentStatusResult.fromJson({
        'orderId': '123',
        'paymentStatus': 'Pending',
        'orderStatus': 'Pending',
        'totalAmount': 200000,
        'checkoutUrl': 'https://pay.payos.vn/web/123',
      });
      expect(pendingResult.isPaid, isFalse);
      expect(pendingResult.isPending, isTrue);
    });

    test('canCancel returns true ONLY when status is Pending AND paymentStatus is Pending', () {
      OrderModel createOrder({required String status, required String paymentStatus}) {
        return OrderModel(
          id: 'test-cancel-id',
          status: status,
          paymentMethod: 'Cod',
          paymentStatus: paymentStatus,
          totalAmount: 200000,
          shippingFee: 30000,
          shippingAddress: 'Address',
          createdAt: DateTime.now(),
          items: [],
        );
      }

      // Allowed
      expect(createOrder(status: 'Pending', paymentStatus: 'Pending').canCancel, isTrue);

      // Disallowed order statuses (even if payment is pending)
      expect(createOrder(status: 'Confirmed', paymentStatus: 'Pending').canCancel, isFalse);
      expect(createOrder(status: 'Shipping', paymentStatus: 'Pending').canCancel, isFalse);
      expect(createOrder(status: 'Completed', paymentStatus: 'Pending').canCancel, isFalse);
      expect(createOrder(status: 'Cancelled', paymentStatus: 'Pending').canCancel, isFalse);

      // Disallowed payment statuses (even if status is pending)
      expect(createOrder(status: 'Pending', paymentStatus: 'Paid').canCancel, isFalse);
      expect(createOrder(status: 'Pending', paymentStatus: 'Failed').canCancel, isFalse);
      expect(createOrder(status: 'Pending', paymentStatus: 'Cancelled').canCancel, isFalse);
      expect(createOrder(status: 'Pending', paymentStatus: 'Expired').canCancel, isFalse);
    });

    test('VN phone regex ^0[35789][0-9]{8}\$ correctly validates Vietnamese phone numbers', () {
      final regex = RegExp(r'^0[35789][0-9]{8}$');

      // Valid phone numbers (10 digits starting with 03, 05, 07, 08, 09)
      expect(regex.hasMatch('0987654321'), isTrue);
      expect(regex.hasMatch('0323456789'), isTrue);
      expect(regex.hasMatch('0512345678'), isTrue);
      expect(regex.hasMatch('0789123456'), isTrue);
      expect(regex.hasMatch('0898765432'), isTrue);

      // Invalid prefixes
      expect(regex.hasMatch('0123456789'), isFalse);
      expect(regex.hasMatch('0412345678'), isFalse);
      expect(regex.hasMatch('0612345678'), isFalse);

      // Invalid characters or pipe characters
      expect(regex.hasMatch('0|87654321'), isFalse);
      expect(regex.hasMatch('098765432a'), isFalse);

      // Invalid length
      expect(regex.hasMatch('098765432'), isFalse); // 9 digits
      expect(regex.hasMatch('09876543210'), isFalse); // 11 digits
      expect(regex.hasMatch(''), isFalse);
    });
  });
}

