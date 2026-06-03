import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:galonfibonacci/api_config.dart';
import 'package:galonfibonacci/screens/login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();

    fetchProfile();
  }

  Future<void> fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/profile/${user.uid}"),
    );

    if (response.statusCode == 200) {
      if (!mounted) return;

      setState(() {
        userData = jsonDecode(response.body);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 20),
                const Text(
                  "Anda belum login",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "Silakan login untuk mengakses halaman profil.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    child: const Text("Login Sekarang"),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: userData == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                      leading: const Icon(Icons.person),

                      title: const Text("Nama"),

                      subtitle: Text(userData?["name"] ?? "Belum diisi"),
                    ),
                  ),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.phone),

                      title: const Text("Nomor HP"),

                      subtitle: Text(userData?["phone"] ?? "Belum diisi"),
                    ),
                  ),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on),

                      title: const Text("Alamat"),

                      subtitle: Text(userData?["address"] ?? "Belum diisi"),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,

                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        );

                        fetchProfile();
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],

                        foregroundColor: Colors.white,
                      ),

                      child: const Text("Ubah Profil"),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
