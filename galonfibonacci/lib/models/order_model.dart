class OrderModel {

  final int id;
  final int total;
  final String status;
  final String createdAt;
  final String paymentStatus;

  OrderModel({
    required this.id,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.paymentStatus,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {

    return OrderModel(
      id: json['id'],
      total: json['total'],
      status: json['status'],
      createdAt: json['created_at'],
      paymentStatus: json["payment_status"] ?? "pending",
    );
  }

  void operator [](String other) {}
}