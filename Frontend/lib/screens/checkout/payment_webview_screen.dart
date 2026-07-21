// lib/screens/checkout/payment_webview_screen.dart
//
// يفتح صفحة ويدجت HyperPay (Copy&Pay) جوا WebView. هاي الشاشة ما بتقرر أبدًا
// إذا الدفع نجح أو فشل - بس بتكتشف إنه المستخدم خلّص من تعبئة الفورم ورجع
// لعنوان /return، وبترجع "finished". القرار الحقيقي دايمًا من الباك إند
// (PaymentService.verifyPaymentStatus) بعد ما تسكّر هاي الشاشة.
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum PaymentWebViewResult { finished, cancelled }

class PaymentWebViewScreen extends StatefulWidget {
  final String widgetUrl;

  const PaymentWebViewScreen({super.key, required this.widgetUrl});

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            if (request.url.contains('/api/payments/return')) {
              Navigator.of(context).pop(PaymentWebViewResult.finished);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.widgetUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(PaymentWebViewResult.cancelled);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
          title: const Text('إتمام الدفع'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(PaymentWebViewResult.cancelled),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
