import 'package:flutter/material.dart';

class KurirScreen extends StatelessWidget {
  const KurirScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Kurir Panel",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),

      body: const Center(
        child: Text(
          "HALAMAN KURIR",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}