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

  // Format DateTime -> "YYYY-MM-DD" untuk dikirim ke backend.
  String _fmtDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  // Ambil bagian tanggal "YYYY-MM-DD" dari string tanggal apa pun; "" jika kosong.
  String _dateOnly(dynamic raw) {
    final s = (raw ?? "").toString();
    if (s.isEmpty) return "";
    // Backend bisa mengirim "2026-07-01" atau "2026-07-01T00:00:00Z".
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  // Parse "YYYY-MM-DD" -> DateTime; null jika gagal.
  DateTime? _parseDate(dynamic raw) {
    final s = _dateOnly(raw);
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  // Tampilan ramah tanggal, contoh "01 Jul 2026". Tanpa paket intl.
  String _displayDate(dynamic raw) {
    final d = _parseDate(raw);
    if (d == null) return "-";
    const bulan = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "Mei",
      "Jun",
      "Jul",
      "Agu",
      "Sep",
      "Okt",
      "Nov",
      "Des",
    ];
    return "${d.day.toString().padLeft(2, '0')} ${bulan[d.month - 1]} ${d.year}";
  }

  // Field pemilih tanggal (dipakai di dialog buat & edit voucher).
  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.calendar_month_rounded, color: color),
          filled: true,
          fillColor: (color ?? Colors.grey).withValues(alpha: 0.08),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          value == null ? "Pilih tanggal" : _displayDate(_fmtDate(value)),
          style: TextStyle(
            color: value == null ? Colors.grey[500] : Colors.black87,
            fontSize: 14,
          ),
        ),
      ),
    );
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
  // TOGGLE STATUS AKTIF/NONAKTIF
  // =========================
  Future<void> toggleVoucherStatus(int id, bool isActive) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/vouchers/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"is_active": isActive}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        fetchVouchers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isActive
                  ? "Voucher diaktifkan"
                  : "Voucher dinonaktifkan sementara",
            ),
            backgroundColor: isActive ? Colors.green : Colors.grey[700],
          ),
        );
      }
    } catch (e) {
      debugPrint("toggleVoucherStatus error: $e");
    }
  }

  // =========================
  // EDIT VOUCHER
  // =========================
  void showEditVoucherDialog(Map<String, dynamic> v) {
    final nameController = TextEditingController(
      text: v["name"]?.toString() ?? "",
    );
    final codeController = TextEditingController(
      text: v["code"]?.toString() ?? "",
    );
    final discountController = TextEditingController(
      text: v["discount"]?.toString() ?? "",
    );
    DateTime? activeFrom = _parseDate(v["active_from"]);
    DateTime? activeUntil = _parseDate(v["active_until"]);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.edit_rounded, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text("Edit Voucher"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Nama Voucher",
                    prefixIcon: const Icon(Icons.label_rounded),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: "Kode Voucher",
                    prefixIcon: const Icon(Icons.confirmation_number_rounded),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: discountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Nominal Diskon (Rp)",
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
                const SizedBox(height: 14),
                Text(
                  "Masa aktif voucher",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _dateField(
                  label: "Aktif dari",
                  value: activeFrom,
                  color: Colors.green[700],
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: activeFrom ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setModal(() => activeFrom = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                _dateField(
                  label: "Aktif sampai",
                  value: activeUntil,
                  color: Colors.orange[700],
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          activeUntil ?? (activeFrom ?? DateTime.now()),
                      firstDate: activeFrom ?? DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setModal(() => activeUntil = picked);
                    }
                  },
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
                backgroundColor: Colors.orange[700],
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
                if (activeFrom != null &&
                    activeUntil != null &&
                    activeFrom!.isAfter(activeUntil!)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Tanggal mulai tidak boleh lebih besar dari tanggal selesai",
                      ),
                    ),
                  );
                  return;
                }
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final response = await http.put(
                  Uri.parse("$baseUrl/vouchers/${v["id"]}"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "name": nameController.text.trim(),
                    "code": codeController.text.trim().toUpperCase(),
                    "discount": discount,
                    "active_from": activeFrom == null
                        ? ""
                        : _fmtDate(activeFrom!),
                    "active_until": activeUntil == null
                        ? ""
                        : _fmtDate(activeUntil!),
                  }),
                );
                if (!mounted) return;
                nav.pop();
                if (response.statusCode == 200) {
                  fetchVouchers();
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text("Voucher berhasil diupdate"),
                      backgroundColor: Colors.orange[700],
                    ),
                  );
                } else {
                  final err = jsonDecode(response.body);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(err["error"] ?? "Gagal update voucher"),
                    ),
                  );
                }
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // LIHAT PENERIMA VOUCHER
  // =========================
  Future<List<Map<String, dynamic>>> _fetchRecipients(int voucherId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/vouchers/$voucherId/recipients"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint("_fetchRecipients error: $e");
    }
    return [];
  }

  void showRecipientsDialog(Map<String, dynamic> v) {
    final voucherId = v["id"] as int;
    final label = (v["name"]?.toString().isNotEmpty == true
        ? v["name"].toString()
        : v["code"]?.toString() ?? "Voucher");
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.people_rounded, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Penerima $label",
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchRecipients(voucherId),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final recipients = snapshot.data ?? [];
            if (recipients.isEmpty) {
              return const SizedBox(
                height: 80,
                child: Center(
                  child: Text("Belum ada penerima untuk voucher ini"),
                ),
              );
            }
            return SizedBox(
              width: double.maxFinite,
              height: 260,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: recipients.length,
                itemBuilder: (_, i) {
                  final r = recipients[i];
                  final name = (r["name"] ?? r["user_name"] ?? "-").toString();
                  final email = (r["email"] ?? r["user_email"] ?? "-")
                      .toString();
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue[50],
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.blue[700],
                        size: 18,
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      email,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  // =========================
  // PENGATURAN REWARD OTOMATIS
  // =========================
  void showRewardSettingsDialog() async {
    Map<String, dynamic>? settings;
    try {
      final r = await http.get(Uri.parse("$baseUrl/reward-settings"));
      if (r.statusCode == 200) settings = jsonDecode(r.body);
    } catch (_) {}

    if (!mounted) return;

    final multiplierController = TextEditingController(
      text: (settings?["multiplier"] ?? 5).toString(),
    );
    final discountController = TextEditingController(
      text: (settings?["discount"] ?? 2000).toString(),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.settings_rounded, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Expanded(child: Text("Pengaturan Reward Otomatis")),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: multiplierController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Kelipatan Transaksi",
                hintText: "Contoh: 5",
                helperText: "Voucher diberikan setiap kelipatan N transaksi",
                prefixIcon: const Icon(Icons.repeat_rounded),
                filled: true,
                fillColor: Colors.blue[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: discountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Potongan Diskon (Rp)",
                hintText: "Contoh: 2000",
                prefixText: "Rp ",
                prefixIcon: Icon(
                  Icons.discount_rounded,
                  color: Colors.green[700],
                ),
                filled: true,
                fillColor: Colors.green[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final multiplier = int.tryParse(multiplierController.text) ?? 0;
              final discount = int.tryParse(discountController.text) ?? 0;
              if (multiplier <= 0 || discount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Isi semua field dengan nilai > 0"),
                  ),
                );
                return;
              }
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final response = await http.put(
                Uri.parse("$baseUrl/reward-settings"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "multiplier": multiplier,
                  "discount": discount,
                }),
              );
              if (!mounted) return;
              nav.pop();
              if (response.statusCode == 200) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("Pengaturan reward berhasil disimpan"),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(content: Text("Gagal menyimpan pengaturan")),
                );
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // =========================
  // BUAT VOUCHER BARU
  // =========================
  void showCreateVoucherDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final discountController = TextEditingController();
    bool autoCode = true;
    DateTime? activeFrom = DateTime.now();
    DateTime? activeUntil = DateTime.now().add(const Duration(days: 30));

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
                  const SizedBox(height: 14),
                  Text(
                    "Masa aktif voucher",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _dateField(
                    label: "Aktif dari",
                    value: activeFrom,
                    color: Colors.green[700],
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: activeFrom ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setModal(() => activeFrom = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _dateField(
                    label: "Aktif sampai",
                    value: activeUntil,
                    color: Colors.orange[700],
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            activeUntil ?? (activeFrom ?? DateTime.now()),
                        firstDate: activeFrom ?? DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setModal(() => activeUntil = picked);
                      }
                    },
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
                  if (activeFrom != null &&
                      activeUntil != null &&
                      activeFrom!.isAfter(activeUntil!)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Tanggal mulai tidak boleh lebih besar dari tanggal selesai",
                        ),
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
                      "active_from": activeFrom == null
                          ? ""
                          : _fmtDate(activeFrom!),
                      "active_until": activeUntil == null
                          ? ""
                          : _fmtDate(activeUntil!),
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
  // BAGIKAN VOUCHER (dengan dropdown user)
  // =========================
  void showAssignDialog(Map<String, dynamic> v) async {
    // Pre-fetch customer list
    List<Map<String, dynamic>> customerList = [];
    try {
      final response = await http.get(Uri.parse("$baseUrl/users"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          customerList = data
              .map((u) => Map<String, dynamic>.from(u))
              .where((u) => (u["role"] ?? "customer").toString() == "customer")
              .toList();
        }
      }
    } catch (e) {
      debugPrint("fetchCustomers error: $e");
    }

    if (!mounted) return;

    bool toAll = true;
    Set<String> selectedEmails = {};

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
                    subtitle: "Pilih pelanggan dari daftar",
                    selected: !toAll,
                    onTap: () => setModal(() => toAll = false),
                  ),
                  if (!toAll) ...[
                    const SizedBox(height: 8),
                    if (customerList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "Tidak ada pelanggan terdaftar",
                          style: TextStyle(color: Colors.orange),
                        ),
                      )
                    else ...[
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: customerList.length,
                          itemBuilder: (_, i) {
                            final u = customerList[i];
                            final name = (u["name"] ?? u["email"] ?? "-")
                                .toString();
                            final email = (u["email"] ?? "").toString();
                            final isChecked = selectedEmails.contains(email);
                            return InkWell(
                              onTap: () {
                                setModal(() {
                                  if (isChecked) {
                                    selectedEmails.remove(email);
                                  } else {
                                    selectedEmails.add(email);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isChecked,
                                      onChanged: (val) {
                                        setModal(() {
                                          if (val == true) {
                                            selectedEmails.add(email);
                                          } else {
                                            selectedEmails.remove(email);
                                          }
                                        });
                                      },
                                      activeColor: Colors.blue[700],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (email.isNotEmpty)
                                            Text(
                                              email,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (selectedEmails.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            "${selectedEmails.length} pelanggan dipilih",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
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
                  if (!toAll && selectedEmails.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Pilih minimal satu pelanggan terlebih dahulu",
                        ),
                      ),
                    );
                    return;
                  }

                  final nav = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);

                  if (toAll) {
                    // Kirim ke semua pelanggan
                    final response = await http.post(
                      Uri.parse("$baseUrl/user-vouchers/assign"),
                      headers: {"Content-Type": "application/json"},
                      body: jsonEncode({
                        "assign_all": true,
                        "email": null,
                        "voucher_codes": [v["code"]],
                      }),
                    );
                    if (!mounted) return;
                    nav.pop();
                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      final msg = (data is Map && data["message"] != null)
                          ? data["message"].toString()
                          : "Voucher berhasil dikirim ke semua pelanggan";
                      final bool noNew = data is Map && (data["assigned"] == 0);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: noNew
                              ? Colors.orange[800]
                              : Colors.green,
                        ),
                      );
                    } else {
                      final err = jsonDecode(response.body);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            err["error"] ?? "Gagal mengirim voucher",
                          ),
                          backgroundColor: Colors.orange[800],
                        ),
                      );
                    }
                  } else {
                    // Kirim ke pelanggan yang dipilih (satu per satu)
                    int successCount = 0;
                    int failCount = 0;
                    String lastError = "";

                    for (final email in selectedEmails) {
                      try {
                        final response = await http.post(
                          Uri.parse("$baseUrl/user-vouchers/assign"),
                          headers: {"Content-Type": "application/json"},
                          body: jsonEncode({
                            "assign_all": false,
                            "email": email,
                            "voucher_codes": [v["code"]],
                          }),
                        );
                        if (response.statusCode == 200) {
                          successCount++;
                        } else {
                          failCount++;
                          final err = jsonDecode(response.body);
                          lastError = err["error"] ?? "Gagal mengirim voucher";
                        }
                      } catch (e) {
                        failCount++;
                        lastError = "Koneksi gagal: $e";
                      }
                    }

                    if (!mounted) return;
                    nav.pop();

                    if (failCount == 0) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            "Voucher berhasil dikirim ke $successCount pelanggan",
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else if (successCount > 0) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            "Terkirim ke $successCount pelanggan, $failCount gagal. $lastError",
                          ),
                          backgroundColor: Colors.orange[800],
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            lastError.isNotEmpty
                                ? lastError
                                : "Gagal mengirim voucher",
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  toAll
                      ? "Kirim ke Semua"
                      : "Kirim ke ${selectedEmails.length} Pelanggan",
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================
  // RADIO TILE
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
            // ── Header: nama, kode, tombol edit & hapus ──
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
                      const SizedBox(height: 4),
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
                    ],
                  ),
                ),
                // Edit button
                IconButton(
                  icon: Icon(Icons.edit_rounded, color: Colors.orange[700]),
                  tooltip: "Edit",
                  onPressed: () => showEditVoucherDialog(v),
                ),
                // Delete button
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

            // ── Status dropdown (aktif / nonaktif) ──
            Row(
              children: [
                Text(
                  "Status:",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<bool>(
                  value: isActive,
                  isDense: true,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(10),
                  items: [
                    DropdownMenuItem(
                      value: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            color: Colors.green[600],
                            size: 10,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Aktif",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.grey[500], size: 10),
                          const SizedBox(width: 6),
                          Text(
                            "Nonaktif",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null && val != isActive) {
                      toggleVoucherStatus(id, val);
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Nominal diskon ──
            Text(
              "Diskon: Rp $discount",
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 12),

            // ── Tombol lihat penerima ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                  side: BorderSide(color: Colors.blue.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                onPressed: () => showRecipientsDialog(v),
                icon: const Icon(Icons.people_rounded, size: 16),
                label: const Text("Lihat Penerima Voucher"),
              ),
            ),

            const SizedBox(height: 8),

            // ── Tombol bagikan ──
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
                  // ── Kartu Reward Otomatis ──
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
                                "Pelanggan mendapat voucher diskon setiap kelipatan transaksi selesai — berjalan otomatis.",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: showRewardSettingsDialog,
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: Colors.white,
                          ),
                          tooltip: "Atur Reward",
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Header daftar voucher ──
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

                  // ── Daftar voucher ──
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
