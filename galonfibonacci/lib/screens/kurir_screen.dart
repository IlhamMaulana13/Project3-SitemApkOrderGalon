import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:galonfibonacci/provider/theme_provider.dart';
import 'package:galonfibonacci/screens/login_screen.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:galonfibonacci/api_config.dart';

class KurirScreen extends StatefulWidget {
  const KurirScreen({super.key});

  @override
  State<KurirScreen> createState() => _KurirScreenState();
}

class _KurirScreenState extends State<KurirScreen> {
  List orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    fetchOrders();
  }

  Future<void> fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/kurir/orders"),
      );

      if (response.statusCode == 200) {
        print(response.body);

        final data = jsonDecode(response.body);

        if (data is List) {
          setState(() {
            orders = data;
            _isLoading = false;
          });
        } else {
          setState(() {
            orders = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          orders = [];
          _isLoading = false;
        });

        print(response.body);
      }
    } catch (e) {
      print(e);

      setState(() {
        orders = [];
        _isLoading = false;
      });
    }
  }

  Future<void> openWhatsApp(String phone, String name, int orderId) async {
    String cleanPhone = phone;

    if (cleanPhone.startsWith("0")) {
      cleanPhone = "62${cleanPhone.substring(1)}";
    }

    final message = Uri.encodeComponent(
      "Hallo Selamat Siang Bapak/Ibu $name, "
      "Kurir Galon Rajeg Bahagia sedang dalam perjalanan menuju lokasi "
      "untuk mengantarkan pesanan anda dengan nomor order #$orderId. "
      "Mohon ditunggu ya 🙏\n\n"
      "Terima kasih.",
    );

    final Uri url = Uri.parse("https://wa.me/$cleanPhone?text=$message");

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // Urutan status pesanan. Status hanya boleh maju satu arah dan
  // tidak dapat dikembalikan ke status sebelumnya (bersifat tetap).
  static const List<String> statusFlow = ["Diproses", "Dikirim", "Selesai"];

  // Status berikutnya dari [current], atau null jika sudah "Selesai".
  String? nextStatusOf(String current) {
    final idx = statusFlow.indexOf(current);
    if (idx == -1) return statusFlow.first;
    if (idx >= statusFlow.length - 1) return null;
    return statusFlow[idx + 1];
  }

  Future<bool> updateStatus(int id, String status) async {
    final response = await http.put(
      Uri.parse("${ApiConfig.baseUrl}/orders/status/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"status": status}),
    );

    if (response.statusCode == 200) {
      if (mounted) {
        fetchOrders();
      }
      return true;
    }

    return false;
  }

  Future<void> uploadProof(int orderId) async {
    final picker = ImagePicker();

    try {
      final cameraFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (cameraFile != null) {
        final bytes = await File(cameraFile.path).readAsBytes();
        final base64Image = base64Encode(bytes);

        final response = await http.post(
          Uri.parse("${ApiConfig.baseUrl}/orders/$orderId/proof"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "proof_photo": "data:image/jpeg;base64,$base64Image",
          }),
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Bukti foto berhasil dikirim"),
              backgroundColor: Colors.green,
            ),
          );
          fetchOrders();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Bukti foto gagal dikirim"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    } catch (_) {
      // Fallback ke galeri jika kamera tidak tersedia.
    }

    try {
      final galleryFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (galleryFile == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Bukti foto dibatalkan")));
        return;
      }

      final bytes = await File(galleryFile.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/orders/$orderId/proof"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "proof_photo": "data:image/jpeg;base64,$base64Image",
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bukti foto berhasil dikirim"),
            backgroundColor: Colors.green,
          ),
        );
        fetchOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bukti foto gagal dikirim"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal mengakses foto: $e")));
    }
  }

  Widget _buildProofPreview(String? proofPhoto) {
    if (proofPhoto == null || proofPhoto.toString().trim().isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      final value = proofPhoto.toString();
      final base64Data = value.contains(',') ? value.split(',').last : value;
      final bytes = base64Decode(base64Data);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            "Bukti lokasi:",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  // Konfirmasi sebelum mengubah status karena perubahan bersifat permanen.
  Future<void> confirmUpdateStatus(int orderId, String nextStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ubah Status Pesanan"),
        content: Text(
          "Ubah status pesanan menjadi \"$nextStatus\"?\n\n"
          "Perubahan status bersifat tetap dan tidak dapat dikembalikan.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text("Ubah ke $nextStatus"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updated = await updateStatus(orderId, nextStatus);
      if (updated && nextStatus == "Selesai" && mounted) {
        await uploadProof(orderId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Dashboard Kurir",
          style: TextStyle(color: Colors.white),
        ),

        backgroundColor: Colors.orange,

        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) => IconButton(
              icon: Icon(
                themeProvider.isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: Colors.white,
              ),
              tooltip: themeProvider.isDarkMode ? 'Mode Terang' : 'Mode Gelap',
              onPressed: () => themeProvider.toggleTheme(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),

            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,

                MaterialPageRoute(builder: (_) => const LoginScreen()),

                (route) => false,
              );
            },
          ),
        ],
      ),

      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text(
                    "Memuat pesanan...",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchOrders,
              child: orders.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        return ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.75,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.orange.withValues(
                                              alpha: 0.15,
                                            )
                                          : Colors.orange.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.delivery_dining_rounded,
                                      size: 64,
                                      color: isDark
                                          ? Colors.orange.shade300
                                          : Colors.orange.shade300,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    "Belum Ada Pesanan",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Pesanan baru akan muncul di sini.\nTarik ke bawah untuk memperbarui.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  OutlinedButton.icon(
                                    onPressed: fetchOrders,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.orange,
                                    ),
                                    label: const Text(
                                      "Perbarui",
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.orange,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index] as Map<String, dynamic>;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),

                          child: Padding(
                            padding: const EdgeInsets.all(16),

                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  "Pesanan #${order["id"]}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                Text("Nama: ${order["name"] ?? "-"}"),
                                Text("No HP: ${order["phone"] ?? "-"}"),
                                Text("Alamat: ${order["address"] ?? "-"}"),

                                const SizedBox(height: 10),

                                Text(
                                  "Total: Rp ${order["total"]}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                Builder(
                                  builder: (ctx) {
                                    final isDark =
                                        Theme.of(ctx).brightness ==
                                        Brightness.dark;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.orange.withValues(
                                                alpha: 0.25,
                                              )
                                            : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        order["status"] ?? "-",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.orange[300]
                                              : Colors.orange[900],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 15),

                                _buildProofPreview(
                                  order["proof_photo"]?.toString(),
                                ),

                                const SizedBox(height: 12),

                                Builder(
                                  builder: (context) {
                                    final currentStatus =
                                        (order["status"] ?? "").toString();
                                    final nextStatus = nextStatusOf(
                                      currentStatus,
                                    );

                                    if (nextStatus == null) {
                                      final isDark =
                                          Theme.of(context).brightness ==
                                          Brightness.dark;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.green.withValues(
                                                  alpha: 0.15,
                                                )
                                              : Colors.green[50],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.green.withValues(
                                                    alpha: 0.4,
                                                  )
                                                : Colors.green.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              color: isDark
                                                  ? Colors.green[400]
                                                  : Colors.green[700],
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "Pesanan sudah selesai",
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.green[400]
                                                    : Colors.green[700],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    return SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => confirmUpdateStatus(
                                          order["id"],
                                          nextStatus,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                        label: Text(
                                          "Ubah status ke \"$nextStatus\"",
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 10),

                                SizedBox(
                                  width: double.infinity,

                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      openWhatsApp(
                                        order["phone"],
                                        order["name"],
                                        order["id"],
                                      );
                                    },

                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),

                                    icon: const Icon(Icons.chat),

                                    label: const Text("Hubungi Customer"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
