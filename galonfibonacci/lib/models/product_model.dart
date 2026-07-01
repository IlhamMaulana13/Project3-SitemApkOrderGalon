class ProductModel {
  final int id;
  final int categoryId;
  final String merk;
  final int price;
  // Stok dipisah: stok baru (untuk "Beli Baru") dan stok sewa (untuk "Sewa").
  final int stockNew;
  final int stockRental;
  final int reservedStockNew;
  final int reservedStockRental;
  final String image;

  ProductModel({
    required this.id,
    required this.categoryId,
    required this.merk,
    required this.price,
    required this.stockNew,
    required this.stockRental,
    required this.reservedStockNew,
    required this.reservedStockRental,
    required this.image,
  });

  // Sisa stok yang benar-benar tersedia (sudah dikurangi yang direservasi).
  int get availableNew => stockNew - reservedStockNew;
  int get availableRental => stockRental - reservedStockRental;

  // Stok tersedia sesuai jenis layanan yang dipilih pelanggan.
  int availableFor(String service) {
    if (service == "Sewa") return availableRental;
    if (service == "Beli Baru") return availableNew;
    return 0; // Isi Ulang tidak memakai stok
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: _asInt(json['id']),
      categoryId: _asInt(json['category_id']),
      merk: json['merk'] ?? '',
      price: _asInt(json['price']),
      stockNew: _asInt(json['stock_new']),
      stockRental: _asInt(json['stock_rental']),
      reservedStockNew: _asInt(json['reserved_stock_new']),
      reservedStockRental: _asInt(json['reserved_stock_rental']),
      image: json['image'] ?? '',
    );
  }
}
