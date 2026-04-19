import 'package:flutter/material.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Keranjang Belanja',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        iconTheme: const IconThemeData(color: Colors.white), // Tombol kembali putih
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Daftar Item di Keranjang
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: [
                // Contoh Item 1 (Ganti URL dengan link direct imgbb Anda)
                _buildCartItem(
                  context,
                  name: 'Isi Ulang Galon Aqua',
                  price: 18000,
                  qty: 2,
                  imageUrl: 'https://i.ibb.co/vzVvK7F/galon-isi-ulang.png',
                ),
                // Contoh Item 2
                _buildCartItem(
                  context,
                  name: 'Sewa Galon (Kosong)',
                  price: 10000,
                  qty: 1,
                  imageUrl: 'https://i.ibb.co/9vP17W8/sewa-galon.png',
                ),
              ],
            ),
          ),

          // Bagian Bawah: Ringkasan Total & Tombol Checkout
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Pesanan',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    Text(
                      'Rp 46.000', // Contoh kalkulasi manual: (18k*2) + 10k
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // Logika untuk lanjut ke pembayaran
                      _showCheckoutDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Lanjut ke Checkout',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget khusus untuk baris item di dalam keranjang
  Widget _buildCartItem(
    BuildContext context, {
    required String name,
    required int price,
    required int qty,
    required String imageUrl,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Gambar Produk
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 70,
                  height: 70,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 15),
            
            // Info Produk
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Rp $price',
                    style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // Keterangan Quantity & Aksi Hapus
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'x$qty',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () {
                    // Logika hapus item
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Dialog sederhana saat klik checkout
  void _showCheckoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda ingin melanjutkan ke proses pembayaran?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ya, Lanjut'),
          ),
        ],
      ),
    );
  }
}