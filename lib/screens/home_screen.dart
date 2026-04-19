import 'package:flutter/material.dart';
import '../models/product_model.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GalonKu - Pilih Produk'),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () {
              // TODO: Navigasi ke halaman Keranjang
            },
          )
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: dummyProducts.length,
        itemBuilder: (ctx, i) {
          final product = dummyProducts[i];
          return Card(
            elevation: 3,
            margin: EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: Icon(Icons.water_drop, size: 40, color: Colors.blue), // Placeholder gambar galon
              title: Text(product.name, style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Kategori: ${product.category}\nRp ${product.price}',
              ),
              isThreeLine: true,
              trailing: ElevatedButton(
                onPressed: () {
                  // TODO: Logika tambah ke keranjang
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${product.name} ditambahkan ke keranjang!')),
                  );
                },
                child: Text('+ Keranjang'),
              ),
            ),
          );
        },
      ),
    );
  }
}