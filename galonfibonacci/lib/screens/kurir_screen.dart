import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  int _selectedTab = 0; // 0 = Aktif, 1 = Riwayat

  List get activeOrders => orders
      .where((o) => o["status"] == "Diproses" || o["status"] == "Dikirim")
      .toList();

  List get completedOrders =>
      orders.where((o) => o["status"] == "Selesai").toList();

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

            final activeCount = data
                .where(
                  (o) => o['status'] == 'Diproses' || o['status'] == 'Dikirim',
                )
                .length;
            final completedCount = data
                .where((o) => o['status'] == 'Selesai')
                .length;

            if (_selectedTab == 0 && activeCount == 0 && completedCount > 0) {
              _selectedTab = 1;
            }
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
        maxWidth: 1024,
        maxHeight: 1024,
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
        maxWidth: 1024,
        maxHeight: 1024,
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

  void _showImageDialog(BuildContext context, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index, int count) {
    final isSelected = _selectedTab == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.orange.shade800 : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.orange.shade900)
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                            ? Colors.orange.shade900
                            : Colors.orange.shade100)
                      : (isDark ? Colors.grey[800] : Colors.grey[300]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.orange.shade900)
                        : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
          InkWell(
            onTap: () => _showImageDialog(context, bytes),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    bytes,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        "Perbesar",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
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
        setState(() {
          _selectedTab = 1;
        });
        await uploadProof(orderId);
      }
    }
  }

  Widget _buildListContent() {
    final displayOrders = _selectedTab == 0 ? activeOrders : completedOrders;

    if (displayOrders.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.orange.withValues(alpha: 0.15)
                        : Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedTab == 0
                        ? Icons.delivery_dining_rounded
                        : Icons.history_rounded,
                    size: 50,
                    color: Colors.orange.shade300,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedTab == 0
                      ? "Belum Ada Pesanan Aktif"
                      : "Riwayat Kosong",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedTab == 0
                      ? "Pesanan baru untuk Anda akan muncul di sini."
                      : "Riwayat pesanan yang selesai akan muncul di sini.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayOrders.length,
      itemBuilder: (context, index) {
        final order = displayOrders[index] as Map<String, dynamic>;

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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (ctx) {
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.orange.withValues(alpha: 0.25)
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
                _buildProofPreview(order["proof_photo"]?.toString()),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final currentStatus = (order["status"] ?? "").toString();
                    final nextStatus = nextStatusOf(currentStatus);

                    if (nextStatus == null) {
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      final hasProof =
                          order["proof_photo"] != null &&
                          order["proof_photo"].toString().trim().isNotEmpty;
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.green.withValues(alpha: 0.4)
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
                                Expanded(
                                  child: Text(
                                    "Pesanan sudah selesai",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.green[400]
                                          : Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => uploadProof(order["id"]),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: hasProof ? Colors.grey : Colors.orange,
                                ),
                                foregroundColor: hasProof
                                    ? Colors.grey[700]
                                    : Colors.orange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              icon: Icon(
                                hasProof
                                    ? Icons.replay_rounded
                                    : Icons.camera_alt_rounded,
                                size: 18,
                              ),
                              label: Text(
                                hasProof
                                    ? "Ganti Foto Bukti"
                                    : "Ambil Foto Bukti (Wajib)",
                                style: TextStyle(
                                  fontWeight: hasProof
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            confirmUpdateStatus(order["id"], nextStatus),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text("Ubah status ke \"$nextStatus\""),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      openWhatsApp(order["phone"], order["name"], order["id"]);
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
    );
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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[900]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTabButton(
                            "Aktif",
                            0,
                            activeOrders.length,
                          ),
                        ),
                        Expanded(
                          child: _buildTabButton(
                            "Riwayat",
                            1,
                            completedOrders.length,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: fetchOrders,
                    child: _buildListContent(),
                  ),
                ),
              ],
            ),
    );
  }
}
