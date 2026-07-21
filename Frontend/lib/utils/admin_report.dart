// lib/utils/admin_report.dart
//
// توليد تقرير PDF قابل للطباعة/الحفظ يلخّص حالة المنصة لصاحب صلاحية الأدمن.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/models/admin_models.dart';

Future<void> printAdminReport({
  required AdminDashboardStats stats,
  required List<AdminStoreModel> stores,
  required List<AdminUserModel> users,
  required List<AdminCategoryModel> categories,
  required DateTime generatedAt,
}) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PickNGo - Admin Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Generated: ${_formatDate(generatedAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
        ],
      ),
      build: (context) => [
        _sectionTitle('Platform Overview'),
        _statsTable(stats),
        pw.SizedBox(height: 20),
        _sectionTitle('Stores by Category'),
        _categoriesTable(categories),
        pw.SizedBox(height: 20),
        _sectionTitle('Stores (${stores.length})'),
        _storesTable(stores),
        pw.SizedBox(height: 20),
        _sectionTitle('Users (${users.length})'),
        _usersTable(users),
      ],
    ),
  );

  await Printing.layoutPdf(onLayout: (_) => doc.save());
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

pw.Widget _sectionTitle(String title) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Text(title, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
  );
}

pw.Widget _statsTable(AdminDashboardStats stats) {
  final rows = [
    ['Total Users', '${stats.totalUsers}'],
    ['Total Stores', '${stats.totalStores}'],
    ['Total Orders', '${stats.totalOrders}'],
    ['Revenue', '₪${stats.revenue.toStringAsFixed(2)}'],
  ];
  return pw.TableHelper.fromTextArray(
    headers: const ['Metric', 'Value'],
    data: rows,
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    cellAlignment: pw.Alignment.centerLeft,
  );
}

pw.Widget _categoriesTable(List<AdminCategoryModel> categories) {
  return pw.TableHelper.fromTextArray(
    headers: const ['Category', 'Stores', 'Products'],
    data: categories.map((c) => [c.name, '${c.storeCount}', '${c.productCount}']).toList(),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    cellAlignment: pw.Alignment.centerLeft,
  );
}

pw.Widget _storesTable(List<AdminStoreModel> stores) {
  if (stores.isEmpty) {
    return pw.Text('No stores yet.', style: const pw.TextStyle(color: PdfColors.grey700));
  }
  return pw.TableHelper.fromTextArray(
    headers: const ['Name', 'Category', 'Address', 'Status'],
    data: stores.map((s) => [s.name, s.category ?? '-', s.address, s.approvalStatus]).toList(),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    cellAlignment: pw.Alignment.centerLeft,
    columnWidths: {
      0: const pw.FlexColumnWidth(2),
      1: const pw.FlexColumnWidth(1.5),
      2: const pw.FlexColumnWidth(3),
      3: const pw.FlexColumnWidth(1.5),
    },
  );
}

pw.Widget _usersTable(List<AdminUserModel> users) {
  if (users.isEmpty) {
    return pw.Text('No users yet.', style: const pw.TextStyle(color: PdfColors.grey700));
  }
  return pw.TableHelper.fromTextArray(
    headers: const ['Name', 'Email', 'Role'],
    data: users.map((u) => [u.fullName, u.email, u.role]).toList(),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    cellAlignment: pw.Alignment.centerLeft,
  );
}
