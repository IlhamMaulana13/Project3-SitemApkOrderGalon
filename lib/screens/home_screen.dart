import 'package:flutter/material.dart';
import 'package:galonfibonacci/screens/cart_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Galon Fibonacci',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: () {
              // Navigasi ke Halaman Keranjang
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner / Ucapan Selamat Datang
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo Pelanggan!',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
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

          // Daftar Produk
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: const [
                // GANTI URL DI BAWAH DENGAN DIRECT LINK IMGBB ANDA
                ProductItem(
                  name: 'Isi Ulang Galon Aqua',
                  price: 7000,
                  imageUrl:
                      'https://i.ibb.co.com/rRzSxNZ3/Galon-Aqua-Kosong-Tempat-Air-Kapasitar-19-L.jpg',
                ),
                ProductItem(
                  name: 'Galon Baru + Isi',
                  price: 45000,
                  imageUrl:
                      'https://i.ibb.co.com/rRzSxNZ3/Galon-Aqua-Kosong-Tempat-Air-Kapasitar-19-L.jpg',
                ),
                ProductItem(
                  name: 'Sewa Galon (Kosong)',
                  price: 2000,
                  imageUrl:
                      'https://i.ibb.co.com/rRzSxNZ3/Galon-Aqua-Kosong-Tempat-Air-Kapasitar-19-L.jpg',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductItem extends StatefulWidget {
  final String name;
  final int price;
  final String imageUrl;

  const ProductItem({
    super.key,
    required this.name,
    required this.price,
    required this.imageUrl,
  });

  @override
  State<ProductItem> createState() => _ProductItemState();
}

class _ProductItemState extends State<ProductItem> {
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Gambar Produk dari URL
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                widget.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                // Loading saat gambar diunduh
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                // Jika URL error/mati
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 15),

            // Info Produk
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Rp ${widget.price}',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            // Kontrol Qty & Tombol Tambah
            Column(
              children: [
                Row(
                  children: [
                    _qtyButton(Icons.remove, () {
                      if (quantity > 1) setState(() => quantity--);
                    }),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '$quantity',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _qtyButton(Icons.add, () {
                      setState(() => quantity++);
                    }),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${widget.name} ditambahkan!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Tambah'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget kecil untuk tombol + dan -
  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: Icon(icon, size: 16, color: Colors.blue[700]),
      ),
    );
  }
}
