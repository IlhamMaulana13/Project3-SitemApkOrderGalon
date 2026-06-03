import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:galonfibonacci/api_config.dart';

class AdminVoucherScreen extends StatefulWidget {
  const AdminVoucherScreen({super.key});

  @override
  State<AdminVoucherScreen> createState() => _AdminVoucherScreenState();
}

class _AdminVoucherScreenState extends State<AdminVoucherScreen> {
  final String baseUrl = ApiConfig.baseUrl;

  List<Map<String, dynamic>> vouchers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchVouchers();
  }

  Future<void> fetchVouchers() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("$baseUrl/vouchers"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          vouchers = data is List ? List<Map<String, dynamic>>.from(data) : [];
        });
      }
    } catch (e) {
      debugPrint("fetchVouchers error: $e");
    }
    if (mounted) setState(() => isLoading = false);
  }

  // =========================
  // HAPUS VOUCHER
  // =========================
  Future<void> deleteVoucher(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Hapus Voucher"),
        content: Text(
          'Hapus voucher "${name.isNotEmpty ? name : "ini"}"?\n\nVoucher yang sudah diberikan ke pelanggan tidak terpengaruh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final response = await http.delete(Uri.parse("$baseUrl/vouchers/$id"));
    if (!mounted) return;

    if (response.statusCode == 200) {
      fetchVouchers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Voucher berhasil dihapus"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================
  // BUAT VOUCHER BARU
  // =========================
  void showCreateVoucherDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final discountController = TextEditingController();
    bool autoCode = true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.local_offer_rounded, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Buat Voucher Promo",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nama voucher
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: "Nama Voucher",
                      hintText: "Contoh: Promo Idul Fitri 2026",
                      prefixIcon: const Icon(Icons.label_rounded),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Kode voucher + toggle auto
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeController,
                          enabled: !autoCode,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: "Kode Voucher",
                            hintText: autoCode
                                ? "Digenerate otomatis"
                                : "Contoh: IDUL-FITRI",
                            prefixIcon: const Icon(
                              Icons.confirmation_number_rounded,
                            ),
                            filled: true,
                            fillColor: autoCode
                                ? Colors.grey[100]
                                : Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Auto",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          Switch(
                            value: autoCode,
                            onChanged: (v) => setModal(() => autoCode = v),
                            activeThumbColor: Colors.purple[700],
                            activeTrackColor: Colors.purple[200],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Nominal diskon
                  TextField(
                    controller: discountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Nominal Diskon (Rp)",
                      hintText: "Contoh: 10000",
                      prefixText: "Rp ",
                      prefixIcon: Icon(
                        Icons.discount_rounded,
                        color: Colors.purple[700],
                      ),
                      filled: true,
                      fillColor: Colors.purple[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  final discount = int.tryParse(discountController.text) ?? 0;
                  if (discount <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text("Nominal diskon wajib diisi & > 0"),
                      ),
                    );
                    return;
                  }

                  final nav = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);

                  final response = await http.post(
                    Uri.parse("$baseUrl/vouchers"),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({
                      "name": nameController.text.trim(),
                      "code": autoCode
                          ? ""
                          : codeController.text.trim().toUpperCase(),
                      "discount": discount,
                    }),
                  );

                  if (!mounted) return;
                  nav.pop();

                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    fetchVouchers();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text("Voucher dibuat: ${data["code"]}"),
                        backgroundColor: Colors.purple[700],
                      ),
                    );
                  } else {
                    final err = jsonDecode(response.body);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(err["error"] ?? "Gagal membuat voucher"),
                      ),
                    );
                  }
                },
                child: const Text("Buat Voucher"),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================
  // BAGIKAN VOUCHER
  // =========================
  void showAssignDialog(Map<String, dynamic> v) {
    bool toAll = true;
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.send_rounded, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text("Bagikan Voucher"),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info voucher
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_offer_rounded,
                          color: Colors.purple[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (v["name"]?.toString().isNotEmpty == true
                                        ? v["name"]
                                        : v["code"])
                                    as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Diskon Rp ${v["discount"]}  •  ${v["code"]}",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Kirim kepada:",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  _radioTile(
                    label: "Semua Pelanggan",
                    subtitle: "Voucher dikirim ke seluruh akun customer",
                    selected: toAll,
                    onTap: () => setModal(() => toAll = true),
                  ),
                  const SizedBox(height: 4),
                  _radioTile(
                    label: "Pelanggan Tertentu",
                    subtitle: "Masukkan email pelanggan",
                    selected: !toAll,
                    onTap: () => setModal(() => toAll = false),
                  ),
                  if (!toAll) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email Pelanggan",
                        hintText: "pelanggan@email.com",
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal"),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  if (!toAll && emailController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text("Masukkan email pelanggan")),
                    );
                    return;
                  }

                  final nav = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);

                  final response = await http.post(
                    Uri.parse("$baseUrl/user-vouchers/assign"),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({
                      "assign_all": toAll,
                      "email": toAll ? null : emailController.text.trim(),
                      "voucher_codes": [v["code"]],
                    }),
                  );

                  if (!mounted) return;
                  nav.pop();

                  if (response.statusCode == 200) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          toAll
                              ? "Voucher berhasil dikirim ke semua pelanggan"
                              : "Voucher berhasil dikirim ke ${emailController.text.trim()}",
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    final err = jsonDecode(response.body);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(err["error"] ?? "Gagal mengirim voucher"),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(toAll ? "Kirim ke Semua" : "Kirim"),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================
  // RADIO TILE (tanpa deprecated API)
  // =========================
  Widget _radioTile({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? Colors.blue[700] : Colors.grey[400],
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14)),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // KARTU VOUCHER
  // =========================
  Widget _buildVoucherCard(Map<String, dynamic> v) {
    final id = v["id"] as int;
    final name = (v["name"] ?? "").toString();
    final code = (v["code"] ?? "-").toString();
    final discount = v["discount"] ?? 0;
    final isActive = v["is_active"] == true || v["is_active"] == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_offer_rounded,
                    color: Colors.purple[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name.isNotEmpty)
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Text(
                              code,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green[50]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? "Aktif" : "Nonaktif",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? Colors.green[700]
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  tooltip: "Hapus",
                  onPressed: () => deleteVoucher(id, name),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Nominal diskon menonjol
            Text(
              "Diskon: Rp $discount",
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 10),

            // Tombol bagikan
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () => showAssignDialog(v),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text("Bagikan ke Pelanggan"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Kelola Voucher",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.blue[700],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: fetchVouchers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showCreateVoucherDialog,
        backgroundColor: Colors.purple[700],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Buat Voucher",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchVouchers,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // =====================
                  // KARTU INFO REWARD OTOMATIS
                  // =====================
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[800]!, Colors.blue[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.card_giftcard_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Reward Otomatis",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Pelanggan mendapat voucher diskon Rp 2.000 setiap kelipatan 5 transaksi selesai — berjalan otomatis.",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // =====================
                  // HEADER SECTION
                  // =====================
                  Row(
                    children: [
                      Text(
                        "Voucher Promo",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${vouchers.length}",
                          style: TextStyle(
                            color: Colors.purple[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "Tekan + untuk tambah",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // =====================
                  // DAFTAR VOUCHER
                  // =====================
                  if (vouchers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.local_offer_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Belum ada voucher promo",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Tekan tombol + untuk membuat voucher baru",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...vouchers.map((v) => _buildVoucherCard(v)),
                ],
              ),
            ),
    );
  }
}
