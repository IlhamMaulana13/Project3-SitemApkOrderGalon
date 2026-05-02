import 'package:flutter/material.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Admin Panel",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      ),

      body: const Center(
        child: Text(
          "HALAMAN ADMIN",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}