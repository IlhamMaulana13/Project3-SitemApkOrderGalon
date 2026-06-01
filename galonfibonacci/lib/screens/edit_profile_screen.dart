import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:galonfibonacci/api_config.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  // =========================
  // AMBIL DATA PROFILE
  // =========================
  Future<void> fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/profile/${user.uid}"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        nameController.text = data["name"] ?? "";
        phoneController.text = data["phone"] ?? "";
        addressController.text = data["address"] ?? "";
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  // =========================
  // SAVE PROFILE
  // =========================
  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/profile"),

      headers: {"Content-Type": "application/json"},

      body: jsonEncode({
        "firebase_uid": user.uid,
        "email": user.email,
        "name": nameController.text,
        "phone": phoneController.text,
        "address": addressController.text,
      }),
    );

    if (response.statusCode == 200) {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,

        builder: (_) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),

            content: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 80),

                const SizedBox(height: 20),

                const Text(
                  "PROFIL BERHASIL DIPERBARUI",
                  textAlign: TextAlign.center,

                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),

                    child: const Text("OK"),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Ubah Profil",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),

              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: "Nama Lengkap",
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,

                    decoration: const InputDecoration(labelText: "Nomor HP"),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: addressController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: "Alamat"),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,

                    child: ElevatedButton(
                      onPressed: saveProfile,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),

                      child: const Text("Simpan Profil"),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
