import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:galonfibonacci/provider/cart_provider.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../api_config.dart';

class PaymentWaitingScreen extends StatefulWidget {
  final String orderId;

  const PaymentWaitingScreen({super.key, required this.orderId});

  @override
  State<PaymentWaitingScreen> createState() => _PaymentWaitingScreenState();
}

class _PaymentWaitingScreenState extends State<PaymentWaitingScreen> {
  Timer? countdownTimer;

  Timer? pollingTimer;

  String paymentStatus = "pending";

  int remainingSeconds = 900;

  @override
  void initState() {
    super.initState();

    startTimer();

    startAutoCheck();
  }

  void startTimer() {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      }
    });
  }

  void startAutoCheck() {
    pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await checkPaymentStatus();

      if (paymentStatus == "paid") {
        timer.cancel();

        if (!mounted) return;
        
        Provider.of<CartProvider>(context, listen: false).clearCart();

        showSuccessDialog();
      }

      if (paymentStatus == "expire" || paymentStatus == "cancel") {
        timer.cancel();

        if (!mounted) return;

        showFailedDialog();
      }
    });
  }

  void showFailedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text("Pembayaran Gagal"),

          content: const Text("Pembayaran expired atau dibatalkan"),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> checkPaymentStatus() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/payment-status/${widget.orderId}"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;

        setState(() {
          paymentStatus = data["payment_status"] ?? "pending";
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: const Text("Pembayaran Berhasil"),

          content: const Text("Pesanan kamu berhasil dibayar."),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                Navigator.pop(context);
              },

              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  String formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');

    final secs = (seconds % 60).toString().padLeft(2, '0');

    return "$minutes:$secs";
  }

  @override
  void dispose() {
    countdownTimer?.cancel();

    pollingTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text(
          "Menunggu Pembayaran",
          style: TextStyle(color: Colors.white),
        ),

        backgroundColor: Colors.blue[700],

        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(30),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(20),
              ),

              child: Column(
                children: [
                  Icon(
                    Icons.access_time_filled,
                    size: 80,
                    color: Colors.orange[700],
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Menunggu Pembayaran",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Selesaikan pembayaran sebelum waktu habis",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),

                  const SizedBox(height: 25),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,

                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Text(
                      formatTime(remainingSeconds),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),

                    decoration: BoxDecoration(
                      color: paymentStatus == "paid"
                          ? Colors.green.shade50
                          : Colors.orange.shade50,

                      borderRadius: BorderRadius.circular(30),
                    ),

                    child: Text(
                      paymentStatus.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: paymentStatus == "paid"
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,

                    child: ElevatedButton.icon(
                      onPressed: checkPaymentStatus,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),

                      icon: const Icon(Icons.refresh),

                      label: const Text("Cek Status Pembayaran"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
