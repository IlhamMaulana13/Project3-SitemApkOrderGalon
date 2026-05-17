import 'product_model.dart';

class CartModel {
  final ProductModel product;
  final String service;
  int quantity;

  CartModel({
    required this.product,
    required this.service,
    required this.quantity,
  });

  int get subtotal => product.price * quantity;
}
