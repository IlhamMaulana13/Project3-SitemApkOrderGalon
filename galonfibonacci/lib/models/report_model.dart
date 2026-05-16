class ReportModel {
  final int id;
  final String name;
  final int total;
  final String status;
  final String createdAt;

  ReportModel({
    required this.id,
    required this.name,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json["id"],
      name: json["name"],
      total: json["total"],
      status: json["status"],
      createdAt: json["created_at"],
    );
  }
}