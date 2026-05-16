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

  final String baseUrl = "${ApiConfig.baseUrl}";

  File? selectedImage;

  @override
  void initState() {
    super.initState();

    fetchProducts();
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

  // PICK IMAGE
  Future<void> pickImage() async {
    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        selectedImage = File(pickedFile.path);
      });
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
      final responseData = await response.stream.bytesToString();

      final data = jsonDecode(responseData);

      return data["data"]["url"];
    }

    return null;
  }

  // DELETE PRODUCT
  Future<void> deleteProduct(int id) async {
    final response = await http.delete(Uri.parse("$baseUrl/products/$id"));

    if (response.statusCode == 200) {
      fetchProducts();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Produk berhasil dihapus")));
    }
  }

  // DIALOG ADD / EDIT
  void showProductDialog({Map? product}) {
    selectedImage = null;

    final merkController = TextEditingController(text: product?["merk"] ?? "");

    final priceController = TextEditingController(
      text: product?["price"]?.toString() ?? "",
    );

    final stockController = TextEditingController(
      text: product?["stock"]?.toString() ?? "",
    );

    showDialog(
      context: context,

      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(product == null ? "Tambah Produk" : "Edit Produk"),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    TextField(
                      controller: merkController,

                      decoration: const InputDecoration(labelText: "Merk"),
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller: priceController,

                      keyboardType: TextInputType.number,

                      decoration: const InputDecoration(labelText: "Harga"),
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller: stockController,

                      keyboardType: TextInputType.number,

                      decoration: const InputDecoration(labelText: "Stock"),
                    ),

                    const SizedBox(height: 15),

                    ElevatedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();

                        final pickedFile = await picker.pickImage(
                          source: ImageSource.gallery,
                        );

                        if (pickedFile != null) {
                          setModalState(() {
                            selectedImage = File(pickedFile.path);
                          });
                        }
                      },

                      icon: const Icon(Icons.image),

                      label: const Text("Pilih Gambar"),
                    ),

                    const SizedBox(height: 10),

                    selectedImage != null
                        ? Image.file(selectedImage!, height: 120)
                        : product != null
                        ? Image.network(product["image"], height: 120)
                        : const SizedBox(),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },

                  child: const Text("Batal"),
                ),

                ElevatedButton(
                  onPressed: () async {
                    String imageUrl = product?["image"] ?? "";

                    if (selectedImage != null) {
                      final uploadedUrl = await uploadImageToImgBB();

                      if (uploadedUrl != null) {
                        imageUrl = uploadedUrl;
                      }
                    }

                    final body = {
                      "category_id": 1,

                      "merk": merkController.text,

                      "price": int.parse(priceController.text),

                      "stock": int.parse(stockController.text),

                      "image": imageUrl,
                    };

                    http.Response response;

                    // ADD
                    if (product == null) {
                      response = await http.post(
                        Uri.parse("$baseUrl/products"),

                        headers: {"Content-Type": "application/json"},

                        body: jsonEncode(body),
                      );
                    }
                    // EDIT
                    else {
                      response = await http.put(
                        Uri.parse("$baseUrl/products/${product["id"]}"),

                        headers: {"Content-Type": "application/json"},

                        body: jsonEncode(body),
                      );
                    }

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
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[700],

        onPressed: () {
          showProductDialog();
        },

        child: const Icon(Icons.add, color: Colors.white),
      ),

      body: ListView.builder(
        padding: const EdgeInsets.all(15),

        itemCount: products.length,

        itemBuilder: (context, index) {
          final product = products[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 15),

            child: ListTile(
              leading: Image.network(
                product["image"],
                width: 60,
                fit: BoxFit.cover,
              ),

              title: Text(product["merk"]),

              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text("Rp ${product["price"]}"),

                  Text("Stock: ${product["stock"]}"),
                ],
              ),

              trailing: Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  IconButton(
                    onPressed: () {
                      showProductDialog(product: product);
                    },

                    icon: const Icon(Icons.edit, color: Colors.orange),
                  ),

                  IconButton(
                    onPressed: () {
                      deleteProduct(product["id"]);
                    },

                    icon: const Icon(Icons.delete, color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
