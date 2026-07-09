import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:galonfibonacci/api_config.dart';

// Formatter untuk memaksa input menjadi huruf besar semua.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class AdminProductScreen extends StatefulWidget {
  const AdminProductScreen({super.key});

  @override
  State<AdminProductScreen> createState() => _AdminProductScreenState();
}

class _AdminProductScreenState extends State<AdminProductScreen> {
  List products = [];
  List<Map<String, dynamic>> suppliers = [];

  final String baseUrl = ApiConfig.baseUrl;

  File? selectedImage;

  @override
  void initState() {
    super.initState();
    fetchProducts();
    fetchSuppliers();
  }

  // GET PRODUCTS
  Future<void> fetchProducts() async {
    final response = await http.get(Uri.parse("$baseUrl/products"));
    if (response.statusCode == 200) {
      setState(() {
        products = jsonDecode(response.body);
      });
    }
  }

  // GET SUPPLIERS
  Future<void> fetchSuppliers() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/suppliers"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          suppliers = data is List ? List<Map<String, dynamic>>.from(data) : [];
        });
      }
    } catch (e) {
      debugPrint("fetchSuppliers error: $e");
    }
  }

  // UPLOAD TO IMGBB
  Future<String?> uploadImageToImgBB() async {
    if (selectedImage == null) return null;
    const apiKey = "2a90f301933df8f150375997315228ed";
    var request = http.MultipartRequest(
      "POST",
      Uri.parse("https://api.imgbb.com/1/upload?key=$apiKey"),
    );
    request.files.add(
      await http.MultipartFile.fromPath("image", selectedImage!.path),
    );
    var response = await request.send();
    if (response.statusCode == 200) {
      final data = jsonDecode(await response.stream.bytesToString());
      return data["data"]["url"];
    }
    return null;
  }

  // DELETE PRODUCT
  Future<void> deleteProduct(int id) async {
    final response = await http.delete(Uri.parse("$baseUrl/products/$id"));
    if (response.statusCode == 200) {
      fetchProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Produk berhasil dihapus")));
    }
  }

  // DIALOG TAMBAH SUPPLIER (dengan alamat & no HP)
  void showAddSupplierDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.add_business_rounded, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text("Tambah Supplier"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                decoration: InputDecoration(
                  labelText: "Nama Supplier",
                  hintText: "Otomatis huruf besar, mis. SUMBER AIR JAYA",
                  prefixIcon: const Icon(Icons.business),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "No HP Supplier",
                  hintText: "Contoh: 08123456789",
                  prefixIcon: const Icon(Icons.phone_rounded),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: "Alamat Supplier",
                  hintText: "Contoh: Jl. Merdeka No.5, Jakarta",
                  prefixIcon: const Icon(Icons.location_on_rounded),
                  filled: true,
                  fillColor: Colors.grey[50],
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
              if (nameController.text.trim().isEmpty) return;

              // Cek duplikat nama supplier sebelum mengirim ke server
              final newName = nameController.text.trim().toUpperCase();
              final duplicate = suppliers.any(
                (s) => (s["name"] ?? "").toString().toUpperCase() == newName,
              );
              if (duplicate) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    title: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "Supplier Sudah Ada",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    content: Text(
                      'Supplier dengan nama "$newName" sudah terdaftar dalam sistem.\n\nSilakan gunakan nama lain.',
                    ),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Mengerti"),
                      ),
                    ],
                  ),
                );
                return;
              }

              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final response = await http.post(
                Uri.parse("$baseUrl/suppliers"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "name": nameController.text.trim(),
                  "phone": phoneController.text.trim(),
                  "address": addressController.text.trim(),
                }),
              );
              if (!mounted) return;
              if (response.statusCode == 200) {
                navigator.pop();
                await fetchSuppliers();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("Supplier berhasil ditambahkan"),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                // Tampilkan notifikasi error (mis. nama supplier duplikat)
                String msg = "Gagal menambahkan supplier";
                try {
                  final err = jsonDecode(response.body);
                  if (err is Map && err["error"] != null) {
                    msg = err["error"].toString();
                  }
                } catch (_) {}
                messenger.showSnackBar(
                  SnackBar(content: Text(msg), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // DIALOG TABEL SUPPLIER
  void showSupplierTableDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.table_chart_rounded, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text("Daftar Supplier"),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: suppliers.isEmpty
              ? const Center(child: Text("Belum ada supplier"))
              : ListView.builder(
                  itemCount: suppliers.length,
                  itemBuilder: (ctx, i) {
                    final s = suppliers[i];
                    final id = (s["id"] ?? "-").toString();
                    final phone = (s["phone"] ?? "").toString();
                    final address = (s["address"] ?? "").toString();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.business_rounded,
                                color: Colors.blue[700],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[700],
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          id,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          (s["name"] ?? "-").toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (phone.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone_rounded,
                                          size: 12,
                                          color: Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          phone,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (address.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          size: 12,
                                          color: Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            address,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () async {
                                final nav = Navigator.of(context);
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Hapus Supplier"),
                                    content: Text(
                                      'Hapus supplier "${s["name"]}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Batal"),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text("Hapus"),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                                final response = await http.delete(
                                  Uri.parse("$baseUrl/suppliers/${s["id"]}"),
                                );
                                if (!mounted) return;
                                if (response.statusCode == 200) {
                                  await fetchSuppliers();
                                  nav.pop();
                                  showSupplierTableDialog();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Supplier berhasil dihapus",
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              showAddSupplierDialog();
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text("Tambah"),
          ),
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

  // DIALOG ADD / EDIT PRODUCT
  void showProductDialog({Map? product}) {
    selectedImage = null;

    final merkController = TextEditingController(text: product?["merk"] ?? "");
    final hargaJualController = TextEditingController(
      text: product?["price"]?.toString() ?? "",
    );
    final hargaModalController = TextEditingController(
      text: product?["modal"]?.toString() ?? "",
    );
    final stockNewController = TextEditingController(
      text: product?["stock_new"]?.toString() ?? "",
    );
    final stockRentalController = TextEditingController(
      text: product?["stock_rental"]?.toString() ?? "",
    );

    // Ambil supplier_id dari produk, pastikan bukan null/kosong/"0"/angka lama
    final rawSupplierId = product?["supplier_id"]?.toString() ?? "";
    String? selectedSupplierId =
        (rawSupplierId.isNotEmpty &&
            rawSupplierId != "0" &&
            RegExp(r'^[A-Za-z]').hasMatch(rawSupplierId))
        ? rawSupplierId
        : null;

    // Pastikan supplier terpilih masih ada di daftar saat ini
    if (selectedSupplierId != null &&
        !suppliers.any((s) => s["id"].toString() == selectedSupplierId)) {
      selectedSupplierId = null;
    }

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            int keuntungan() {
              final jual = int.tryParse(hargaJualController.text) ?? 0;
              final modal = int.tryParse(hargaModalController.text) ?? 0;
              return jual - modal;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    product == null
                        ? Icons.add_circle_rounded
                        : Icons.edit_rounded,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Text(product == null ? "Tambah Produk" : "Edit Produk"),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MERK
                    TextField(
                      controller: merkController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: "Nama / Merk Produk",
                        hintText: "Contoh: Aqua, Club, Le Minerale",
                        prefixIcon: const Icon(Icons.local_drink_rounded),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── HARGA JUAL ──────────────────────────────
                    Row(
                      children: [
                        Icon(
                          Icons.sell_rounded,
                          size: 16,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Harga Jual",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.green[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: hargaJualController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: "Contoh: 45000",
                        prefixText: "Rp ",
                        filled: true,
                        fillColor: Colors.green[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.green.shade400,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── HARGA MODAL ─────────────────────────────
                    Row(
                      children: [
                        Icon(
                          Icons.price_change_rounded,
                          size: 16,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Harga Modal",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.orange[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: hargaModalController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: "Contoh: 30000",
                        prefixText: "Rp ",
                        filled: true,
                        fillColor: Colors.orange[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.orange.shade400,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // PREVIEW KEUNTUNGAN
                    Builder(
                      builder: (_) {
                        final k = keuntungan();
                        if (hargaJualController.text.isEmpty ||
                            hargaModalController.text.isEmpty) {
                          return const SizedBox();
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: k >= 0 ? Colors.green[50] : Colors.red[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: k >= 0
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                k >= 0
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                color: k >= 0
                                    ? Colors.green[700]
                                    : Colors.red[700],
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                k >= 0
                                    ? "Keuntungan: Rp $k"
                                    : "Rugi: Rp ${k.abs()}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: k >= 0
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // STOK DIPISAH: STOK BARU & STOK SEWA
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stockNewController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Stok Baru",
                              helperText: "Untuk Beli Baru",
                              prefixIcon: const Icon(Icons.inventory_2_rounded),
                              filled: true,
                              fillColor: Colors.blue[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: stockRentalController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Stok Sewa",
                              helperText: "Untuk Sewa",
                              prefixIcon: const Icon(Icons.swap_horiz_rounded),
                              filled: true,
                              fillColor: Colors.orange[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // DROPDOWN SUPPLIER (InputDecorator + DropdownButton
                    // agar kompatibel semua versi Flutter)
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: "Supplier",
                        prefixIcon: const Icon(Icons.business_rounded),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: DropdownButton<String>(
                        value:
                            suppliers.any(
                              (s) => s["id"].toString() == selectedSupplierId,
                            )
                            ? selectedSupplierId
                            : null,
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: const Text("Pilih supplier"),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text("-- Tanpa Supplier --"),
                          ),
                          ...suppliers.map((s) {
                            return DropdownMenuItem<String>(
                              value: s["id"].toString(),
                              child: Text(
                                "${s["id"]} • ${s["name"]}",
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setModalState(() => selectedSupplierId = value);
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          textStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        icon: const Icon(Icons.add_business_rounded, size: 16),
                        label: const Text("Tambah Supplier"),
                        onPressed: () {
                          Navigator.pop(context);
                          showAddSupplierDialog();
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    // PILIH GAMBAR
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.grey[800],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (pickedFile != null) {
                          setModalState(
                            () => selectedImage = File(pickedFile.path),
                          );
                        }
                      },
                      icon: const Icon(Icons.image_rounded),
                      label: const Text("Pilih Gambar"),
                    ),

                    const SizedBox(height: 10),

                    if (selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          selectedImage!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (product != null &&
                        (product["image"] ?? "").toString().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          product["image"],
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 80,
                            color: Colors.grey[100],
                            child: const Icon(Icons.broken_image_rounded),
                          ),
                        ),
                      ),
                  ],
                ),
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
                    if (merkController.text.trim().isEmpty ||
                        hargaJualController.text.isEmpty ||
                        hargaModalController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Nama, harga jual & modal wajib diisi"),
                        ),
                      );
                      return;
                    }

                    String imageUrl = product?["image"] ?? "";
                    if (selectedImage != null) {
                      final uploadedUrl = await uploadImageToImgBB();
                      if (uploadedUrl != null) imageUrl = uploadedUrl;
                    }

                    final body = {
                      "category_id": 1,
                      "merk": merkController.text.trim(),
                      "price": int.tryParse(hargaJualController.text) ?? 0,
                      "modal": int.tryParse(hargaModalController.text) ?? 0,
                      "stock_new": int.tryParse(stockNewController.text) ?? 0,
                      "stock_rental":
                          int.tryParse(stockRentalController.text) ?? 0,
                      // Pertahankan nilai reservasi yang sudah ada saat mengedit
                      // agar tidak ter-reset ke 0.
                      "reserved_stock_new":
                          int.tryParse(
                            product?["reserved_stock_new"]?.toString() ?? "0",
                          ) ??
                          0,
                      "reserved_stock_rental":
                          int.tryParse(
                            product?["reserved_stock_rental"]?.toString() ??
                                "0",
                          ) ??
                          0,
                      "image": imageUrl,
                      "supplier_id": selectedSupplierId ?? "",
                    };

                    http.Response response;
                    if (product == null) {
                      response = await http.post(
                        Uri.parse("$baseUrl/products"),
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode(body),
                      );
                    } else {
                      response = await http.put(
                        Uri.parse("$baseUrl/products/${product["id"]}"),
                        headers: {"Content-Type": "application/json"},
                        body: jsonEncode(body),
                      );
                    }

                    if (!context.mounted) return;

                    if (response.statusCode == 200) {
                      Navigator.pop(context);
                      fetchProducts();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            product == null
                                ? "Produk berhasil ditambah"
                                : "Produk berhasil diupdate",
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Kelola Produk",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: showSupplierTableDialog,
            icon: const Icon(Icons.table_chart_rounded, color: Colors.white),
            label: const Text(
              "Supplier",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue[700],
        onPressed: () => showProductDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Tambah Produk",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchProducts,
              child: ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final hargaJual = product["price"] ?? 0;
                  final hargaModal = product["modal"] ?? 0;
                  final keuntungan = hargaJual - hargaModal;
                  final supplierName = (product["supplier_name"] ?? "")
                      .toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // GAMBAR
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              (product["image"] ?? "").toString(),
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 70,
                                height: 70,
                                color: Colors.blue[50],
                                child: Icon(
                                  Icons.local_drink_rounded,
                                  color: Colors.blue[300],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // INFO
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (product["merk"] ?? "-").toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                if (supplierName.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.business_rounded,
                                        size: 13,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          supplierName,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 6),

                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _infoChip(
                                      "Jual: Rp $hargaJual",
                                      Colors.green,
                                      Icons.sell_rounded,
                                    ),
                                    _infoChip(
                                      "Modal: Rp $hargaModal",
                                      Colors.orange,
                                      Icons.price_change_rounded,
                                    ),
                                    _infoChip(
                                      keuntungan >= 0
                                          ? "+Rp $keuntungan"
                                          : "-Rp ${keuntungan.abs()}",
                                      keuntungan >= 0
                                          ? Colors.teal
                                          : Colors.red,
                                      keuntungan >= 0
                                          ? Icons.trending_up_rounded
                                          : Icons.trending_down_rounded,
                                    ),
                                    _infoChip(
                                      "Stok Baru: ${product["stock_new"] ?? 0} (Tersedia: ${((product["stock_new"] ?? 0) as int) - ((product["reserved_stock_new"] ?? 0) as int)})",
                                      Colors.blue[700]!,
                                      Icons.inventory_2_rounded,
                                    ),
                                    _infoChip(
                                      "Stok Sewa: ${product["stock_rental"] ?? 0} (Tersedia: ${((product["stock_rental"] ?? 0) as int) - ((product["reserved_stock_rental"] ?? 0) as int)})",
                                      Colors.orange[700]!,
                                      Icons.swap_horiz_rounded,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // AKSI
                          Column(
                            children: [
                              IconButton(
                                onPressed: () =>
                                    showProductDialog(product: product),
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.orange,
                                ),
                              ),
                              IconButton(
                                onPressed: () => deleteProduct(product["id"]),
                                icon: const Icon(
                                  Icons.delete_rounded,
                                  color: Colors.red,
                                ),
                              ),
                            ],
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

  Widget _infoChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
