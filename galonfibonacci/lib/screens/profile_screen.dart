import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
      Uri.parse("http://10.110.115.221:8080/profile/${user.uid}"),
    );

    if (response.statusCode == 200) {
      setState(() {
        userData = jsonDecode(response.body);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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

                      child: const Text("Edit Profile"),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
