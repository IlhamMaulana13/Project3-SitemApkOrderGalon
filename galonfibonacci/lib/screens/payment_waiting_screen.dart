import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';

class PaymentWaitingScreen extends StatefulWidget {
  final String orderId;

  const PaymentWaitingScreen({super.key, required this.orderId});

  @override
  State<PaymentWaitingScreen> createState() => _PaymentWaitingScreenState();
}

class _PaymentWaitingScreenState extends State<PaymentWaitingScreen> {
  Timer? _countdownTimer;
  Timer? _pollingTimer;

  String paymentStatus = "pending";
  int remainingSeconds = 900; // 15 menit
  bool _dialogShown = false;

  static const Set<String> _successStatuses = {'paid', 'settlement', 'capture'};
  static const Set<String> _failedStatuses = {
    'expired', 'expire', 'cancelled', 'cancel', 'failed', 'deny', 'denied'
  };

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _startPolling();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else {
        _countdownTimer?.cancel();
        _pollingTimer?.cancel();
        _showFailedDialog("Waktu pembayaran habis");
      }
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/payment-status/${widget.orderId}"),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = (data["status"] ?? "pending").toString().toLowerCase();

        setState(() => paymentStatus = status);

        if (_successStatuses.contains(status)) {
          _countdownTimer?.cancel();
          _pollingTimer?.cancel();
          _showSuccessDialog();
        } else if (_failedStatuses.contains(status)) {
          _countdownTimer?.cancel();
          _pollingTimer?.cancel();
          _showFailedDialog("Pembayaran gagal atau dibatalkan");
        }
      }
    } catch (e) {
      debugPrint("checkStatus error: $e");
    }
  }

  void _showSuccessDialog() {
    if (_dialogShown || !mounted) return;
    _dialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.green[100],
              child: Icon(Icons.check_rounded, color: Colors.green[700], size: 50),
            ),
            const SizedBox(height: 20),
            const Text(
              "Pembayaran Berhasil!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Pesanan kamu sedang diproses oleh tim kami.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text("Kembali ke Beranda"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFailedDialog(String reason) {
    if (_dialogShown || !mounted) return;
    _dialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.red[100],
              child: Icon(Icons.close_rounded, color: Colors.red[700], size: 50),
            ),
            const SizedBox(height: 20),
            const Text(
              "Pembayaran Gagal",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text("Kembali ke Beranda"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  String _statusLabel(String status) {
    if (_successStatuses.contains(status)) return "LUNAS";
    if (_failedStatuses.contains(status)) return "GAGAL";
    return "MENUNGGU";
  }

  Color _statusColor(String status) {
    if (_successStatuses.contains(status)) return Colors.green;
    if (_failedStatuses.contains(status)) return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(paymentStatus);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Status Pembayaran",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.access_time_filled_rounded,
                    size: 70,
                    color: Colors.orange[600],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Menunggu Pembayaran",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Selesaikan pembayaran sebelum waktu habis",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),

                  const SizedBox(height: 24),

                  // Countdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _formatTime(remainingSeconds),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Status chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _statusLabel(paymentStatus),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Order ID info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_outlined,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "ID: ${widget.orderId}",
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _checkStatus,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text("Perbarui Status"),
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (r) => r.isFirst),
                    child: Text(
                      "Kembali ke Beranda",
                      style: TextStyle(color: Colors.grey[600]),
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
