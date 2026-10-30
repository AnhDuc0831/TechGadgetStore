import 'package:flutter_test/flutter_test.dart';
import 'package:tech_gadget_app/models/order.dart';
import 'package:tech_gadget_app/providers/order_provider.dart';
import 'package:tech_gadget_app/services/order_service.dart';

class FakeOrderService extends OrderService {
  List<OrderModel> mockOrders = [];
  PagedOrders? mockPagedOrders;
  CheckoutResult? mockCheckoutResult;
  PaymentStatusResult? mockPaymentStatusResult;
  bool cancelShouldSucceed = true;
  String? lastUpdatedStatus;

  FakeOrderService() : super(baseUrl: 'http://localhost');

  @override
  Future<List<OrderModel>> getUserOrders(String accessToken) async {
    return mockOrders;
  }

  @override
  Future<CheckoutResult> checkout(String accessToken, CheckoutRequest request) async {
    if (mockCheckoutResult != null) return mockCheckoutResult!;
    throw Exception('Checkout failed in test');
  }

  @override
  Future<PaymentStatusResult> getPaymentStatus(String accessToken, String orderId) async {
    if (mockPaymentStatusResult != null) return mockPaymentStatusResult!;
    throw Exception('Status check failed in test');
  }

  @override
  Future<bool> cancelOrder(String accessToken, String orderId, {String? reason}) async {
    if (cancelShouldSucceed) return true;
    throw Exception('Cannot cancel order');
  }

  @override
  Future<PagedOrders> getAdminOrders(String accessToken, {int page = 1, int pageSize = 10, String? status}) async {
    return mockPagedOrders ?? PagedOrders(items: [], page: page, pageSize: pageSize, totalCount: 0, totalPages: 0);
  }

  @override
  Future<AdminOrderModel> updateOrderStatus(String accessToken, String orderId, String newStatus) async {
    lastUpdatedStatus = newStatus;
    return AdminOrderModel(
      id: orderId,
      status: newStatus,
      paymentMethod: 'PayOS',
      paymentStatus: 'Paid',
      totalAmount: 100000,
      shippingFee: 0,
      shippingAddress: 'Address',
      createdAt: DateTime.now(),
      items: [],
      needsReview: false,
    );
  }
}

void main() {
  group('OrderProvider Unit Tests', () {
    late FakeOrderService fakeService;
    late OrderProvider provider;

    setUp(() {
      fakeService = FakeOrderService();
      provider = OrderProvider(service: fakeService);
    });

    test('loadOrders populates orders list successfully', () async {
      fakeService.mockOrders = [
        OrderModel(
          id: 'ord-1',
          status: 'Confirmed',
          paymentMethod: 'PayOS',
          paymentStatus: 'Paid',
          totalAmount: 200000,
          shippingFee: 30000,
          shippingAddress: '123 Le Loi',
          createdAt: DateTime.now(),
          items: [],
        ),
      ];

      await provider.loadOrders('fake-token');

      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.orders.length, 1);
      expect(provider.orders.first.id, 'ord-1');
    });

    test('checkout sets loading and returns CheckoutResult', () async {
      fakeService.mockCheckoutResult = CheckoutResult(
        orderId: 'new-ord',
        orderCode: 1730000001,
        totalAmount: 500000,
        shippingFee: 0,
        paymentMethod: 'PayOS',
        paymentStatus: 'Pending',
        orderStatus: 'Pending',
        checkoutUrl: 'https://pay.payos.vn/web/test',
      );

      final req = CheckoutRequest(
        shippingName: 'User A',
        shippingPhone: '0987654321',
        shippingAddress: 'Address',
        paymentMethod: 'PayOS',
        selectedCartItemIds: ['item-1'],
      );

      final result = await provider.checkout('fake-token', req);

      expect(result.orderId, 'new-ord');
      expect(result.orderCode, 1730000001);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('pollPaymentStatus returns payment status from service', () async {
      fakeService.mockPaymentStatusResult = PaymentStatusResult(
        orderId: 'ord-poll',
        paymentStatus: 'Paid',
        orderStatus: 'Confirmed',
        totalAmount: 300000,
      );

      final res = await provider.pollPaymentStatus('fake-token', 'ord-poll');

      expect(res.isPaid, isTrue);
      expect(res.orderStatus, 'Confirmed');
    });

    test('cancelOrder calls service and reloads orders on success', () async {
      fakeService.cancelShouldSucceed = true;
      fakeService.mockOrders = [];

      final success = await provider.cancelOrder('fake-token', 'ord-to-cancel');

      expect(success, isTrue);
      expect(provider.isLoading, isFalse);
    });

    test('updateOrderStatus updates admin order in local list', () async {
      final initialAdminOrder = AdminOrderModel(
        id: 'ord-admin-1',
        status: 'Pending',
        paymentMethod: 'PayOS',
        paymentStatus: 'Paid',
        totalAmount: 100000,
        shippingFee: 0,
        shippingAddress: 'Address',
        createdAt: DateTime.now(),
        items: [],
      );

      fakeService.mockPagedOrders = PagedOrders(
        items: [initialAdminOrder],
        page: 1,
        pageSize: 10,
        totalCount: 1,
        totalPages: 1,
      );

      await provider.loadAdminOrders('fake-token');
      expect(provider.adminOrders!.items.first.status, 'Pending');

      final updated = await provider.updateOrderStatus('fake-token', 'ord-admin-1', 'Confirmed');

      expect(fakeService.lastUpdatedStatus, 'Confirmed');
      expect(updated.status, 'Confirmed');
      expect(provider.adminOrders!.items.first.status, 'Confirmed');
    });
  });
}

