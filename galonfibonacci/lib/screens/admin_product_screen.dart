import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminProductScreen extends StatefulWidget {
  const AdminProductScreen({super.key});

  @override
  State<AdminProductScreen> createState() =>
      _AdminProductScreenState();
}

class _AdminProductScreenState
    extends State<AdminProductScreen> {

  List products = [];

  final String baseUrl =
      "http://192.168.1.5:8080";

  @override
  void initState() {
    super.initState();

    fetchProducts();
  }

  // GET PRODUCTS
  Future<void> fetchProducts() async {

    final response = await http.get(
      Uri.parse("$baseUrl/products"),
    );

    if (response.statusCode == 200) {

      setState(() {
        products = jsonDecode(response.body);
      });
    }
  }

  // DELETE PRODUCT
  Future<void> deleteProduct(int id) async {

    final response = await http.delete(
      Uri.parse("$baseUrl/products/$id"),
    );

    if (response.statusCode == 200) {

      fetchProducts();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Produk berhasil dihapus"),
        ),
      );
    }
  }

  // DIALOG TAMBAH / EDIT
  void showProductDialog({
    Map? product,
  }) {

    final merkController =
        TextEditingController(
      text: product?["merk"] ?? "",
    );

    final priceController =
        TextEditingController(
      text: product?["price"]?.toString() ?? "",
    );

    final stockController =
        TextEditingController(
      text: product?["stock"]?.toString() ?? "",
    );

    final imageController =
        TextEditingController(
      text: product?["image"] ?? "",
    );

    showDialog(
      context: context,

      builder: (_) {

        return AlertDialog(

          title: Text(
            product == null
                ? "Tambah Produk"
                : "Edit Produk",
          ),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [

                TextField(
                  controller: merkController,

                  decoration: const InputDecoration(
                    labelText: "Merk",
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: priceController,

                  keyboardType:
                      TextInputType.number,

                  decoration: const InputDecoration(
                    labelText: "Harga",
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: stockController,

                  keyboardType:
                      TextInputType.number,

                  decoration: const InputDecoration(
                    labelText: "Stock",
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: imageController,

                  decoration: const InputDecoration(
                    labelText: "Image URL",
                  ),
                ),
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

                final body = {

                  "category_id": 1,
                  "merk":
                      merkController.text,

                  "price": int.parse(
                    priceController.text,
                  ),

                  "stock": int.parse(
                    stockController.text,
                  ),

                  "image":
                      imageController.text,
                };

                http.Response response;

                // ADD
                if (product == null) {

                  response = await http.post(
                    Uri.parse(
                      "$baseUrl/products",
                    ),

                    headers: {
                      "Content-Type":
                          "application/json",
                    },

                    body: jsonEncode(body),
                  );
                }

                // EDIT
                else {

                  response = await http.put(
                    Uri.parse(
                      "$baseUrl/products/${product["id"]}",
                    ),

                    headers: {
                      "Content-Type":
                          "application/json",
                    },

                    body: jsonEncode(body),
                  );
                }

                if (response.statusCode == 200) {

                  Navigator.pop(context);

                  fetchProducts();

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
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
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.grey[100],

      appBar: AppBar(

        title: const Text(
          "Kelola Produk",
          style: TextStyle(
            color: Colors.white,
          ),
        ),

        backgroundColor: Colors.blue[700],

        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),

      floatingActionButton:
          FloatingActionButton(

        backgroundColor: Colors.blue[700],

        onPressed: () {
          showProductDialog();
        },

        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),

      body: ListView.builder(

        padding: const EdgeInsets.all(15),

        itemCount: products.length,

        itemBuilder: (context, index) {

          final product = products[index];

          return Card(

            margin:
                const EdgeInsets.only(bottom: 15),

            child: ListTile(

              leading: Image.network(
                product["image"],
                width: 60,
                fit: BoxFit.cover,
              ),

              title: Text(
                product["merk"],
              ),

              subtitle: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Text(
                    "Rp ${product["price"]}",
                  ),

                  Text(
                    "Stock: ${product["stock"]}",
                  ),
                ],
              ),

              trailing: Row(
                mainAxisSize: MainAxisSize.min,

                children: [

                  IconButton(
                    onPressed: () {
                      showProductDialog(
                        product: product,
                      );
                    },

                    icon: const Icon(
                      Icons.edit,
                      color: Colors.orange,
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      deleteProduct(
                        product["id"],
                      );
                    },

                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
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