import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminOrderScreen extends StatefulWidget {
  const AdminOrderScreen({super.key});

  @override
  State<AdminOrderScreen> createState() =>
      _AdminOrderScreenState();
}

class _AdminOrderScreenState
    extends State<AdminOrderScreen> {

  List orders = [];

  final String baseUrl =
      "http://192.168.1.5:8080";

  @override
  void initState() {
    super.initState();

    fetchOrders();
  }

  // GET ALL ORDERS
  Future<void> fetchOrders() async {

    final response = await http.get(
      Uri.parse("$baseUrl/orders"),
    );

    if (response.statusCode == 200) {

      setState(() {
        orders = jsonDecode(response.body);
      });
    }
  }

  // UPDATE STATUS
  Future<void> updateStatus(
    int orderId,
    String status,
  ) async {

    final response = await http.put(

      Uri.parse(
        "$baseUrl/orders/status/$orderId",
      ),

      headers: {
        "Content-Type":
            "application/json",
      },

      body: jsonEncode({
        "status": status,
      }),
    );

    if (response.statusCode == 200) {

      fetchOrders();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Status berhasil diupdate",
          ),
        ),
      );
    }
  }

  // STATUS COLOR
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
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.grey[100],

      appBar: AppBar(

        title: const Text(
          "Kelola Pesanan",
          style: TextStyle(
            color: Colors.white,
          ),
        ),

        backgroundColor: Colors.blue[700],

        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),

      body: ListView.builder(

        padding: const EdgeInsets.all(15),

        itemCount: orders.length,

        itemBuilder: (context, index) {

          final order = orders[index];

          return Card(

            margin:
                const EdgeInsets.only(
              bottom: 15,
            ),

            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),

            child: Padding(

              padding:
                  const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,

                    children: [

                      Text(
                        "Order #${order["id"]}",
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              getStatusColor(
                            order["status"],
                          ),

                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),

                        child: Text(
                          order["status"],

                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: 10),

                  Text(
                    "Total: Rp ${order["total"]}",
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(
                      height: 5),

                  Text(
                    order["created_at"],
                    style: TextStyle(
                      color:
                          Colors.grey[600],
                    ),
                  ),

                  const SizedBox(
                      height: 15),

                  DropdownButtonFormField<String>(

                    value:
                        order["status"],

                    decoration:
                        InputDecoration(
                      filled: true,

                      fillColor:
                          Colors.grey[100],

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                    ),

                    items: const [

                      DropdownMenuItem(
                        value:
                            "Diproses",

                        child: Text(
                          "Diproses",
                        ),
                      ),

                      DropdownMenuItem(
                        value:
                            "Dikirim",

                        child: Text(
                          "Dikirim",
                        ),
                      ),

                      DropdownMenuItem(
                        value:
                            "Selesai",

                        child: Text(
                          "Selesai",
                        ),
                      ),
                    ],

                    onChanged: (value) {

                      if (value != null) {

                        updateStatus(
                          order["id"],
                          value,
                        );
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