import 'package:flutter/material.dart';
import 'package:galonfibonacci/screens/payment_waiting_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebviewScreen extends StatefulWidget {
  final String paymentUrl;
  final String orderId;

  const PaymentWebviewScreen({
    super.key,
    required this.paymentUrl,
    required this.orderId,
  });

  @override
  State<PaymentWebviewScreen> createState() => _PaymentWebviewScreenState();
}

class _PaymentWebviewScreenState extends State<PaymentWebviewScreen> {
  late final WebViewController _controller;
  bool isLoading = true;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => isLoading = true),
          onPageFinished: (_) => setState(() => isLoading = false),
          onWebResourceError: (err) =>
              debugPrint("WEBVIEW ERROR: ${err.description}"),

          // Deteksi URL penyelesaian Midtrans
          onNavigationRequest: (NavigationRequest req) {
            final url = req.url.toLowerCase();

            final isSuccess = url.contains('transaction_status=settlement') ||
                url.contains('transaction_status=capture') ||
                url.contains('status_code=200') ||
                url.contains('/finish');

            final isPending =
                url.contains('transaction_status=pending') ||
                url.contains('status_code=201');

            final isFailed = url.contains('transaction_status=expire') ||
                url.contains('transaction_status=cancel') ||
                url.contains('transaction_status=deny') ||
                url.contains('status_code=4') ||
                url.contains('/error');

            if ((isSuccess || isPending || isFailed) && !_navigating) {
              _goToWaiting();
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _goToWaiting() {
    if (_navigating || !mounted) return;
    _navigating = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentWaitingScreen(orderId: widget.orderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToWaiting();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue[700],
          title: const Text(
            "Pembayaran",
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: "Selesai / Cek Status",
            onPressed: _goToWaiting,
          ),
          actions: [
            TextButton.icon(
              onPressed: _goToWaiting,
              icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
              label: const Text(
                "Cek Status",
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (isLoading)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
