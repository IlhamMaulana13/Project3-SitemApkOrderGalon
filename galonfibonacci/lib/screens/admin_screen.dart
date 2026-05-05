import 'package:flutter/material.dart';
import 'package:galonfibonacci/screens/admin_order_screen.dart';
import 'package:galonfibonacci/screens/admin_product_screen.dart';
import 'package:galonfibonacci/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        backgroundColor: Colors.blue[700],

        title: const Text(
          "Dashboard Admin",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),

        actions: [
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
                  backgroundColor: Colors.blue[100],

                  child: Icon(Icons.inventory_2, color: Colors.blue[700]),
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
                  backgroundColor: Colors.orange[100],

                  child: Icon(Icons.receipt_long, color: Colors.orange[700]),
                ),

                title: const Text(
                  "Kelola Pesanan",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                subtitle: const Text("Update status pesanan"),

                trailing: const Icon(Icons.arrow_forward_ios),

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminOrderScreen()),
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
