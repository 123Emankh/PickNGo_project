// lib/screens/settings/order_report_screen.dart
//
// تقرير طلبات الزبون: ملخص (عدد الطلبات/إجمالي الإنفاق/آخر طلب) + سجل
// الطلبات بفلترة تاريخ (أسبوع/شهر/مدى مخصص) + تصدير PDF. بيعيد استخدام
// GET /api/orders/my الموجود أصلاً (بفلترة تاريخ اختيارية جديدة) و
// OrderDetailsDialog الموجودة أصلاً لعرض تفاصيل أي طلب - بدون أي جدول أو
// نظام موازي جديد.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/app_card.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_themes.dart';
import '../../utils/customer_order_report.dart';
import '../orders/order_details_dialog.dart';

enum _ReportFilter { all, week, month, custom }

class OrderReportScreen extends ConsumerStatefulWidget {
  const OrderReportScreen({super.key});

  @override
  ConsumerState<OrderReportScreen> createState() => _OrderReportScreenState();
}

class _OrderReportScreenState extends ConsumerState<OrderReportScreen> {
  static const Color brandColor = AppColors.brand;

  final _orderService = OrderService();
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  List<OrderModel> _orders = [];
  _ReportFilter _filter = _ReportFilter.all;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ({DateTime? from, DateTime? to}) _rangeForFilter() {
    final now = DateTime.now();
    switch (_filter) {
      case _ReportFilter.week:
        return (from: now.subtract(const Duration(days: 7)), to: null);
      case _ReportFilter.month:
        return (from: DateTime(now.year, now.month - 1, now.day), to: null);
      case _ReportFilter.custom:
        return _customRange != null
            ? (from: _customRange!.start, to: _customRange!.end)
            : (from: null, to: null);
      case _ReportFilter.all:
        return (from: null, to: null);
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final range = _rangeForFilter();
    final result = await _orderService.getMyOrders(from: range.from, to: range.to);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) {
        _orders = result.orders;
      } else {
        _errorMessage = result.message;
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _customRange,
    );
    if (picked == null) return;
    setState(() {
      _filter = _ReportFilter.custom;
      _customRange = picked;
    });
    _load();
  }

  void _selectFilter(_ReportFilter filter) {
    if (filter == _ReportFilter.custom) {
      _pickCustomRange();
      return;
    }
    setState(() => _filter = filter);
    _load();
  }

  // ✅ نفس المجموع يلي معروض بالشاشة بالضبط - الملغى ما بيدخل بـ"إجمالي الإنفاق"
  double get _totalSpent => _orders
      .where((o) => o.status != 'Cancelled')
      .fold(0.0, (sum, o) => sum + o.finalAmount);

  DateTime? get _lastOrderDate => _orders.isNotEmpty ? _orders.first.orderTime : null;

  Future<void> _exportPdf(Locale locale) async {
    setState(() => _isExporting = true);
    try {
      final user = ref.read(authProvider).user;
      await printCustomerOrderReport(
        customerName: user?.fullName ?? '',
        totalOrders: _orders.length,
        totalSpent: _totalSpent,
        lastOrderDate: _lastOrderDate,
        orders: _orders,
        generatedAt: DateTime.now(),
        isRtl: locale.languageCode == 'ar',
        labels: {
          'title': AppLocalizations.t(locale, 'order_report_title'),
          'generated': AppLocalizations.t(locale, 'order_report_pdf_generated'),
          'summarySection': AppLocalizations.t(locale, 'order_report_pdf_summary_section'),
          'ordersSection': AppLocalizations.t(locale, 'order_report_pdf_orders_section'),
          'customerName': AppLocalizations.t(locale, 'order_report_customer_name'),
          'totalOrders': AppLocalizations.t(locale, 'order_report_total_orders'),
          'totalSpent': AppLocalizations.t(locale, 'order_report_total_spent'),
          'lastOrder': AppLocalizations.t(locale, 'order_report_last_order'),
          'noOrders': AppLocalizations.t(locale, 'order_report_no_orders'),
          'colOrder': AppLocalizations.t(locale, 'order_report_col_order'),
          'colDate': AppLocalizations.t(locale, 'order_report_col_date'),
          'colStore': AppLocalizations.t(locale, 'order_report_col_store'),
          'colItems': AppLocalizations.t(locale, 'order_report_col_items'),
          'colSubtotal': AppLocalizations.t(locale, 'order_report_col_subtotal'),
          'colDeliveryFee': AppLocalizations.t(locale, 'order_report_col_delivery_fee'),
          'colTotal': AppLocalizations.t(locale, 'order_report_col_total'),
          'colPayment': AppLocalizations.t(locale, 'order_report_col_payment'),
          'colStatus': AppLocalizations.t(locale, 'order_report_col_status'),
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t(locale, 'order_report_export_failed'))),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return AppColors.warning;
      case 'Confirmed':
      case 'Preparing':
        return AppColors.secondaryBrand;
      case 'Ready':
      case 'PickedUp':
        return AppColors.accent;
      case 'Delivered':
        return brandColor;
      case 'Cancelled':
      case 'Refunded':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return MainLayout(
      builder: (context, isWeb, padding, width) {
        return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.t(locale, 'order_report_title'),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      OutlinedButton.icon(
                        onPressed: (_isExporting || _orders.isEmpty)
                            ? null
                            : () => _exportPdf(locale),
                        icon: _isExporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: Text(AppLocalizations.t(locale, 'order_report_export_pdf')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildFilterChips(locale),
                  const SizedBox(height: 16),
                  _buildSummaryCard(locale),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text(_errorMessage!)),
                    )
                  else if (_orders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          AppLocalizations.t(locale, 'order_report_no_orders'),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  else
                    ..._orders.map((order) => _buildOrderRow(context, locale, order)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChips(Locale locale) {
    Widget chip(_ReportFilter value, String labelKey) {
      final selected = _filter == value;
      return ChoiceChip(
        label: Text(AppLocalizations.t(locale, labelKey)),
        selected: selected,
        onSelected: (_) => _selectFilter(value),
        selectedColor: brandColor.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          color: selected ? brandColor : null,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(_ReportFilter.all, 'order_report_filter_all'),
        chip(_ReportFilter.week, 'order_report_filter_week'),
        chip(_ReportFilter.month, 'order_report_filter_month'),
        chip(_ReportFilter.custom, 'order_report_filter_custom'),
      ],
    );
  }

  Widget _buildSummaryCard(Locale locale) {
    final user = ref.watch(authProvider).user;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow(
            AppLocalizations.t(locale, 'order_report_customer_name'),
            user?.fullName ?? '',
          ),
          _summaryRow(
            AppLocalizations.t(locale, 'order_report_total_orders'),
            '${_orders.length}',
          ),
          _summaryRow(
            AppLocalizations.t(locale, 'order_report_total_spent'),
            '₪${_totalSpent.toStringAsFixed(2)}',
          ),
          _summaryRow(
            AppLocalizations.t(locale, 'order_report_last_order'),
            _lastOrderDate != null
                ? DateFormat('d MMM y, h:mm a', 'en_US').format(_lastOrderDate!.toLocal())
                : '-',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildOrderRow(BuildContext context, Locale locale, OrderModel order) {
    final color = _statusColor(order.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => showDialog(
          context: context,
          builder: (_) => OrderDetailsDialog(order: order),
        ),
        child: AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.storeName ?? order.orderNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.orderTime != null
                          ? DateFormat('d MMM y, h:mm a', 'en_US').format(order.orderTime!.toLocal())
                          : '-',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₪${order.finalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
