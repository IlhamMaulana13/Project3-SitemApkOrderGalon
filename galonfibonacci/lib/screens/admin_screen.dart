import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:galonfibonacci/api_config.dart';
import 'package:galonfibonacci/provider/theme_provider.dart';
import 'package:galonfibonacci/screens/admin_order_screen.dart';
import 'package:galonfibonacci/screens/admin_product_screen.dart';
import 'package:galonfibonacci/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final String baseUrl = ApiConfig.baseUrl;
  int newOrderCount = 0;
  bool isLoadingOrders = true;

  @override
  void initState() {
    super.initState();
    fetchNewOrderCount();
  }

  Future<void> fetchNewOrderCount() async {
    setState(() {
      isLoadingOrders = true;
    });

    try {
      final response = await http.get(Uri.parse("$baseUrl/orders"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          final count = data.where((order) {
            final status = (order["status"] ?? "").toString();
            return status == "Diproses";
          }).length;
          if (mounted) {
            setState(() {
              newOrderCount = count;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("fetchNewOrderCount error: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoadingOrders = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Dashboard Admin",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),

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
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },

            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            // MENU PRODUK
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),

              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDark ? Colors.blue[900] : Colors.blue[100],

                  child: Icon(Icons.inventory_2, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                ),

                title: const Text(
                  "Kelola Produk",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                subtitle: const Text("Tambah, edit, hapus produk"),

                trailing: const Icon(Icons.arrow_forward_ios),

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminProductScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 15),

            // MENU ORDER
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),

              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDark ? Colors.orange[900] : Colors.orange[100],

                  child: Icon(Icons.receipt_long, color: isDark ? Colors.orange[300] : Colors.orange[700]),
                ),

                title: const Text(
                  "Orderan Baru",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                subtitle: Text(
                  isLoadingOrders
                      ? "Memuat order baru..."
                      : (newOrderCount > 0
                            ? "$newOrderCount orderan baru menunggu"
                            : "Belum ada orderan baru"),
                ),

                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isLoadingOrders && newOrderCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          newOrderCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    const Icon(Icons.arrow_forward_ios),
                  ],
                ),

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminOrderScreen()),
                  ).then((_) => fetchNewOrderCount());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
