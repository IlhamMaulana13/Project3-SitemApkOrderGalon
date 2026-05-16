import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:galonfibonacci/provider/cart_provider.dart';
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

  int discount = 0;

  @override
  void initState() {
    super.initState();

    fetchProfile();
  }

  Future<void> fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/profile/${user.uid}"),
    );

    if (response.statusCode == 200) {
      setState(() {
        profile = jsonDecode(response.body);
      });
    }
  }

  void applyVoucher(int subtotal) {
    if (voucherController.text == "GALON10") {
      setState(() {
        discount = 10000;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Voucher berhasil digunakan")),
      );
    } else {
      setState(() {
        discount = 0;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Voucher tidak valid")));
    }
  }

  Future<void> checkout() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    int total = cartProvider.total - discount;

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/orders"),

      headers: {"Content-Type": "application/json"},

      body: jsonEncode({
        "user_id": user.uid,
        "payment_method_id": 1,
        "total": total,

        "items": cartProvider.items.map((item) {
          return {
            "product_id": item.product.id,
            "qty": item.quantity,
            "subtotal": item.product.price * item.quantity,
          };
        }).toList(),
      }),
    );

    if (response.statusCode == 200) {
      cartProvider.clearCart();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Checkout berhasil")));

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Checkout gagal")));
    }
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
                          const Text(
                            "Informasi Customer",

                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 15),

                          ListTile(
                            leading: const Icon(Icons.person),

                            title: Text(profile?["name"] ?? "Belum diisi"),
                          ),

                          ListTile(
                            leading: const Icon(Icons.phone),

                            title: Text(profile?["phone"] ?? "Belum diisi"),
                          ),

                          ListTile(
                            leading: const Icon(Icons.location_on),

                            title: Text(profile?["address"] ?? "Belum diisi"),
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
                      onPressed: checkout,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],

                        foregroundColor: Colors.white,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),

                      child: const Text(
                        "Buat Pesanan",

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
}
