import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            const SizedBox(height: 20),

            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.blue[100],

              child: Icon(
                Icons.person,
                size: 50,
                color: Colors.blue[700],
              ),
            ),

            const SizedBox(height: 15),

            Text(
              user?.email ?? "Guest Mode",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text("Alamat"),
                subtitle: const Text(
                  "Belum diisi",
                ),
              ),
            ),

            Card(
              child: ListTile(
                leading: const Icon(Icons.phone),
                title: const Text("Nomor HP"),
                subtitle: const Text(
                  "Belum diisi",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}