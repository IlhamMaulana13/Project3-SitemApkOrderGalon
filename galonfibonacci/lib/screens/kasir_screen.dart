import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:galonfibonacci/api_config.dart';
import 'package:galonfibonacci/screens/login_screen.dart';
import 'package:http/http.dart' as http;

class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  final String baseUrl = ApiConfig.baseUrl;

  // Daftar layanan & harga (samakan dengan alur pelanggan)
  static const List<String> services = ["Isi Ulang", "Beli Baru", "Sewa"];

  List products = [];

  // Keranjang transaksi berjalan
  // tiap item: {product_id, merk, service, price, qty}
  final List<Map<String, dynamic>> cart = [];

  // Ringkasan & riwayat transaksi kasir
  int todayTotal = 0;
  int todayCount = 0;
  List transactions = [];

  bool isProcessing = false;

  final customerNameController = TextEditingController();
  final customerPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchProducts();
    fetchTransactions();
  }

  @override
  void dispose() {
    customerNameController.dispose();
    customerPhoneController.dispose();
    super.dispose();
  }

  String? get kasirUid => FirebaseAuth.instance.currentUser?.uid;

  int priceForService(String service) {
    switch (service) {
      case "Isi Ulang":
        return 7000;
      case "Beli Baru":
        return 45000;
      case "Sewa":
        return 2000;
      default:
        return 0;
    }
  }

  int get cartTotal {
    int total = 0;
    for (final item in cart) {
      total += (item["price"] as int) * (item["qty"] as int);
    }
    return total;
  }

  // =========================
  // FETCH
  // =========================
  Future<void> fetchProducts() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/products"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          products = data is List ? data : [];
        });
      }
    } catch (e) {
      debugPrint("fetchProducts error: $e");
    }
  }

  Future<void> fetchTransactions() async {
    final uid = kasirUid;
    if (uid == null) return;

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/kasir/transactions/$uid"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          todayTotal = data["today_total"] ?? 0;
          todayCount = data["today_count"] ?? 0;
          transactions = data["transactions"] ?? [];
        });
      }
    } catch (e) {
      debugPrint("fetchTransactions error: $e");
    }
  }

  // =========================
  // KERANJANG
  // =========================
  void addToCart(Map product, String service, int qty) {
    final productId = product["id"];
    final price = priceForService(service);

    final existingIndex = cart.indexWhere(
      (item) => item["product_id"] == productId && item["service"] == service,
    );

    setState(() {
      if (existingIndex >= 0) {
        cart[existingIndex]["qty"] += qty;
      } else {
        cart.add({
          "product_id": productId,
          "merk": product["merk"],
          "service": service,
          "price": price,
          "qty": qty,
        });
      }
    });
  }

  void removeFromCart(int index) {
    setState(() {
      cart.removeAt(index);
    });
  }

  void changeQty(int index, int delta) {
    setState(() {
      final newQty = (cart[index]["qty"] as int) + delta;
      if (newQty <= 0) {
        cart.removeAt(index);
      } else {
        cart[index]["qty"] = newQty;
      }
    });
  }

  // =========================
  // DIALOG TAMBAH ITEM
  // =========================
  void showAddItemDialog(Map product) {
    String selectedService = "Beli Baru";
    int qty = 1;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final price = priceForService(selectedService);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(product["merk"] ?? "Produk"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Jenis Layanan"),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedService,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: services
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => selectedService = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Jumlah"),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (qty > 1) setModalState(() => qty--);
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            "$qty",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => setModalState(() => qty++),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Subtotal"),
                      Text(
                        "Rp ${price * qty}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
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
                  ),
                  onPressed: () {
                    addToCart(product, selectedService, qty);
                    Navigator.pop(context);
                  },
                  child: const Text("Tambah"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================
  // PROSES BAYAR TUNAI
  // =========================
  Future<void> processPayment() async {
    final uid = kasirUid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sesi kasir tidak valid, silakan login ulang"),
        ),
      );
      return;
    }

    if (cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Keranjang masih kosong")));
      return;
    }

    setState(() => isProcessing = true);

    final items = cart
        .map(
          (item) => {
            "product_id": item["product_id"],
            "qty": item["qty"],
            "subtotal": (item["price"] as int) * (item["qty"] as int),
            "service": item["service"],
          },
        )
        .toList();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/kasir/orders"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "kasir_uid": uid,
          "customer_name": customerNameController.text.trim(),
          "customer_phone": customerPhoneController.text.trim(),
          "total": cartTotal,
          "items": items,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          cart.clear();
          customerNameController.clear();
          customerPhoneController.clear();
        });

        await fetchProducts();
        await fetchTransactions();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Transaksi tunai berhasil disimpan"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["error"] ?? "Transaksi gagal")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Terjadi kesalahan: $e")));
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  // =========================
  // BOTTOM SHEET KERANJANG
  // =========================
  void showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Keranjang Transaksi",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (cart.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text("Belum ada item")),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.32,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: cart.length,
                        itemBuilder: (context, index) {
                          final item = cart[index];
                          final subtotal =
                              (item["price"] as int) * (item["qty"] as int);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              "${item["merk"]} (${item["service"]})",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              "Rp ${item["price"]} x ${item["qty"]}",
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    changeQty(index, -1);
                                    setSheetState(() {});
                                  },
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 20,
                                  ),
                                ),
                                Text("${item["qty"]}"),
                                IconButton(
                                  onPressed: () {
                                    changeQty(index, 1);
                                    setSheetState(() {});
                                  },
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Rp $subtotal",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const Divider(),
                  // DATA PELANGGAN (OPSIONAL)
                  TextField(
                    controller: customerNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: "Nama Pelanggan (opsional)",
                      prefixIcon: Icon(Icons.person_outline),
                      hintText: "Contoh: Budi Santoso",
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customerPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "No HP Pelanggan (opsional)",
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Rp $cartTotal",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: (cart.isEmpty || isProcessing)
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await processPayment();
                            },
                      icon: const Icon(Icons.payments),
                      label: const Text(
                        "Bayar Tunai",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================
  // TAB: KASIR (POS)
  // =========================
  Widget buildPosTab() {
    final searchController = TextEditingController();
    List filteredProducts = products;

    return StatefulBuilder(
      builder: (context, setStatePos) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(15),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Cari produk...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            setStatePos(() {
                              filteredProducts = products;
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setStatePos(() {
                    filteredProducts = products
                        .where(
                          (p) => (p['merk'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(value.toLowerCase()),
                        )
                        .toList();
                  });
                },
              ),
            ),
            Expanded(
              child: products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredProducts.isEmpty
                  ? const Center(child: Text('Produk tidak ditemukan'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                (product["image"] ?? "").toString(),
                                width: 55,
                                height: 55,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 55,
                                  height: 55,
                                  color: Colors.blue[50],
                                  child: Icon(
                                    Icons.local_drink,
                                    color: Colors.blue[300],
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              (product["merk"] ?? "-").toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text("Stok: ${product["stock"] ?? 0}"),
                            trailing: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => showAddItemDialog(product),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text("Tambah"),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (cart.isNotEmpty)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("${cart.length} item"),
                            Text(
                              "Rp $cartTotal",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: showCartSheet,
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: const Text("Lihat Keranjang"),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: fetchTransactions,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.point_of_sale, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Pendapatan Tunai Hari Ini",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Rp $todayTotal",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "$todayCount transaksi",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Riwayat Transaksi",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text("Belum ada transaksi")),
            )
          else
            ...transactions.map((trx) {
              final name = (trx["customer_name"] ?? "").toString();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Icon(Icons.receipt_long, color: Colors.green[700]),
                  ),
                  title: Text(
                    "Order #${trx["id"]}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? "Pelanggan umum" : name),
                      Text(
                        (trx["created_at"] ?? "").toString(),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Text(
                    "Rp ${trx["total"]}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: Colors.blue[700],
          title: const Text(
            "Kasir Toko",
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
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
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.point_of_sale), text: "Kasir"),
              Tab(icon: Icon(Icons.history), text: "Riwayat"),
            ],
          ),
        ),
        body: TabBarView(children: [buildPosTab(), buildHistoryTab()]),
      ),
    );
  }
}
