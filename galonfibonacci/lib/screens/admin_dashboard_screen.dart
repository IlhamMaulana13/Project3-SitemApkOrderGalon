import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:galonfibonacci/screens/admin_order_screen.dart';
import 'package:galonfibonacci/screens/admin_product_screen.dart';
import 'package:http/http.dart' as http;

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? dashboard;

  @override
  void initState() {
    super.initState();

    fetchDashboard();
  }

  Future<void> fetchDashboard() async {
    final response = await http.get(
      Uri.parse("http://192.168.1.5:8080/dashboard"),
    );

    if (response.statusCode == 200) {
      setState(() {
        dashboard = jsonDecode(response.body);
      });
    }
  }

  Widget buildCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: Colors.blue[700], size: 35),

          const SizedBox(height: 15),

          Text(title, style: TextStyle(color: Colors.grey[600])),

          const SizedBox(height: 8),

          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text(
          "Dashboard Admin",
          style: TextStyle(color: Colors.white),
        ),

        backgroundColor: Colors.blue[700],
      ),

      body: dashboard == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),

                    crossAxisCount: 2,

                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,

                    childAspectRatio: 0.9,

                    children: [
                      buildCard(
                        "Total Order",
                        dashboard!["total_orders"].toString(),
                        Icons.receipt_long,
                      ),

                      buildCard(
                        "Pendapatan",
                        "Rp ${dashboard!["total_revenue"]}",
                        Icons.attach_money,
                      ),

                      buildCard(
                        "Produk",
                        dashboard!["total_products"].toString(),
                        Icons.inventory,
                      ),

                      buildCard(
                        "Customer",
                        dashboard!["total_customers"].toString(),
                        Icons.people,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "Menu Admin",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),

                    crossAxisCount: 2,

                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,

                    childAspectRatio: 1.1,

                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminProductScreen(),
                            ),
                          );
                        },

                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),

                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,

                            children: [
                              Icon(
                                Icons.inventory,
                                size: 40,
                                color: Colors.blue[700],
                              ),

                              const SizedBox(height: 10),

                              const Text(
                                "Kelola Produk",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),

                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminOrderScreen(),
                            ),
                          );
                        },

                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),

                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,

                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 40,
                                color: Colors.orange,
                              ),

                              const SizedBox(height: 10),

                              const Text(
                                "Kelola Pesanan",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "Produk Terlaris",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  ...dashboard!["best_products"].map<Widget>((item) {
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],

                          child: Icon(
                            Icons.local_drink,
                            color: Colors.blue[700],
                          ),
                        ),

                        title: Text(item["merk"]),

                        trailing: Text(
                          "${item["total"]} terjual",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}
