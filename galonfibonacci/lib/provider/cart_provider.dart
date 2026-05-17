import 'package:flutter/material.dart';
import '../models/cart_model.dart';
import '../models/product_model.dart';

class CartProvider extends ChangeNotifier {
  final List<CartModel> _items = [];

  List<CartModel> get items => _items;

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  void addToCart(ProductModel product, String service, int quantity) {
    final index = _items.indexWhere(
      (item) => item.product.id == product.id && item.service == service,
    );

    if (index != -1) {
      _items[index].quantity += quantity;
    } else {
      _items.add(
        CartModel(product: product, service: service, quantity: quantity),
      );
    }

    notifyListeners();
  }

  void removeItem(int productId, String service) {
    _items.removeWhere(
      (item) => item.product.id == productId && item.service == service,
    );

    notifyListeners();
  }

  int get total {
    int total = 0;

    for (var item in _items) {
      total += item.subtotal;
    }

    return total;
  }
}
