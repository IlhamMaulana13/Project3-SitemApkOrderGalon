import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:galonfibonacci/provider/cart_provider.dart';
import 'package:galonfibonacci/screens/auth_screen.dart';
import 'package:galonfibonacci/screens/order_screen.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import 'cart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ProductModel> products = [];

  // FILTER
  String selectedService = "Isi Ulang";
  String userName = "Pelanggan";

  @override
  void initState() {
    super.initState();
    fetchProducts();
    fetchUserName();
  }

  void fetchProducts() async {
    final result = await ApiService.getProducts();

    if (!mounted) return;

    setState(() {
      products = result;
    });
  }

  Future<void> fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final response = await ApiService.getProfile(user.uid);

      if (!mounted) return;

      setState(() {
        userName = response["name"] ?? "Pelanggan";
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // HARGA BERDASARKAN FILTER
  int getPrice() {
    if (selectedService == "Isi Ulang") {
      return 7000;
    } else if (selectedService == "Beli Baru") {
      return 45000;
    } else {
      return 2000;
    }
  }

  // WIDGET FILTER
  Widget buildFilter(String title) {
    final isSelected = selectedService == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedService = title;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo_galon.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo $userName!',
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Mau pesan galon apa hari ini?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // FILTER
          const SizedBox(height: 15),

          SizedBox(
            height: 45,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              scrollDirection: Axis.horizontal,
              children: [
                buildFilter("Isi Ulang"),
                buildFilter("Beli Baru"),
                buildFilter("Sewa"),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];

                return ProductItem(
                  product: product,
                  selectedService: selectedService,
                  price: getPrice(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductItem extends StatefulWidget {
  final ProductModel product;
  final String selectedService;
  final int price;

  const ProductItem({
    super.key,
    required this.product,
    required this.selectedService,
    required this.price,
  });

  @override
  State<ProductItem> createState() => _ProductItemState();
}

class _ProductItemState extends State<ProductItem> {
  int quantity = 1;

  bool get useStock {
    return widget.selectedService == "Beli Baru";
  }

  bool get isOutOfStock {
    return useStock && widget.product.stock <= 0;
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                widget.product.image,
                width: 70,
                height: 70,
                fit: BoxFit.cover,

                // loading
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },

                // ERROR IMAGE
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              ),
            ),

            const SizedBox(width: 12),

            // CONTENT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.merk,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.selectedService,
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "Rp ${widget.price}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.green[700],
                          ),
                        ),
                      ),

                      if (useStock)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: widget.product.stock <= 0
                                ? Colors.red.shade50
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "Stock ${widget.product.stock}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: widget.product.stock <= 0
                                  ? Colors.red
                                  : Colors.blue[700],
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // QUANTITY
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          if (quantity > 1) {
                            setState(() {
                              quantity--;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.remove, size: 18),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          "$quantity",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      InkWell(
                        onTap: () {
                          setState(() {
                            quantity++;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.add, size: 18),
                        ),
                      ),

                      const Spacer(),

                      ElevatedButton(
                        onPressed: isOutOfStock
                            ? null
                            : () {
                                final updatedProduct = ProductModel(
                                  id: widget.product.id,
                                  categoryId: widget.product.categoryId,
                                  merk:
                                      "${widget.product.merk} (${widget.selectedService})",
                                  price: widget.price,
                                  stock: widget.product.stock,
                                  image: widget.product.image,
                                );

                                cartProvider.addToCart(
                                  updatedProduct,
                                  widget.selectedService,
                                  quantity,
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "${widget.product.merk} ditambahkan",
                                    ),
                                  ),
                                );
                              },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),

                        child: Text(
                          isOutOfStock ? "Habis" : "Tambah",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
