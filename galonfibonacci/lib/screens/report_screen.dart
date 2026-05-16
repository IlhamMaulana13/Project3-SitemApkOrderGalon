import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/report_model.dart';
import '../services/api_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {

  List<ReportModel> reports = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  void fetchReports() async {

    final result = await ApiService.getReports();

    setState(() {
      reports = result;
      isLoading = false;
    });
  }

  Future<void> printPdf() async {

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [

          pw.Text(
            "Laporan Penjualan Galon",
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 20),

          pw.Table.fromTextArray(
            headers: [
              "ID",
              "Customer",
              "Total",
              "Status",
            ],

            data: reports.map((e) => [

              e.id.toString(),
              e.name,
              "Rp ${e.total}",
              e.status,

            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  int getTotalRevenue() {

    int total = 0;

    for (var item in reports) {
      total += item.total;
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: const Text("Laporan"),
        actions: [

          IconButton(
            onPressed: printPdf,
            icon: const Icon(Icons.print),
          ),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )

          : Column(
              children: [

                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(15),
                  padding: const EdgeInsets.all(15),

                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(15),
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const Text(
                        "Total Pendapatan",
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "Rp ${getTotalRevenue()}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(

                    itemCount: reports.length,

                    itemBuilder: (context, index) {

                      final report = reports[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 8,
                        ),

                        child: ListTile(

                          leading: CircleAvatar(
                            child: Text(report.id.toString()),
                          ),

                          title: Text(report.name),

                          subtitle: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [

                              Text("Rp ${report.total}"),

                              Text(report.status),
                            ],
                          ),

                          trailing: Text(
                            report.createdAt
                                .substring(0, 10),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}