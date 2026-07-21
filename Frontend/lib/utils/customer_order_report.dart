// lib/utils/customer_order_report.dart
//
// تقرير PDF لطلبات الزبون (Order Report) - نفس نمط utils/admin_report.dart
// بالضبط (pw.Document + MultiPage + TableHelper + Printing.layoutPdf)، بس
// مع دعم عربي حقيقي: خط Cairo عبر PdfGoogleFonts (نفس عائلة الخط المستخدمة
// بواجهة التطبيق فعليًا - GoogleFonts.cairo بـ app_themes.dart) واتجاه RTL،
// لأنه admin_report.dart تفادى المشكلة بالكامل باستخدام إنجليزي بس.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/models/order_model.dart';

Future<void> printCustomerOrderReport({
  required String customerName,
  required int totalOrders,
  required double totalSpent,
  required DateTime? lastOrderDate,
  required List<OrderModel> orders,
  required DateTime generatedAt,
  required bool isRtl,
  required Map<String, String> labels,
}) async {
  final regularFont = await PdfGoogleFonts.cairoRegular();
  final boldFont = await PdfGoogleFonts.cairoBold();
  final direction = isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      textDirection: direction,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            labels['title'] ?? 'Order Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            textDirection: direction,
          ),
          pw.Text(
            '${labels['generated'] ?? 'Generated'}: ${_formatDate(generatedAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            textDirection: direction,
          ),
          pw.SizedBox(height: 16),
        ],
      ),
      build: (context) => [
        _sectionTitle(labels['summarySection'] ?? 'Customer Summary', direction),
        _summaryTable(
          customerName: customerName,
          totalOrders: totalOrders,
          totalSpent: totalSpent,
          lastOrderDate: lastOrderDate,
          labels: labels,
          direction: direction,
        ),
        pw.SizedBox(height: 20),
        _sectionTitle(
          '${labels['ordersSection'] ?? 'Order History'} (${orders.length})',
          direction,
        ),
        _ordersTable(orders, labels, direction),
      ],
    ),
  );

  await Printing.layoutPdf(onLayout: (_) => doc.save());
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

pw.Widget _sectionTitle(String title, pw.TextDirection direction) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Text(
      title,
      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
      textDirection: direction,
    ),
  );
}

pw.Widget _summaryTable({
  required String customerName,
  required int totalOrders,
  required double totalSpent,
  required DateTime? lastOrderDate,
  required Map<String, String> labels,
  required pw.TextDirection direction,
}) {
  final rows = [
    [labels['customerName'] ?? 'Customer', customerName],
    [labels['totalOrders'] ?? 'Total Orders', '$totalOrders'],
    [labels['totalSpent'] ?? 'Total Spent', '₪${totalSpent.toStringAsFixed(2)}'],
    [
      labels['lastOrder'] ?? 'Last Order',
      lastOrderDate != null ? _formatDate(lastOrderDate) : '-',
    ],
  ];
  return pw.TableHelper.fromTextArray(
    headers: null,
    data: rows,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    cellAlignment: direction == pw.TextDirection.rtl
        ? pw.Alignment.centerRight
        : pw.Alignment.centerLeft,
    tableDirection: direction,
    cellStyle: const pw.TextStyle(fontSize: 11),
    columnWidths: {0: const pw.FlexColumnWidth(1.4), 1: const pw.FlexColumnWidth(2)},
  );
}

pw.Widget _ordersTable(
  List<OrderModel> orders,
  Map<String, String> labels,
  pw.TextDirection direction,
) {
  if (orders.isEmpty) {
    return pw.Text(
      labels['noOrders'] ?? 'No orders',
      style: const pw.TextStyle(color: PdfColors.grey700),
      textDirection: direction,
    );
  }
  return pw.TableHelper.fromTextArray(
    headers: [
      labels['colOrder'] ?? 'Order',
      labels['colDate'] ?? 'Date',
      labels['colStore'] ?? 'Store',
      labels['colItems'] ?? 'Items',
      labels['colSubtotal'] ?? 'Subtotal',
      labels['colDeliveryFee'] ?? 'Delivery Fee',
      labels['colTotal'] ?? 'Total Paid',
      labels['colPayment'] ?? 'Payment',
      labels['colStatus'] ?? 'Status',
    ],
    data: orders.map((o) {
      final itemsSummary = o.items.map((i) => '${i.quantity}x ${i.name}').join(', ');
      return [
        o.orderNumber,
        o.orderTime != null ? _formatDate(o.orderTime!) : '-',
        o.storeName ?? '-',
        itemsSummary,
        '₪${o.totalAmount.toStringAsFixed(2)}',
        '₪${o.deliveryFee.toStringAsFixed(2)}',
        '₪${o.finalAmount.toStringAsFixed(2)}',
        o.paymentMethod,
        o.status,
      ];
    }).toList(),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    cellAlignment: direction == pw.TextDirection.rtl
        ? pw.Alignment.centerRight
        : pw.Alignment.centerLeft,
    tableDirection: direction,
    headerDirection: direction,
    cellStyle: const pw.TextStyle(fontSize: 8.5),
    columnWidths: {
      0: const pw.FlexColumnWidth(1.6),
      1: const pw.FlexColumnWidth(1.5),
      2: const pw.FlexColumnWidth(1.6),
      3: const pw.FlexColumnWidth(2.4),
      4: const pw.FlexColumnWidth(1),
      5: const pw.FlexColumnWidth(1.2),
      6: const pw.FlexColumnWidth(1.1),
      7: const pw.FlexColumnWidth(1.2),
      8: const pw.FlexColumnWidth(1),
    },
  );
}
