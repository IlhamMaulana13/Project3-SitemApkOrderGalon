import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminOrderScreen extends StatefulWidget {
  const AdminOrderScreen({super.key});

  @override
  State<AdminOrderScreen> createState() => _AdminOrderScreenState();
}

class _AdminOrderScreenState extends State<AdminOrderScreen> {
  List orders = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    fetchOrders();
  }

  Future<void> fetchOrders() async {
    final response = await http.get(
      Uri.parse("http://192.168.1.5:8080/orders"),
    );

    if (response.statusCode == 200) {
      setState(() {
        orders = jsonDecode(response.body);

        isLoading = false;
      });
    }
  }

  Future<void> updateStatus(int id, String status) async {
    final response = await http.put(
      Uri.parse("http://192.168.1.5:8080/orders/status/$id"),

      headers: {"Content-Type": "application/json"},

      body: jsonEncode({"status": status}),
    );

    if (response.statusCode == 200) {
      fetchOrders();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Status order #$id diubah")));
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "Diproses":
        return Colors.orange;

      case "Dikirim":
        return Colors.blue;

      case "Sampai":
        return Colors.green;

      case "Selesai":
        return Colors.teal;

      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text(
          "Admin Pesanan",
          style: TextStyle(color: Colors.white),
        ),

        backgroundColor: Colors.blue[700],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(15),

              itemCount: orders.length,

              itemBuilder: (context, index) {
                final order = orders[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 15),

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
                            Text(
                              "Order #${order["id"]}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),

                              decoration: BoxDecoration(
                                color: getStatusColor(order["status"]),
                                borderRadius: BorderRadius.circular(20),
                              ),

                              child: Text(
                                order["status"],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Text(
                          "Total: Rp ${order["total"]}",
                          style: const TextStyle(fontSize: 16),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          order["created_at"],
                          style: TextStyle(color: Colors.grey[600]),
                        ),

                        const SizedBox(height: 15),

                        DropdownButtonFormField(
                          value: order["status"],

                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),

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
                              value: "Sampai",
                              child: Text("Sampai"),
                            ),

                            DropdownMenuItem(
                              value: "Selesai",
                              child: Text("Selesai"),
                            ),
                          ],

                          onChanged: (value) {
                            if (value != null) {
                              updateStatus(order["id"], value.toString());
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
