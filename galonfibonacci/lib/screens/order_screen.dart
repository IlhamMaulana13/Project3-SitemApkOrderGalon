import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:galonfibonacci/screens/invoice_screen.dart';

import '../models/order_model.dart';
import '../services/api_service.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  List<OrderModel> orders = [];
  List<Map<String, dynamic>> rewardVouchers = [];

  Timer? timer;

  // simpan status lama
  Map<int, String> oldStatus = {};

  Color getStatusColor(String status) {
    switch (status) {
      case "Diproses":
        return Colors.orange;

      case "Dikirim":
        return Colors.blue;

      case "Selesai":
        return Colors.green;

      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();

    fetchOrders();
    fetchUserVouchers();

    // realtime refresh tiap 5 detik
    timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      fetchOrders();
      fetchUserVouchers();
    });
  }

  Future<void> fetchUserVouchers() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        rewardVouchers = [];
      });
      return;
    }

    final result = await ApiService.getUserVouchers(user.uid);

    if (!mounted) return;

    setState(() {
      rewardVouchers = result;
    });
  }

  Future<void> fetchOrders() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        orders = [];
      });
      return;
    }

    final result = await ApiService.getOrders(userId: user.uid);

    // cek perubahan status
    for (var order in result) {
      // kalau order sudah pernah ada
      if (oldStatus.containsKey(order.id)) {
        // status berubah
        if (oldStatus[order.id] != order.status) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.blue[700],

                content: Text(
                  "Status pesanan #${order.id} berubah menjadi ${order.status}",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          }
        }
      }

      // update status lama
      oldStatus[order.id] = order.status;
    }

    setState(() {
      orders = result;
    });
  }

  @override
  void dispose() {
    timer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: orders.isEmpty && rewardVouchers.isEmpty
          ? const Center(child: Text("Belum ada pesanan"))
          : ListView(
              padding: const EdgeInsets.all(15),
              children: [
                if (rewardVouchers.isNotEmpty) ...[
                  const Text(
                    'Voucher Saya',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...rewardVouchers.map((voucher) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[400]!, Colors.blue[700]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    voucher['code'] ?? '-',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Diskon Rp ${voucher['discount'] ?? 0}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Gunakan',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  const Text(
                    'Pesanan Saya',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                ],
                if (orders.isEmpty)
                  const Center(child: Text("Belum ada pesanan"))
                else
                  ...orders.map((order) {
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InvoiceScreen(orderId: order.id),
                          ),
                        );
                      },
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.only(bottom: 15),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Pesanan #${order.id}",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(order.status),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      order.status,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Icon(
                                    Icons.payments,
                                    color: Colors.green[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Rp ${order.total}",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    order.createdAt,
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            InvoiceScreen(orderId: order.id),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.receipt_long),
                                  label: const Text("Lihat Invoice"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
