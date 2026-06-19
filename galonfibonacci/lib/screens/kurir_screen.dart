import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:galonfibonacci/provider/theme_provider.dart';
import 'package:galonfibonacci/screens/login_screen.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:galonfibonacci/api_config.dart';

class KurirScreen extends StatefulWidget {
  const KurirScreen({super.key});

  @override
  State<KurirScreen> createState() => _KurirScreenState();
}

class _KurirScreenState extends State<KurirScreen> {
  List orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    fetchOrders();
  }

  Future<void> fetchOrders() async {
    setState(() => _isLoading = true);
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
            _isLoading = false;
          });
        } else {
          setState(() {
            orders = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          orders = [];
          _isLoading = false;
        });

        print(response.body);
      }
    } catch (e) {
      print(e);

      setState(() {
        orders = [];
        _isLoading = false;
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
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) => IconButton(
              icon: Icon(
                themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: Colors.white,
              ),
              tooltip: themeProvider.isDarkMode ? 'Mode Terang' : 'Mode Gelap',
              onPressed: () => themeProvider.toggleTheme(),
            ),
          ),
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

      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text(
                    "Memuat pesanan...",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchOrders,
              child: orders.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.75,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.orange.withValues(alpha: 0.15)
                                          : Colors.orange.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.delivery_dining_rounded,
                                      size: 64,
                                      color: isDark
                                          ? Colors.orange.shade300
                                          : Colors.orange.shade300,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    "Belum Ada Pesanan",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Pesanan baru akan muncul di sini.\nTarik ke bawah untuk memperbarui.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  OutlinedButton.icon(
                                    onPressed: fetchOrders,
                                    icon: const Icon(Icons.refresh_rounded, color: Colors.orange),
                                    label: const Text(
                                      "Perbarui",
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.orange),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : ListView.builder(
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

                    Builder(builder: (ctx) {
                      final isDark = Theme.of(ctx).brightness == Brightness.dark;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.orange.withValues(alpha: 0.25) : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          order["status"] ?? "-",
                          style: TextStyle(
                            color: isDark ? Colors.orange[300] : Colors.orange[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 15),

                    Builder(builder: (context) {
                      final currentStatus = (order["status"] ?? "").toString();
                      final nextStatuses = ["Diproses", "Dikirim", "Selesai"]
                          .where((s) => s != currentStatus)
                          .toList();

                      if (nextStatuses.isEmpty) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: isDark ? Colors.green[400] : Colors.green[700], size: 18),
                              const SizedBox(width: 8),
                              Text(
                                "Pesanan sudah selesai",
                                style: TextStyle(
                                    color: isDark ? Colors.green[400] : Colors.green[700],
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }

                      return DropdownButton<String>(
                        value: null,
                        hint: Text(
                          "Ubah status...",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        isExpanded: true,
                        items: nextStatuses
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            updateStatus(order["id"], value);
                          }
                        },
                      );
                    }),

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
