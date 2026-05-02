import 'package:flutter/material.dart';
import 'package:galonfibonacci/screens/invoice_screen.dart';

import '../models/order_model.dart';
import '../services/api_service.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  List<OrderModel> orders = [];

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
  void initState() {
    super.initState();
    fetchOrders();
  }

  void fetchOrders() async {
    final result = await ApiService.getOrders();

    setState(() {
      orders = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: orders.length,

        itemBuilder: (context, index) {
          final order = orders[index];

          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceScreen(orderId: order.id),
                ),
              );
            },

            child: Card(
              margin: const EdgeInsets.only(bottom: 15),

              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text("#${order.id}"),
                ),

                title: Text(
                  "Rp ${order.total}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: getStatusColor(order.status),
                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Text(
                        order.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    Text(order.createdAt, style: const TextStyle(fontSize: 12)),
                  ],
                ),

                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: Text(
                    order.status,
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
