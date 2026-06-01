import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:galonfibonacci/provider/cart_provider.dart';
import 'package:galonfibonacci/screens/edit_profile_screen.dart';
import 'package:galonfibonacci/screens/payment_webview_screen.dart';
import 'package:galonfibonacci/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:galonfibonacci/api_config.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final voucherController = TextEditingController();

  Map<String, dynamic>? profile;

  List<Map<String, dynamic>> rewardVouchers = [];

  int discount = 0;

  bool isLoading = false;

  String selectedPayment = "QRIS";

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/profile/${user.uid}"),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        setState(() {
          profile = jsonDecode(response.body);
        });

        fetchUserVouchers();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> fetchUserVouchers() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final result = await ApiService.getUserVouchers(user.uid);

      if (!mounted) return;

      setState(() {
        rewardVouchers = result;
      });

      applyVoucher(Provider.of<CartProvider>(context, listen: false).total);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void applyVoucher(int subtotal) {
    int matchedDiscount = 0;

    // AUTO ambil voucher reward pertama
    if (rewardVouchers.isNotEmpty) {
      matchedDiscount = rewardVouchers.first["discount"] as int;

      voucherController.text = rewardVouchers.first["code"];
    }

    // fallback voucher manual
    if (matchedDiscount == 0) {
      final code = voucherController.text.trim();

      for (var voucher in rewardVouchers) {
        if (voucher["code"] == code) {
          matchedDiscount = voucher["discount"] as int;
          break;
        }
      }

      if (matchedDiscount == 0 && code == "GALON10") {
        matchedDiscount = 10000;
      }
    }

    setState(() {
      discount = matchedDiscount;
    });
  }

  Future<void> checkout() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (cartProvider.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Keranjang masih kosong")));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      int subtotal = cartProvider.total;
      int appliedDiscount = min(discount, subtotal);
      int total = subtotal - appliedDiscount;

      // ─── COD ───────────────────────────────────────────────
      if (selectedPayment == "COD") {
        final codKey = "${user.uid}_COD_${DateTime.now().millisecondsSinceEpoch}";
        final codResponse = await http.post(
          Uri.parse("${ApiConfig.baseUrl}/orders"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "user_id": user.uid,
            "payment_method_id": 2,
            "payment_channel": "COD",
            "midtrans_order_id": "COD-${DateTime.now().millisecondsSinceEpoch}",
            "idempotency_key": codKey,
            "total": total,
            "voucher_code": voucherController.text.trim(),
            "voucher_discount": appliedDiscount,
            "items": cartProvider.items.map((item) => {
              "product_id": item.product.id,
              "qty": item.quantity,
              "subtotal": item.product.price * item.quantity,
              "service": item.service,
            }).toList(),
          }),
        );

        if (!mounted) return;

        if (codResponse.statusCode == 200) {
          cartProvider.clearCart();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.green[100],
                    child: Icon(Icons.check_rounded, color: Colors.green[700], size: 44),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Pesanan Berhasil!",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Pesanan COD kamu sudah masuk.\nTim kami akan segera menghubungi kamu.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.popUntil(context, (r) => r.isFirst);
                      },
                      child: const Text("Kembali ke Beranda"),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          final err = jsonDecode(codResponse.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err["error"] ?? "Gagal membuat pesanan COD")),
          );
        }

        setState(() => isLoading = false);
        return;
      }

      // ─── PEMBAYARAN ONLINE (Midtrans) ──────────────────────
      final orderId = "ORDER-${DateTime.now().millisecondsSinceEpoch}";

      final paymentResponse = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/payment"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "order_id": orderId,
          "total": total,
          "customer_name": profile?["name"] ?? "",
          "customer_email": user.email ?? "",
          "customer_phone": profile?["phone"] ?? "",
        }),
      );

      if (paymentResponse.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Gagal membuat pembayaran (${paymentResponse.statusCode})"),
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      final payData = jsonDecode(paymentResponse.body);
      final paymentUrl = payData["redirect_url"] as String?;

      if (paymentUrl == null || paymentUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("URL pembayaran tidak valid")),
        );
        setState(() => isLoading = false);
        return;
      }

      // Simpan order ke database
      final idempotencyKey =
          "${user.uid}_${DateTime.now().millisecondsSinceEpoch}";

      final orderResponse = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/orders"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": user.uid,
          "payment_method_id": 1,
          "payment_channel": selectedPayment,
          "midtrans_order_id": orderId,
          "idempotency_key": idempotencyKey,
          "total": total,
          "voucher_code": voucherController.text.trim(),
          "voucher_discount": appliedDiscount,
          "items": cartProvider.items.map((item) => {
            "product_id": item.product.id,
            "qty": item.quantity,
            "subtotal": item.product.price * item.quantity,
            "service": item.service,
          }).toList(),
        }),
      );

      if (!mounted) return;

      if (orderResponse.statusCode != 200) {
        final err = jsonDecode(orderResponse.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err["error"] ?? "Gagal menyimpan pesanan")),
        );
        setState(() => isLoading = false);
        return;
      }

      cartProvider.clearCart();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentWebviewScreen(
            paymentUrl: paymentUrl,
            orderId: orderId,
          ),
        ),
      );
    } catch (e) {
      debugPrint(e.toString());

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Terjadi error: $e")));
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    int subtotal = cartProvider.total;
    int appliedDiscount = min(discount, subtotal);

    int total = subtotal - appliedDiscount;

    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text("Konfirmasi Pesanan", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // CUSTOMER INFO
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Padding(
                      padding: const EdgeInsets.all(16),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              const Text(
                                "Informasi Pelanggan",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              TextButton.icon(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const EditProfileScreen(),
                                    ),
                                  );

                                  fetchProfile();
                                },

                                icon: const Icon(Icons.edit, size: 18),

                                label: const Text("Ubah"),
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),

                          ListTile(
                            contentPadding: EdgeInsets.zero,

                            leading: const Icon(Icons.person),

                            title: Text(profile?["name"] ?? "Belum diisi"),

                            subtitle: const Text("Nama Lengkap"),
                          ),

                          ListTile(
                            contentPadding: EdgeInsets.zero,

                            leading: const Icon(Icons.phone),

                            title: Text(profile?["phone"] ?? "Belum diisi"),

                            subtitle: const Text("Nomor HP"),
                          ),

                          ListTile(
                            contentPadding: EdgeInsets.zero,

                            leading: const Icon(Icons.location_on),

                            title: Text(profile?["address"] ?? "Belum diisi"),

                            subtitle: const Text("Alamat Pengiriman"),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Metode Pembayaran",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 15),

                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: paymentItem(
                                      "QRIS",
                                      "assets/images/qris.png",
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: paymentItem(
                                      "BCA VA",
                                      "assets/images/bca.png",
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Expanded(
                                    child: paymentItem(
                                      "GoPay",
                                      "assets/images/gopay.png",
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: paymentItem(
                                      "ShopeePay",
                                      "assets/images/shopepay.png",
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              Row(
                                children: [
                                  Expanded(
                                    child: paymentItem(
                                      "COD",
                                      "assets/images/cod.png",
                                    ),
                                  ),

                                  const Expanded(child: SizedBox()),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // VOUCHER
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Padding(
                      padding: const EdgeInsets.all(16),

                      child: TextField(
                        controller: voucherController,

                        decoration: InputDecoration(
                          hintText: "Masukkan kode voucher",

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),

                          suffixIcon: Padding(
                            padding: const EdgeInsets.all(5),

                            child: ElevatedButton(
                              onPressed: () {
                                applyVoucher(subtotal);
                              },

                              child: const Text("Terapkan"),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // RINGKASAN
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Padding(
                      padding: const EdgeInsets.all(16),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const Text(
                            "Ringkasan Pesanan",

                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 15),

                          ...cartProvider.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),

                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,

                                children: [
                                  Expanded(
                                    child: Text(
                                      "${item.product.merk} x${item.quantity}",
                                    ),
                                  ),

                                  Text("Rp ${item.subtotal}"),
                                ],
                              ),
                            );
                          }),

                          const Divider(),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              const Text("Subtotal"),

                              Text("Rp $subtotal"),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              const Text("Potongan"),

                              Text(
                                "- Rp $appliedDiscount",

                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),

                          const Divider(),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              const Text(
                                "Total Bayar",

                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              Text(
                                "Rp $total",

                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,

                    child: ElevatedButton(
                      onPressed: isLoading ? null : checkout,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],

                        foregroundColor: Colors.white,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),

                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Bayar Sekarang",

                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget paymentItem(String title, String image) {
    final isSelected = selectedPayment == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPayment = title;
        });
        print(selectedPayment);
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,

          borderRadius: BorderRadius.circular(16),

          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,

            width: 2,
          ),
        ),

        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,

              child: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,

                color: isSelected ? Colors.blue : Colors.grey,
              ),
            ),

            const SizedBox(height: 5),

            Image.asset(image, height: 40),

            const SizedBox(height: 10),

            Text(
              title,

              style: TextStyle(
                fontWeight: FontWeight.bold,

                color: isSelected ? Colors.blue[700] : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
