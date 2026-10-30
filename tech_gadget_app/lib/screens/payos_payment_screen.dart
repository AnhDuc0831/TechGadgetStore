import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'payment_result_screen.dart';

class PayOSPaymentScreen extends StatefulWidget {
  final String orderId;
  final int? orderCode;
  final String checkoutUrl;

  const PayOSPaymentScreen({
    super.key,
    required this.orderId,
    this.orderCode,
    required this.checkoutUrl,
  });

  static const String returnUrlPrefix = 'https://techgadget.store/payment-success';
  static const String cancelUrlPrefix = 'https://techgadget.store/payment-cancel';

  @override
  State<PayOSPaymentScreen> createState() => _PayOSPaymentScreenState();
}

class _PayOSPaymentScreenState extends State<PayOSPaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _hasNavigatedToResult = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100.0;
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
            _checkInterceptUrl(url);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
            _checkInterceptUrl(url);
          },
          onNavigationRequest: (request) async {
            final url = request.url;

            // 1. Chặn returnUrl và cancelUrl của PayOS
            if (url.startsWith(PayOSPaymentScreen.returnUrlPrefix) ||
                url.startsWith(PayOSPaymentScreen.cancelUrlPrefix)) {
              _goToResultScreen();
              return NavigationDecision.prevent;
            }

            // 2. Chặn các scheme không phải http/https (deep link app ngân hàng, ví điện tử)
            final uri = Uri.tryParse(url);
            if (uri != null && uri.scheme != 'http' && uri.scheme != 'https') {
              try {
                final canLaunch = await canLaunchUrl(uri);
                if (canLaunch) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  debugPrint('Không thể mở deep link ứng dụng: $url');
                }
              } catch (e) {
                debugPrint('Lỗi khi mở external application: $e');
              }
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _checkInterceptUrl(String url) {
    if (_hasNavigatedToResult) return;
    if (url.startsWith(PayOSPaymentScreen.returnUrlPrefix) ||
        url.startsWith(PayOSPaymentScreen.cancelUrlPrefix)) {
      _goToResultScreen();
    }
  }

  void _goToResultScreen() {
    if (_hasNavigatedToResult || !mounted) return;
    _hasNavigatedToResult = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentResultScreen(
          orderId: widget.orderId,
          orderCode: widget.orderCode,
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rời khỏi thanh toán?'),
        content: const Text(
          'Giao dịch chuyển khoản có thể chưa hoàn tất. Bạn có chắc muốn rời khỏi màn hình này để kiểm tra trạng thái đơn hàng?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rời đi'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _goToResultScreen();
      return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.orderCode != null
              ? 'Thanh toán đơn #${widget.orderCode}'
              : 'Thanh toán PayOS'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _onWillPop,
          ),
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3.0),
                  child: LinearProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null,
                  ),
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Tải lại trang',
              onPressed: () => _controller.reload(),
            ),
          ],
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}

