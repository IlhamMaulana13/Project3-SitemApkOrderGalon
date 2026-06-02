import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:galonfibonacci/api_config.dart';

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
          suppliers = data is List
              ? List<Map<String, dynamic>>.from(data)
              : [];
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Produk berhasil dihapus")),
      );
    }
  }

  // DIALOG TAMBAH SUPPLIER
  void showAddSupplierDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Tambah Supplier"),
        content: TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: "Nama Supplier",
            prefixIcon: Icon(Icons.business),
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
            ),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final response = await http.post(
                Uri.parse("$baseUrl/suppliers"),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({"name": nameController.text.trim()}),
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
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // DIALOG ADD / EDIT PRODUCT
  void showProductDialog({Map? product}) {
    selectedImage = null;

    final merkController = TextEditingController(
      text: product?["merk"] ?? "",
    );
    final hargaJualController = TextEditingController(
      text: product?["price"]?.toString() ?? "",
    );
    final hargaModalController = TextEditingController(
      text: product?["modal"]?.toString() ?? "",
    );
    final stockController = TextEditingController(
      text: product?["stock"]?.toString() ?? "",
    );

    int? selectedSupplierId = (product?["supplier_id"] != null &&
            product!["supplier_id"] != 0)
        ? product["supplier_id"] as int
        : null;

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
                        Icon(Icons.sell_rounded,
                            size: 16, color: Colors.green[700]),
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
                              color: Colors.green.shade400, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── HARGA MODAL ─────────────────────────────
                    Row(
                      children: [
                        Icon(Icons.price_change_rounded,
                            size: 16, color: Colors.orange[700]),
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
                              color: Colors.orange.shade400, width: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // PREVIEW KEUNTUNGAN
                    Builder(builder: (_) {
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
                          color:
                              k >= 0 ? Colors.green[50] : Colors.red[50],
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
                    }),

                    const SizedBox(height: 14),

                    // STOCK
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Stok",
                        prefixIcon: const Icon(Icons.inventory_2_rounded),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // DROPDOWN SUPPLIER
                    DropdownButtonFormField<int>(
                      initialValue: selectedSupplierId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: "Supplier",
                        prefixIcon: const Icon(Icons.business_rounded),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: suppliers.map((s) {
                        return DropdownMenuItem<int>(
                          value: s["id"] as int,
                          child: Text(
                            s["name"].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() => selectedSupplierId = value);
                      },
                      hint: suppliers.isEmpty
                          ? const Text("Belum ada supplier")
                          : const Text("Pilih supplier"),
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
                        icon: const Icon(
                          Icons.add_business_rounded,
                          size: 16,
                        ),
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
                        hargaModalController.text.isEmpty ||
                        stockController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Semua field wajib diisi"),
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
                      "stock": int.tryParse(stockController.text) ?? 0,
                      "image": imageUrl,
                      "supplier_id": selectedSupplierId ?? 0,
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
            onPressed: showAddSupplierDialog,
            icon: const Icon(Icons.add_business_rounded, color: Colors.white),
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
                  final supplierName =
                      (product["supplier_name"] ?? "").toString();

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
                                      Icon(Icons.business_rounded,
                                          size: 13, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        supplierName,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
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
                                      "Stok: ${product["stock"]}",
                                      Colors.blue[700]!,
                                      Icons.inventory_2_rounded,
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
                                onPressed: () =>
                                    deleteProduct(product["id"]),
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
