class OrderModel {

  final int id;
  final int total;
  final String status;
  final String createdAt;

  OrderModel({
    required this.id,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {

    return OrderModel(
      id: json['id'],
      total: json['total'],
      status: json['status'],
      createdAt: json['created_at'],
    );
  }
}