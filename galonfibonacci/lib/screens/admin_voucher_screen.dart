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

  final Set<int> selectedVoucherIds = {};

  final discountController = TextEditingController();

  final assignEmailController = TextEditingController();

  bool assignToAllCustomers = true;

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

      body: jsonEncode({"discount": int.parse(discountController.text)}),
    );

    if (response.statusCode == 200) {
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

  void toggleVoucherSelected(int id) {
    setState(() {
      if (selectedVoucherIds.contains(id)) {
        selectedVoucherIds.remove(id);
      } else {
        selectedVoucherIds.add(id);
      }
    });
  }

  Future<void> assignSelectedVoucher() async {
    if (selectedVoucherIds.isEmpty) {
      return;
    }

    if (selectedVoucherIds.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pilih maksimal 1 voucher untuk diberikan."),
        ),
      );

      return;
    }

    final selectedVoucher = vouchers.firstWhere(
      (voucher) => voucher["id"] == selectedVoucherIds.first,

      orElse: () => null,
    );

    if (selectedVoucher == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Voucher tidak ditemukan.")));

      return;
    }

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/user-vouchers/assign"),

      headers: {"Content-Type": "application/json"},

      body: jsonEncode({
        "assign_all": assignToAllCustomers,

        "email": assignToAllCustomers
            ? null
            : assignEmailController.text.trim(),

        "voucher_codes": [selectedVoucher["code"]],
      }),
    );

    if (response.statusCode == 200) {
      selectedVoucherIds.clear();

      assignEmailController.clear();

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Voucher berhasil diberikan.")),
      );
    } else {
      final body = jsonDecode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body["error"] ?? "Gagal memberikan voucher.")),
      );
    }
  }

  void showAssignDialog() {
    if (selectedVoucherIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih voucher yang ingin diberikan.")),
      );

      return;
    }

    if (selectedVoucherIds.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih maksimal 1 voucher.")),
      );

      return;
    }

    showDialog(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: const Text("Berikan Voucher"),

          content: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Text(
                    "Pilih target pemberian voucher.",
                    style: TextStyle(fontSize: 14),
                  ),

                  const SizedBox(height: 15),

                  RadioListTile<bool>(
                    value: true,

                    groupValue: assignToAllCustomers,

                    title: const Text("Semua Customer"),

                    onChanged: (value) {
                      setModalState(() {
                        assignToAllCustomers = value!;
                      });
                    },
                  ),

                  RadioListTile<bool>(
                    value: false,

                    groupValue: assignToAllCustomers,

                    title: const Text("Customer Tertentu"),

                    onChanged: (value) {
                      setModalState(() {
                        assignToAllCustomers = value!;
                      });
                    },
                  ),

                  if (!assignToAllCustomers)
                    TextField(
                      controller: assignEmailController,

                      keyboardType: TextInputType.emailAddress,

                      decoration: const InputDecoration(
                        labelText: "Email Customer",
                      ),
                    ),
                ],
              );
            },
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text("Batal"),
            ),

            ElevatedButton(
              onPressed: () {
                if (!assignToAllCustomers &&
                    assignEmailController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Masukkan email customer.")),
                  );

                  return;
                }

                assignSelectedVoucher();
              },

              child: const Text("Kirim"),
            ),
          ],
        );
      },
    );
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
              const Text(
                "Kode voucher dibuat otomatis.",
                style: TextStyle(fontSize: 14),
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

      body: Padding(
        padding: const EdgeInsets.all(15),

        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: vouchers.length,

                itemBuilder: (context, index) {
                  final voucher = vouchers[index];

                  final isSelected = selectedVoucherIds.contains(voucher["id"]);

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: ListTile(
                      leading: Checkbox(
                        value: isSelected,

                        onChanged: (_) {
                          toggleVoucherSelected(voucher["id"] as int);
                        },
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

                      onTap: () {
                        toggleVoucherSelected(voucher["id"] as int);
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: showAssignDialog,

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                ),

                child: const Text("Berikan ke Customer"),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
