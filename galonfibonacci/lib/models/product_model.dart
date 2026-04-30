class Product {
  final String id;
  final String name;
  final int price;
  final String category;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
  });
}

// Data sementara untuk tes UI
List<Product> dummyProducts = [
  Product(id: 'p1', name: 'Isi Ulang Galon Aqua', price: 20000, category: 'Isi Ulang'),
  Product(id: 'p2', name: 'Galon Baru Aqua', price: 50000, category: 'Beli Baru'),
  Product(id: 'p3', name: 'Sewa Galon Kosong', price: 15000, category: 'Sewa'),
];