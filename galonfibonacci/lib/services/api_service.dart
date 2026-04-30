import 'dart:convert';

import 'package:http/http.dart' as http;
import '../models/product_model.dart';

class ApiService {

  static const String baseUrl = "http://10.0.2.2:8080";

  static Future<List<ProductModel>> getProducts() async {

    final response = await http.get(
      Uri.parse("$baseUrl/products"),
    );

    if (response.statusCode == 200) {

      List data = jsonDecode(response.body);

      return data
          .map((item) => ProductModel.fromJson(item))
          .toList();

    } else {
      throw Exception("Failed to load products");
    }
  }
}