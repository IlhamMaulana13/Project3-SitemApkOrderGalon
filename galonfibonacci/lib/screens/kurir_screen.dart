import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:galonfibonacci/screens/login_screen.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:galonfibonacci/api_config.dart';

class KurirScreen extends StatefulWidget {
  const KurirScreen({super.key});

  @override
  State<KurirScreen> createState() => _KurirScreenState();
}

class _KurirScreenState extends State<KurirScreen> {
  List orders = [];

  @override
  void initState() {
    super.initState();

    fetchOrders();
  }

  Future<void> fetchOrders() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/kurir/orders"),
      );

      if (response.statusCode == 200) {
        print(response.body);

        final data = jsonDecode(response.body);

        if (data is List) {
          setState(() {
            orders = data;
          });
        } else {
          setState(() {
            orders = [];
          });
        }
      } else {
        setState(() {
          orders = [];
        });

        print(response.body);
      }
    } catch (e) {
      print(e);

      setState(() {
        orders = [];
      });
    }
  }

  Future<void> openWhatsApp(String phone, String name, int orderId) async {
    String cleanPhone = phone;

    if (cleanPhone.startsWith("0")) {
      cleanPhone = "62${cleanPhone.substring(1)}";
    }

    final message = Uri.encodeComponent(
      "Hallo Selamat Siang Bapak/Ibu $name, "
      "Kurir Galon Rajeg Bahagia sedang dalam perjalanan menuju lokasi "
      "untuk mengantarkan pesanan anda dengan nomor order #$orderId. "
      "Mohon ditunggu ya 🙏\n\n"
      "Terima kasih.",
    );

    final Uri url = Uri.parse("https://wa.me/$cleanPhone?text=$message");

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> updateStatus(int id, String status) async {
    await http.put(
      Uri.parse("${ApiConfig.baseUrl}/orders/status/$id"),

      headers: {"Content-Type": "application/json"},

      body: jsonEncode({"status": status}),
    );

    fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Dashboard Kurir",
          style: TextStyle(color: Colors.white),
        ),

        backgroundColor: Colors.orange,

        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),

            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,

                MaterialPageRoute(builder: (_) => const LoginScreen()),

                (route) => false,
              );
            },
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: fetchOrders,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index] as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),

              child: Padding(
                padding: const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      "Pesanan #${order["id"]}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text("Nama: ${order["name"] ?? "-"}"),
                    Text("No HP: ${order["phone"] ?? "-"}"),
                    Text("Alamat: ${order["address"] ?? "-"}"),

                    const SizedBox(height: 10),

                    Text(
                      "Total: Rp ${order["total"]}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Text(order["status"] ?? "-"),
                    ),

                    const SizedBox(height: 15),

                    DropdownButton<String>(
                      value: order["status"],

                      isExpanded: true,

                      items: const [
                        DropdownMenuItem(
                          value: "Diproses",
                          child: Text("Diproses"),
                        ),

                        DropdownMenuItem(
                          value: "Dikirim",
                          child: Text("Dikirim"),
                        ),

                        DropdownMenuItem(
                          value: "Selesai",
                          child: Text("Selesai"),
                        ),
                      ],

                      onChanged: (value) {
                        if (value != null) {
                          updateStatus(order["id"], value);
                        }
                      },
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,

                      child: ElevatedButton.icon(
                        onPressed: () {
                          openWhatsApp(
                            order["phone"],
                            order["name"],
                            order["id"],
                          );
                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),

                        icon: const Icon(Icons.chat),

                        label: const Text("Hubungi Customer"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
