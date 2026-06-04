import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galonfibonacci/api_config.dart';
import 'package:http/http.dart' as http;

class AdminRentalScreen extends StatefulWidget {
  const AdminRentalScreen({super.key});

  @override
  State<AdminRentalScreen> createState() => _AdminRentalScreenState();
}

class _AdminRentalScreenState extends State<AdminRentalScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = ApiConfig.baseUrl;

  List<Map<String, dynamic>> rentals = [];
  List<Map<String, dynamic>> appSewa = [];
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;

  late TabController _tabController;
  final List<String> _tabs = ['Semua', 'Aktif', 'Dikembalikan', 'Rusak'];
  final List<String> _statusKeys = ['', 'active', 'returned', 'damaged'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => isLoading = true);
    await Future.wait([fetchRentals(), fetchAppSewa(), fetchProducts()]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> fetchProducts() async {
    try {
      final response =
          await http.get(Uri.parse("$baseUrl/products"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            products = data is List
                ? List<Map<String, dynamic>>.from(data)
                : [];
          });
        }
      }
    } catch (e) {
      debugPrint("fetchProducts error: $e");
    }
  }

  // Hitung jumlah unit aktif disewa per produk
  Map<String, int> _activeRentalCountByProduct() {
    final active = _allRentals().where((r) => r['status'] == 'active');
    final Map<String, int> counts = {};
    for (final r in active) {
      final merk = (r['merk'] ?? '-').toString();
      counts[merk] = (counts[merk] ?? 0) + ((r['qty'] as num?)?.toInt() ?? 1);
    }
    return counts;
  }

  Future<void> fetchRentals() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/rentals"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            rentals = data is List
                ? List<Map<String, dynamic>>.from(data)
                : [];
          });
        }
      }
    } catch (e) {
      debugPrint("fetchRentals error: $e");
    }
  }

  Future<void> fetchAppSewa() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/orders"));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      if (data is! List) return;

      final List<Map<String, dynamic>> sewaList = [];
      for (final order in data) {
        final items = order["items"];
        if (items is! List) continue;

        for (final item in items) {
          final service = (item["service"] ?? "").toString();
          if (service != "Sewa") continue;

          final orderStatus = (order["status"] ?? "").toString();
          sewaList.add({
            "id": order["id"],
            "merk": (item["product_name"] ?? item["merk"] ?? "-").toString(),
            "qty": item["qty"] ?? 1,
            "customer_name": (order["customer_name"] ?? "Pelanggan App").toString(),
            "customer_phone": (order["customer_phone"] ?? "").toString(),
            "rented_at": (order["created_at"] ?? "").toString(),
            "returned_at": orderStatus == "Selesai" ? (order["updated_at"] ?? order["created_at"] ?? "").toString() : "",
            "status": orderStatus == "Selesai" ? "returned" : "active",
            "notes": "",
            "source": "app",
          });
        }
      }

      if (mounted) {
        setState(() {
          appSewa = sewaList;
        });
      }
    } catch (e) {
      debugPrint("fetchAppSewa error: $e");
    }
  }

  List<Map<String, dynamic>> _allRentals() => [...rentals, ...appSewa];

  List<Map<String, dynamic>> _filtered(String statusKey) {
    final combined = _allRentals();
    if (statusKey.isEmpty) return combined;
    return combined.where((r) => r['status'] == statusKey).toList();
  }

  // =====================
  // TANDAI DIKEMBALIKAN
  // =====================
  Future<void> markReturned(int id, String merk) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Konfirmasi Pengembalian"),
        content: Text(
          "Tandai galon \"$merk\" sebagai sudah dikembalikan?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ya, Sudah Kembali"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/rentals/$id/return"),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Galon berhasil dicatat dikembalikan"),
            backgroundColor: Colors.green,
          ),
        );
        fetchRentals();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? "Gagal memperbarui status")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Terjadi kesalahan: $e")),
      );
    }
  }

  // =====================
  // KONVERSI GALON RUSAK
  // =====================
  Future<void> convertDamage(
    int id,
    String merk,
    int qty,
    String customer,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text("Galon Rusak"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Pelanggan: $customer",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text("Produk: $merk (×$qty)"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                "Sistem akan membuat tagihan Beli Baru untuk mengganti galon yang rusak dan mengurangi stok.",
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Konfirmasi Rusak"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/rentals/$id/convert-damage"),
      );
      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final tagihan = data['total_tagihan'] ?? 0;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text("Tagihan Dibuat"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pelanggan: ${data['customer'] ?? customer}"),
                Text("Produk: ${data['merk'] ?? merk}"),
                const SizedBox(height: 8),
                Text(
                  "Total Tagihan: Rp $tagihan",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Tagihan ini tercatat di Kelola Pesanan dengan status pembayaran pending.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        fetchRentals();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? "Gagal memproses")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Terjadi kesalahan: $e")),
      );
    }
  }

  // =====================
  // STATUS CHIP
  // =====================
  Widget _statusChip(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'active':
        color = Colors.blue;
        label = 'Aktif Disewa';
        icon = Icons.loop_rounded;
        break;
      case 'returned':
        color = Colors.green;
        label = 'Dikembalikan';
        icon = Icons.check_circle_rounded;
        break;
      case 'damaged':
        color = Colors.red;
        label = 'Rusak';
        icon = Icons.broken_image_rounded;
        break;
      default:
        color = Colors.grey;
        label = status;
        icon = Icons.circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // =====================
  // KARTU RENTAL
  // =====================
  Widget _rentalCard(Map<String, dynamic> r) {
    final status = r['status'] ?? 'active';
    final isActive = status == 'active';
    final isFromApp = (r['source'] ?? '') == 'app';
    final id = r['id'] as int;
    final merk = r['merk'] ?? '-';
    final qty = r['qty'] ?? 1;
    final customerName = r['customer_name'] ?? 'Pelanggan';
    final customerPhone = r['customer_phone'] ?? '';
    final rentedAt = r['rented_at'] ?? '';
    final returnedAt = r['returned_at'] ?? '';
    final notes = (r['notes'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_drink_rounded,
                    color: Colors.blue[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merk,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Jumlah disewa: $qty galon",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusChip(status),
                    if (isFromApp) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.smartphone_rounded, size: 11, color: Colors.purple[600]),
                            const SizedBox(width: 3),
                            Text(
                              "Dari App",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Customer info
            Row(
              children: [
                Icon(Icons.person_rounded, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (customerPhone.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.phone_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    customerPhone,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 6),

            // Dates
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  "Disewa: ${rentedAt.length > 16 ? rentedAt.substring(0, 16) : rentedAt}",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),

            if (returnedAt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.event_available_rounded,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    "Dikembalikan: ${returnedAt.length > 16 ? returnedAt.substring(0, 16) : returnedAt}",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],

            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notes,
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 12,
                  ),
                ),
              ),
            ],

            // Action buttons hanya untuk kasir rentals yang masih aktif
            if (isActive && !isFromApp) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green[700],
                        side: BorderSide(color: Colors.green.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => markReturned(id, merk.toString()),
                      icon: const Icon(Icons.check_circle_outline_rounded,
                          size: 18),
                      label: const Text(
                        "Sudah Kembali",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => convertDamage(
                        id,
                        merk.toString(),
                        qty as int,
                        customerName.toString(),
                      ),
                      icon: const Icon(Icons.broken_image_rounded, size: 18),
                      label: const Text(
                        "Galon Rusak",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =====================
  // RINGKASAN STOK SEWA
  // =====================
  Widget _buildStockSummary() {
    if (products.isEmpty) return const SizedBox();

    final rentalCounts = _activeRentalCountByProduct();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_rounded,
                  color: Colors.indigo[700], size: 18),
              const SizedBox(width: 6),
              Text(
                "Stok Sewa per Produk",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...products.map((p) {
            final merk = (p['merk'] ?? '-').toString();
            final totalStock = (p['stock'] as num?)?.toInt() ?? 0;
            final rented = rentalCounts[merk] ?? 0;
            final available = (totalStock - rented).clamp(0, totalStock);
            final pct = totalStock == 0 ? 0.0 : rented / totalStock;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      merk,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct.toDouble(),
                            minHeight: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              rented == 0
                                  ? Colors.green
                                  : (available == 0
                                      ? Colors.red
                                      : Colors.orange),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$rented disewa  •  $available tersedia",
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "$totalStock",
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTabContent(String statusKey) {
    final list = _filtered(statusKey);
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_drink_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              "Tidak ada data sewa",
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: list.length,
        itemBuilder: (_, i) => _rentalCard(list[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        _allRentals().where((r) => r['status'] == 'active').length;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Pencatatan Galon Sewa",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.blue[700],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (activeCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "$activeCount aktif",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs
              .asMap()
              .entries
              .map((e) {
                final count = _filtered(_statusKeys[e.key]).length;
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.value),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              })
              .toList(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStockSummary(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _statusKeys
                        .map((key) => _buildTabContent(key))
                        .toList(),
                  ),
                ),
              ],
            ),
    );
  }
}
