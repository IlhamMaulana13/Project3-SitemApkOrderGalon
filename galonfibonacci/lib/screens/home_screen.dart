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

  String selectedService = "Isi Ulang";
  String userName = "Pelanggan";

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchProducts();
    fetchUserName();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<ProductModel> get filteredProducts {
    if (_searchQuery.isEmpty) return products;
    return products
        .where((p) => p.merk.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // Ambil harga dari product.price jika ada, fallback ke service price
  int getPrice() {
    // Cek apakah product memiliki field price (dari API)
    // Jika product sudah ada price field, gunakan itu
    // Fallback: gunakan service-based pricing
    if (selectedService == "Isi Ulang") return 7000;
    if (selectedService == "Beli Baru") return 45000;
    return 2000; // Sewa
  }

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
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
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
          // HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo_galon.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Halo $userName!',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Mau pesan galon apa hari ini?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // SEARCH BAR
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.blue[700],
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.grey[500],
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // FILTER LAYANAN
          SizedBox(
            height: 44,
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

          // LABEL HASIL PENCARIAN
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Hasil pencarian: "$_searchQuery"  •  ${filteredProducts.length} produk',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // DAFTAR PRODUK
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Belum ada produk'
                              : 'Produk "$_searchQuery" tidak ditemukan',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 4,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
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

  bool get useStock => widget.selectedService == "Beli Baru";
  bool get isOutOfStock => useStock && widget.product.stock <= 0;

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                widget.product.image,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.blue[50],
                  child: Icon(
                    Icons.local_drink_rounded,
                    color: Colors.blue[300],
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.merk,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
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
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // HARGA — terpampang jelas
                  Text(
                    "Rp ${widget.price}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.green[700],
                    ),
                  ),
                  if (useStock) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 13,
                          color: widget.product.stock <= 0
                              ? Colors.red
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Stok: ${widget.product.stock}",
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.product.stock <= 0
                                ? Colors.red
                                : Colors.grey[600],
                            fontWeight: widget.product.stock <= 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (quantity > 1) setState(() => quantity--);
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        "$quantity",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => quantity++),
                      icon: const Icon(Icons.add_circle_outline),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOutOfStock
                        ? Colors.grey[300]
                        : Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
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
                  child: Text(
                    isOutOfStock ? "Habis" : "Tambah",
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
