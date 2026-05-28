import 'dart:convert';

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
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void applyVoucher(int subtotal) {
    final code = voucherController.text.trim();

    if (code.isEmpty) {
      setState(() {
        discount = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Masukkan kode voucher terlebih dahulu")),
      );
      return;
    }

    int matchedDiscount = 0;

    for (var voucher in rewardVouchers) {
      if (voucher["code"] == code) {
        matchedDiscount = voucher["discount"] as int;
        break;
      }
    }

    if (matchedDiscount > 0) {
      setState(() {
        discount = matchedDiscount;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Voucher berhasil digunakan")),
      );
      return;
    }

    if (code == "GALON10") {
      setState(() {
        discount = 10000;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Voucher berhasil digunakan")),
      );
      return;
    }

    setState(() {
      discount = 0;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Voucher tidak valid")));
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
      int total = subtotal - discount;

      if (selectedPayment == "COD") {
        final codResponse = await http.post(
          Uri.parse("${ApiConfig.baseUrl}/orders"),

          headers: {"Content-Type": "application/json"},

          body: jsonEncode({
            "user_id": user.uid,
            "payment_method_id": 2,
            "payment_channel": "COD",
            "midtrans_order_id": null,
            "total": total,

            "items": cartProvider.items.map((item) {
              return {
                "product_id": item.product.id,
                "qty": item.quantity,
                "subtotal": item.product.price * item.quantity,
                "service": item.service,
              };
            }).toList(),
          }),
        );

        if (codResponse.statusCode == 200) {
          cartProvider.clearCart();

          if (!mounted) return;

          showDialog(
            context: context,
            builder: (_) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),

                title: const Text("Pesanan Berhasil"),

                content: const Text("Pesanan COD berhasil dibuat."),

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

        setState(() {
          isLoading = false;
        });

        return;
      }

      final orderId = "ORDER-${DateTime.now().millisecondsSinceEpoch}";

      final response = await http.post(
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final paymentUrl = data["redirect_url"];
        final idempotencyKey =
            "${user.uid}_${DateTime.now().millisecondsSinceEpoch}";

        await http.post(
          Uri.parse("${ApiConfig.baseUrl}/orders"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "user_id": user.uid,
            "payment_method_id": 1,
            "payment_channel": selectedPayment,
            "midtrans_order_id": orderId,
            "idempotency_key": idempotencyKey,
            "total": total,
            "items": cartProvider.items.map((item) {
              return {
                "product_id": item.product.id,
                "qty": item.quantity,
                "subtotal": item.product.price * item.quantity,
                "service": item.service,
              };
            }).toList(),
          }),
        );

        cartProvider.clearCart();

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebviewScreen(paymentUrl: paymentUrl),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal membuat pembayaran (${response.statusCode})"),
          ),
        );
      }
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

    int total = subtotal - discount;

    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text("Checkout", style: TextStyle(color: Colors.white)),
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
                                "Informasi Customer",
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

                                label: const Text("Edit"),
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

                  if (rewardVouchers.isNotEmpty)
                    Card(
                      color: Colors.green[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Voucher Reward",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Selamat! Transaksi ke-5 kamu mendapatkan voucher ${rewardVouchers.first["code"]} dengan potongan Rp ${rewardVouchers.first["discount"]}.",
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Masukkan kode tersebut di kolom voucher dan klik Apply.",
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

                              child: const Text("Apply"),
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
                                "- Rp $discount",

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
