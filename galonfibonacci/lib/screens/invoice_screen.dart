import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:galonfibonacci/api_config.dart';

class InvoiceScreen extends StatefulWidget {
  final int orderId;

  const InvoiceScreen({super.key, required this.orderId});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  Map<String, dynamic>? invoice;

  @override
  void initState() {
    super.initState();
    fetchInvoice();
  }

  Future<void> fetchInvoice() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/orders/detail/${widget.orderId}"),
    );

    if (response.statusCode == 200) {
      setState(() {
        invoice = jsonDecode(response.body);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (invoice == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final items = invoice!['items'];

    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: Text(
          "Invoice #${invoice!['id']}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Padding(
        padding: const EdgeInsets.all(15),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      "Status: ${invoice!['status']}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "Total: Rp ${invoice!['total']}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Daftar Item",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: items.length,

                itemBuilder: (context, index) {
                  final item = items[index];

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text("${item['qty']}x")),

                      title: Text(item['merk']),

                      subtitle: Text("Subtotal Rp ${item['subtotal']}"),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
