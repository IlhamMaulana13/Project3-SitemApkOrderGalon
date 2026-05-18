import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:galonfibonacci/provider/cart_provider.dart';
import 'package:galonfibonacci/screens/edit_profile_screen.dart';
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

  int selectedPaymentMethodId = 1;
  String selectedPaymentChannel = "BCA";

  final String qrisCode = "QRIS-1234-5678-9012";

  final Map<String, String> transferVaCodes = {
    "BCA": "7001234567890123",
    "SeaBank": "8001234567890123",
    "GoPay": "9001234567890123",
  };

  final List<Map<String, dynamic>> paymentMethods = [
    {"id": 1, "label": "QRIS", "subtitle": "Bayar cepat dengan scan QRIS"},
    {
      "id": 2,
      "label": "Transfer Bank",
      "subtitle": "Pilih bank / e-wallet untuk transfer",
    },
    {"id": 3, "label": "COD", "subtitle": "Bayar saat pesanan diterima"},
  ];

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

  Future<void> showQrisDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("QRIS"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.qr_code, size: 120, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Scan QRIS di atas untuk menyelesaikan pembayaran.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SelectableText(
                qrisCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            ),
          ],
        );
      },
    );
  }

  Future<void> showPaymentResultDialog(int paymentMethodId) async {
    if (!mounted) return;

    final title = paymentMethodId == 1
        ? "Bayar dengan QRIS"
        : paymentMethodId == 2
        ? "Transfer ${selectedPaymentChannel}"
        : "Cash on Delivery";

    final subtitle = paymentMethodId == 1
        ? "Tekan tombol QRIS untuk menampilkan kode pembayaran"
        : paymentMethodId == 2
        ? "Gunakan kode VA berikut untuk melakukan transfer"
        : "Bayar di tempat saat pesanan diterima";

    final selectedVaCode = selectedPaymentMethodId == 2
        ? transferVaCodes[selectedPaymentChannel] ??
              transferVaCodes.values.first
        : null;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle),
              const SizedBox(height: 20),
              if (paymentMethodId == 2 && selectedVaCode != null)
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        selectedVaCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: selectedVaCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Kode VA disalin")),
                        );
                      },
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
            ],
          ),
          actions: [
            if (paymentMethodId == 1)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  showQrisDialog();
                },
                child: const Text("Tampilkan QRIS"),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            ),
          ],
        );
      },
    );
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
        "payment_method_id": selectedPaymentMethodId,
        "payment_channel": selectedPaymentMethodId == 2
            ? selectedPaymentChannel
            : selectedPaymentMethodId == 1
            ? "QRIS"
            : "COD",
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

      await showPaymentResultDialog(selectedPaymentMethodId);

      if (!mounted) return;
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
                          const SizedBox(height: 12),
                          ...paymentMethods.map((method) {
                            final isSelected =
                                selectedPaymentMethodId == method["id"];
                            return Card(
                              color: isSelected
                                  ? Colors.blue.shade50
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                                ),
                              ),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: RadioListTile<int>(
                                value: method["id"],
                                groupValue: selectedPaymentMethodId,
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    selectedPaymentMethodId = value;
                                    if (value != 2) {
                                      selectedPaymentChannel = "BCA";
                                    }
                                  });
                                },
                                title: Text(
                                  method["label"] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.blue[900]
                                        : Colors.black87,
                                  ),
                                ),
                                subtitle: Text(method["subtitle"] as String),
                                activeColor: Colors.blue[700],
                              ),
                            );
                          }).toList(),
                          if (selectedPaymentMethodId == 2)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: DropdownButtonFormField<String>(
                                value: selectedPaymentChannel,
                                decoration: InputDecoration(
                                  labelText: "Pilih Bank / E-Wallet",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: transferVaCodes.keys.map((channel) {
                                  return DropdownMenuItem(
                                    value: channel,
                                    child: Text(channel),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    selectedPaymentChannel = value;
                                  });
                                },
                              ),
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
