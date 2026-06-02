import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/report_model.dart';
import '../services/api_service.dart';

enum ReportFilterType { all, date, month }

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<ReportModel> reports = [];
  bool isLoading = true;
  ReportFilterType selectedFilter = ReportFilterType.all;
  DateTime? selectedDate;
  DateTime? selectedMonth;

  List<ReportModel> get filteredReports {
    if (selectedFilter == ReportFilterType.date && selectedDate != null) {
      return reports.where((report) {
        final createdAt = DateTime.tryParse(report.createdAt);
        return createdAt != null &&
            createdAt.year == selectedDate!.year &&
            createdAt.month == selectedDate!.month &&
            createdAt.day == selectedDate!.day;
      }).toList();
    }

    if (selectedFilter == ReportFilterType.month && selectedMonth != null) {
      return reports.where((report) {
        final createdAt = DateTime.tryParse(report.createdAt);
        return createdAt != null &&
            createdAt.year == selectedMonth!.year &&
            createdAt.month == selectedMonth!.month;
      }).toList();
    }

    return reports;
  }

  String get filterLabel {
    if (selectedFilter == ReportFilterType.date && selectedDate != null) {
      return "Tanggal: ${selectedDate!.day.toString().padLeft(2, '0')}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.year}";
    }

    if (selectedFilter == ReportFilterType.month && selectedMonth != null) {
      return "Bulan: ${_formatMonth(selectedMonth!)} ${selectedMonth!.year}";
    }

    return 'Semua transaksi';
  }

  String _formatMonth(DateTime date) {
    const monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return monthNames[date.month - 1];
  }

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

  Future<void> selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        selectedFilter = ReportFilterType.date;
        selectedDate = date;
        selectedMonth = null;
      });
    }
  }

  Future<void> selectMonth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedMonth ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Pilih bulan untuk filter',
    );

    if (date != null) {
      setState(() {
        selectedFilter = ReportFilterType.month;
        selectedMonth = DateTime(date.year, date.month);
        selectedDate = null;
      });
    }
  }

  Future<void> printPdf() async {
    final doc = pw.Document();

    final Uint8List logoBytes = (await rootBundle.load(
      'assets/images/logo_galon.png',
    )).buffer.asUint8List();

    final logoImage = pw.MemoryImage(logoBytes);

    final primaryColor = pdf.PdfColor.fromHex('#1976D2');
    final lightBlue = pdf.PdfColor.fromHex('#E3F2FD');
    final darkText = pdf.PdfColor.fromHex('#212121');

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),

        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              "Dicetak pada ${DateTime.now().toString().substring(0, 16)}",
              style: const pw.TextStyle(fontSize: 8),
            ),
          );
        },

        build: (context) => [
          // HEADER
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 70,
                  height: 70,
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: pdf.PdfColors.white, width: 1),
                  ),
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),

                pw.SizedBox(width: 15),

                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "GALON RIZZKI FARAS",
                        style: pw.TextStyle(
                          color: pdf.PdfColors.white,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),

                      pw.SizedBox(height: 5),

                      pw.Text(
                        "Alamat: 6°08'20.7\"S 106°31'51.0\"E",
                        style: const pw.TextStyle(
                          color: pdf.PdfColors.white,
                          fontSize: 10,
                        ),
                      ),

                      pw.SizedBox(height: 3),

                      pw.Text(
                        "+62 895 1574 9884",
                        style: const pw.TextStyle(
                          color: pdf.PdfColors.white,
                          fontSize: 10,
                        ),
                      ),

                      pw.Text(
                        "galonrizzkifaras@gmail.com",
                        style: const pw.TextStyle(
                          color: pdf.PdfColors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // JUDUL
          pw.Center(
            child: pw.Text(
              "LAPORAN PENJUALAN",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),

          pw.SizedBox(height: 5),

          pw.Center(
            child: pw.Text(
              filterLabel,
              style: pw.TextStyle(color: pdf.PdfColors.grey700, fontSize: 11),
            ),
          ),

          pw.SizedBox(height: 20),

          // TOTAL PENDAPATAN
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: lightBlue,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: primaryColor),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Total Pendapatan",
                  style: pw.TextStyle(
                    color: darkText,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.Text(
                  "Rp ${getTotalRevenue()}",
                  style: pw.TextStyle(
                    color: primaryColor,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // TABEL
          pw.Table.fromTextArray(
            headers: const ["ID", "Customer", "Total", "Status", "Tanggal"],

            headerDecoration: pw.BoxDecoration(color: primaryColor),

            headerStyle: pw.TextStyle(
              color: pdf.PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
            ),

            cellStyle: pw.TextStyle(color: darkText, fontSize: 10),

            oddRowDecoration: pw.BoxDecoration(color: lightBlue),

            border: pw.TableBorder.all(
              color: pdf.PdfColors.grey400,
              width: 0.5,
            ),

            cellAlignment: pw.Alignment.centerLeft,

            data: filteredReports.map((e) {
              return [
                e.id.toString(),
                e.name,
                "Rp ${e.total}",
                e.status,
                e.createdAt.substring(0, 10),
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 20),

          // SUMMARY
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  "Jumlah Transaksi",
                  style: pw.TextStyle(color: pdf.PdfColors.grey700),
                ),

                pw.Text(
                  "${filteredReports.length}",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  int getTotalRevenue() {
    int total = 0;

    for (var item in filteredReports) {
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
          IconButton(onPressed: printPdf, icon: const Icon(Icons.print)),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Semua'),
                                  selected:
                                      selectedFilter == ReportFilterType.all,
                                  onSelected: (_) {
                                    setState(() {
                                      selectedFilter = ReportFilterType.all;
                                      selectedDate = null;
                                      selectedMonth = null;
                                    });
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Per tanggal'),
                                  selected:
                                      selectedFilter == ReportFilterType.date,
                                  onSelected: (_) {
                                    setState(() {
                                      selectedFilter = ReportFilterType.date;
                                      selectedMonth = null;
                                    });
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Per bulan'),
                                  selected:
                                      selectedFilter == ReportFilterType.month,
                                  onSelected: (_) {
                                    setState(() {
                                      selectedFilter = ReportFilterType.month;
                                      selectedDate = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                filterLabel,
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: selectedFilter == ReportFilterType.all
                                ? null
                                : selectedFilter == ReportFilterType.date
                                ? selectDate
                                : selectMonth,
                            icon: const Icon(Icons.calendar_month),
                            label: Text(
                              selectedFilter == ReportFilterType.date
                                  ? 'Pilih tanggal'
                                  : selectedFilter == ReportFilterType.month
                                  ? 'Pilih bulan'
                                  : 'Pilih',
                            ),
                          ),
                          if (selectedFilter != ReportFilterType.all &&
                              (selectedDate != null || selectedMonth != null))
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    selectedFilter = ReportFilterType.all;
                                    selectedDate = null;
                                    selectedMonth = null;
                                  });
                                },
                                child: const Text('Reset'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 15),
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
                        style: TextStyle(color: Colors.white70),
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
                  child: filteredReports.isEmpty
                      ? const Center(
                          child: Text('Tidak ada transaksi untuk filter ini.'),
                        )
                      : ListView.builder(
                          itemCount: filteredReports.length,
                          itemBuilder: (context, index) {
                            final report = filteredReports[index];

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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Rp ${report.total}"),
                                    Text(report.status),
                                  ],
                                ),
                                trailing: Text(
                                  report.createdAt.substring(0, 10),
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
