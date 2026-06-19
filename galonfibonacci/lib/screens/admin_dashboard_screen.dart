import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:galonfibonacci/api_config.dart';
import 'package:galonfibonacci/provider/theme_provider.dart';
import 'package:galonfibonacci/screens/admin_order_screen.dart';
import 'package:galonfibonacci/screens/admin_product_screen.dart';
import 'package:galonfibonacci/screens/admin_rental_screen.dart';
import 'package:galonfibonacci/screens/admin_role_screen.dart';
import 'package:galonfibonacci/screens/admin_voucher_screen.dart';
import 'package:galonfibonacci/screens/login_screen.dart';
import 'package:galonfibonacci/screens/report_screen.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? dashboard;

  @override
  void initState() {
    super.initState();
    fetchDashboard();
  }

  Future<void> fetchDashboard() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/dashboard"),
    );
    if (response.statusCode == 200) {
      setState(() {
        dashboard = jsonDecode(response.body);
      });
    }
  }

  // =========================
  // SIDEBAR DRAWER
  // =========================
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
            decoration: BoxDecoration(color: Colors.blue[700]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Admin Panel',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Galon Rizzki Faras',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _drawerItem(
            context,
            icon: Icons.dashboard_rounded,
            title: 'Dashboard',
            color: Colors.blue[700]!,
            isActive: true,
            screen: null,
          ),
          _drawerItem(
            context,
            icon: Icons.inventory_2_rounded,
            title: 'Kelola Produk',
            color: Colors.blue[600]!,
            screen: const AdminProductScreen(),
          ),
          _drawerItem(
            context,
            icon: Icons.receipt_long_rounded,
            title: 'Kelola Pesanan',
            color: Colors.orange,
            screen: const AdminOrderScreen(),
          ),
          _drawerItem(
            context,
            icon: Icons.print_rounded,
            title: 'Cetak Laporan',
            color: Colors.green,
            screen: const ReportScreen(),
          ),
          _drawerItem(
            context,
            icon: Icons.local_offer_rounded,
            title: 'Kelola Voucher',
            color: Colors.purple,
            screen: const AdminVoucherScreen(),
          ),
          _drawerItem(
            context,
            icon: Icons.water_drop_rounded,
            title: 'Pencatatan Sewa',
            color: Colors.indigo,
            screen: const AdminRentalScreen(),
          ),
          _drawerItem(
            context,
            icon: Icons.manage_accounts_rounded,
            title: 'Kelola Role',
            color: Colors.teal,
            screen: const AdminRoleScreen(),
          ),
          const Spacer(),
          const Divider(height: 1),
          Builder(builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.logout_rounded, color: Colors.red[isDark ? 300 : 600], size: 20),
              ),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red[isDark ? 300 : 600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            onTap: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    Widget? screen,
    bool isActive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50]!;
    final textColor = isActive
        ? Colors.blue[isDark ? 300 : 700]!
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
            fontSize: 14,
          ),
        ),
        trailing: isActive
            ? Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.blue[isDark ? 300 : 700],
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          Navigator.pop(context);
          if (screen != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
          }
        },
      ),
    );
  }

  // =========================
  // STAT CARD (POINT UTAMA)
  // =========================
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final cardBg = Theme.of(context).cardColor;
    final subtitleColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: subtitleColor, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChartSection() {
    final products = dashboard!['best_products'] as List<dynamic>;
    final colors = [Colors.blue, Colors.orange, Colors.green, Colors.purple];
    final chartItems = products.take(3).toList().asMap().entries.map((entry) {
      final item = entry.value;
      final index = entry.key;
      return {
        'label': item['merk'] ?? 'Unknown',
        'value': (item['total'] ?? 0) as int,
        'color': colors[index % colors.length],
      };
    }).toList();

    final maxValue = chartItems.isEmpty
        ? 1
        : chartItems
              .map((item) => item['value'] as int)
              .reduce((a, b) => a > b ? a : b);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final barBgColor = isDark ? const Color(0xFF3A3A3C) : Colors.grey[200]!;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grafik Penjualan Produk',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Perbandingan penjualan 3 merk terbaik.',
              style: TextStyle(color: subtitleColor, fontSize: 13),
            ),
            const SizedBox(height: 18),
            ...chartItems.map((item) {
              final value = item['value'] as int;
              final label = item['label'] as String;
              final color = item['color'] as Color;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: subtitleColor,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: barBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: maxValue == 0 ? 0 : value / maxValue,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$value',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: Text(
          "Dashboard Admin",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) => IconButton(
              icon: Icon(
                themeProvider.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: Colors.white,
              ),
              tooltip: themeProvider.isDarkMode ? 'Mode Terang' : 'Mode Gelap',
              onPressed: () => themeProvider.toggleTheme(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: fetchDashboard,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: dashboard == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =====================
                    // HEADER SELAMAT DATANG
                    // =====================
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.blue[800]!, Colors.blue[600]!],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.analytics_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Halo, Admin!',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pantau performa bisnis galon dalam satu tampilan.',
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // =====================
                    // POINT UTAMA (4 KPI)
                    // =====================
                    Text(
                      'Ringkasan Bisnis',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _buildStatCard(
                          title: 'Total Produk',
                          value: dashboard!["total_products"].toString(),
                          icon: Icons.inventory_2_rounded,
                          color: Colors.blue[700]!,
                        ),
                        _buildStatCard(
                          title: 'Total Customer',
                          value: dashboard!["total_customers"].toString(),
                          icon: Icons.people_rounded,
                          color: Colors.teal,
                        ),
                        _buildStatCard(
                          title: 'Laba Bulan Ini',
                          value: 'Rp ${dashboard!["monthly_profit"] ?? 0}',
                          icon: Icons.trending_up_rounded,
                          color: Colors.green,
                        ),
                        _buildStatCard(
                          title: 'Order Diproses',
                          value: '${dashboard!["pending_orders"] ?? 0}',
                          icon: Icons.pending_actions_rounded,
                          color: Colors.orange,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // =====================
                    // TOTAL PENDAPATAN
                    // =====================
                    Builder(builder: (context) {
                      final subtitleColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Pendapatan',
                                    style: TextStyle(color: subtitleColor, fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Rp ${dashboard!["total_revenue"]}',
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Order',
                                    style: TextStyle(color: subtitleColor, fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${dashboard!["total_orders"]} order',
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 20),

                    // =====================
                    // MENU NAVIGASI CEPAT
                    // =====================
                    Text(
                      'Menu Admin',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      children: [
                        _buildMenuCard(
                          context,
                          icon: Icons.inventory_2_rounded,
                          title: 'Produk',
                          color: Colors.blue[700]!,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminProductScreen(),
                            ),
                          ),
                        ),
                        _buildMenuCard(
                          context,
                          icon: Icons.receipt_long_rounded,
                          title: 'Pesanan',
                          color: Colors.orange,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminOrderScreen(),
                            ),
                          ),
                        ),
                        _buildMenuCard(
                          context,
                          icon: Icons.print_rounded,
                          title: 'Laporan',
                          color: Colors.green,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReportScreen(),
                            ),
                          ),
                        ),
                        _buildMenuCard(
                          context,
                          icon: Icons.local_offer_rounded,
                          title: 'Voucher',
                          color: Colors.purple,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminVoucherScreen(),
                            ),
                          ),
                        ),
                        _buildMenuCard(
                          context,
                          icon: Icons.water_drop_rounded,
                          title: 'Sewa Galon',
                          color: Colors.indigo,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminRentalScreen(),
                            ),
                          ),
                        ),
                        _buildMenuCard(
                          context,
                          icon: Icons.manage_accounts_rounded,
                          title: 'Kelola Role',
                          color: Colors.teal,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminRoleScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // =====================
                    // GRAFIK PENJUALAN
                    // =====================
                    _buildSalesChartSection(),
                  ],
                ),
              ),
            ),
    );
  }
}
