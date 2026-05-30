import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:galonfibonacci/api_config.dart';
import 'package:http/http.dart' as http;

class AdminRoleScreen extends StatefulWidget {
  const AdminRoleScreen({super.key});

  @override
  State<AdminRoleScreen> createState() => _AdminRoleScreenState();
}

class _AdminRoleScreenState extends State<AdminRoleScreen> {
  final String baseUrl = ApiConfig.baseUrl;

  static const List<String> roles = ["customer", "kurir", "kasir", "admin"];

  List users = [];
  bool isLoading = true;
  String search = "";

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  // GET SEMUA USER
  Future<void> fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("$baseUrl/users"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          users = data is List ? data : [];
        });
      }
    } catch (e) {
      debugPrint("fetchUsers error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // UPDATE ROLE
  Future<void> updateRole(String uid, String role) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/users/$uid/role"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"role": role}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        await fetchUsers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Role berhasil diubah menjadi $role"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["error"] ?? "Gagal mengubah role")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Terjadi kesalahan: $e")),
      );
    }
  }

  Color roleColor(String role) {
    switch (role) {
      case "admin":
        return Colors.blue;
      case "kasir":
        return Colors.teal;
      case "kurir":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData roleIcon(String role) {
    switch (role) {
      case "admin":
        return Icons.admin_panel_settings;
      case "kasir":
        return Icons.point_of_sale;
      case "kurir":
        return Icons.delivery_dining;
      default:
        return Icons.person;
    }
  }

  void confirmChangeRole(Map user, String newRole) {
    final currentRole = (user["role"] ?? "customer").toString();
    if (newRole == currentRole) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Ubah Role"),
        content: Text(
          "Ubah role \"${user["name"] ?? user["email"]}\" "
          "dari $currentRole menjadi $newRole?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              updateRole(user["firebase_uid"], newRole);
            },
            child: const Text("Ubah"),
          ),
        ],
      ),
    );
  }

  List get filteredUsers {
    if (search.isEmpty) return users;
    final q = search.toLowerCase();
    return users.where((u) {
      final name = (u["name"] ?? "").toString().toLowerCase();
      final email = (u["email"] ?? "").toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        title: const Text(
          "Kelola Role Pengguna",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              onChanged: (value) => setState(() => search = value),
              decoration: InputDecoration(
                hintText: "Cari nama atau email...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                ? const Center(child: Text("Tidak ada pengguna"))
                : RefreshIndicator(
                    onRefresh: fetchUsers,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        final role = (user["role"] ?? "customer").toString();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: roleColor(
                                        role,
                                      ).withOpacity(0.15),
                                      child: Icon(
                                        roleIcon(role),
                                        color: roleColor(role),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (user["name"] ?? "-").toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            (user["email"] ?? "-").toString(),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: roleColor(role).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        role,
                                        style: TextStyle(
                                          color: roleColor(role),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: roles.map((r) {
                                    final selected = r == role;
                                    return ChoiceChip(
                                      label: Text(r),
                                      selected: selected,
                                      selectedColor: roleColor(
                                        r,
                                      ).withOpacity(0.2),
                                      labelStyle: TextStyle(
                                        color: selected
                                            ? roleColor(r)
                                            : Colors.black87,
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      onSelected: (_) =>
                                          confirmChangeRole(user, r),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
