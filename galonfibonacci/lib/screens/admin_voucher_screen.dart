import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:galonfibonacci/api_config.dart';

class AdminVoucherScreen extends StatefulWidget {
  const AdminVoucherScreen({super.key});

  @override
  State<AdminVoucherScreen> createState() => _AdminVoucherScreenState();
}

class _AdminVoucherScreenState extends State<AdminVoucherScreen> {
  List vouchers = [];

  final codeController = TextEditingController();
  final discountController = TextEditingController();

  @override
  void initState() {
    super.initState();

    fetchVouchers();
  }

  Future<void> fetchVouchers() async {
    final response = await http.get(Uri.parse("${ApiConfig.baseUrl}/vouchers"));

    if (response.statusCode == 200) {
      setState(() {
        vouchers = jsonDecode(response.body);
      });
    }
  }

  Future<void> createVoucher() async {
    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/vouchers"),

      headers: {"Content-Type": "application/json"},

      body: jsonEncode({
        "code": codeController.text,
        "discount": int.parse(discountController.text),
      }),
    );

    if (response.statusCode == 200) {
      codeController.clear();
      discountController.clear();

      Navigator.pop(context);

      fetchVouchers();
    }
  }

  Future<void> deleteVoucher(int id) async {
    final response = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/vouchers/$id"),
    );

    if (response.statusCode == 200) {
      fetchVouchers();
    }
  }

  void showVoucherDialog() {
    showDialog(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: const Text("Tambah Voucher"),

          content: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              TextField(
                controller: codeController,

                decoration: const InputDecoration(labelText: "Kode Voucher"),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: discountController,
                keyboardType: TextInputType.number,

                decoration: const InputDecoration(labelText: "Potongan"),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text("Batal"),
            ),

            ElevatedButton(
              onPressed: createVoucher,

              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text(
          "Kelola Voucher",
          style: TextStyle(color: Colors.white),
        ),

        backgroundColor: Colors.blue[700],

        iconTheme: const IconThemeData(color: Colors.white),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: showVoucherDialog,

        backgroundColor: Colors.blue[700],

        child: const Icon(Icons.add, color: Colors.white),
      ),

      body: ListView.builder(
        padding: const EdgeInsets.all(15),

        itemCount: vouchers.length,

        itemBuilder: (context, index) {
          final voucher = vouchers[index];

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),

            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],

                child: Icon(Icons.discount, color: Colors.blue[700]),
              ),

              title: Text(
                voucher["code"],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              subtitle: Text("Potongan Rp ${voucher["discount"]}"),

              trailing: IconButton(
                onPressed: () {
                  deleteVoucher(voucher["id"]);
                },

                icon: const Icon(Icons.delete, color: Colors.red),
              ),
            ),
          );
        },
      ),
    );
  }
}
