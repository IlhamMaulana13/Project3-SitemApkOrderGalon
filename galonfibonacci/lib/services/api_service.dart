import 'dart:convert';

import 'package:galonfibonacci/models/order_model.dart';
import 'package:galonfibonacci/models/report_model.dart';
import 'package:http/http.dart' as http;

import '../models/cart_model.dart';
import '../models/product_model.dart';
import 'package:galonfibonacci/api_config.dart';

class ApiService {
  static const String baseUrl = "${ApiConfig.baseUrl}";

  // GET PRODUCTS
  static Future<List<ProductModel>> getProducts() async {
    final response = await http.get(Uri.parse("$baseUrl/products"));

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);

      return data.map((item) => ProductModel.fromJson(item)).toList();
    } else {
      throw Exception("Failed to load products");
    }
  }

  // CHECKOUT
  static Future<bool> checkout(List<CartModel> cartItems, int total) async {
    final body = {
      "user_id": "firebase_uid_123",
      "payment_method_id": 1,
      "total": total,
      "items": cartItems.map((item) {
        return {
          "product_id": item.product.id,
          "qty": item.quantity,
          "subtotal": item.subtotal,
        };
      }).toList(),
    };

    final response = await http.post(
      Uri.parse("$baseUrl/orders"),

      headers: {"Content-Type": "application/json"},

      body: jsonEncode(body),
    );

    return response.statusCode == 200;
  }

  static Future<List<OrderModel>> getOrders() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/orders"));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // kalau null atau bukan List
        if (data == null || data is! List) {
          return [];
        }

        return data
            .map<OrderModel>((item) => OrderModel.fromJson(item))
            .toList();
      } else {
        print(response.body);

        return [];
      }
    } catch (e) {
      print(e);

      return [];
    }
  }

  static Future<List<ReportModel>> getReports() async {

  final response = await http.get(
    Uri.parse("$baseUrl/reports"),
  );

  if (response.statusCode == 200) {

    final data = jsonDecode(response.body);

    return List<ReportModel>.from(
      data.map((e) => ReportModel.fromJson(e)),
    );
  }

  return [];
}
}
