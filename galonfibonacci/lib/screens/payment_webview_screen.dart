import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebviewScreen extends StatefulWidget {
  final String paymentUrl;

  const PaymentWebviewScreen({
    super.key,
    required this.paymentUrl,
  });

  @override
  State<PaymentWebviewScreen> createState() =>
      _PaymentWebviewScreenState();
}

class _PaymentWebviewScreenState
    extends State<PaymentWebviewScreen> {

  late final WebViewController controller;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()

      // AKTIFKAN JAVASCRIPT
      ..setJavaScriptMode(JavaScriptMode.unrestricted)

      // BACKGROUND PUTIH
      ..setBackgroundColor(const Color(0xFFFFFFFF))

      // NAVIGATION
      ..setNavigationDelegate(
        NavigationDelegate(

          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });

            debugPrint("PAGE START: $url");
          },

          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });

            debugPrint("PAGE FINISH: $url");
          },

          onWebResourceError: (WebResourceError error) {
            debugPrint(
              "WEBVIEW ERROR: ${error.description}",
            );
          },
        ),
      )

      // LOAD URL MIDTRANS
      ..loadRequest(
        Uri.parse(widget.paymentUrl),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Pembayaran",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),

      body: Stack(
        children: [

          // WEBVIEW
          WebViewWidget(
            controller: controller,
          ),

          // LOADING
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}