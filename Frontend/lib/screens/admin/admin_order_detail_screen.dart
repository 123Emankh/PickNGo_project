// lib/screens/admin/admin_order_detail_screen.dart
//
// تفاصيل طلب كاملة للأدمن: العميل/المتجر/السائق/شركة التوصيل/حالة الطلب/
// وقت الإنشاء والتحديث/معلومات Smart Assignment (Phase 3)/رحلة التوصيل
// المجمّعة إن وجدت (Grouped Delivery). GET /api/admin/orders/:id.
import 'package:flutter/material.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../widgets/detail_app_bar.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final String orderId;

  const AdminOrderDetailScreen({super.key, required this.orderId});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState(); 
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  static const Color brandColor = AppColors.brand;
  final _adminService = AdminService();
  AdminOrderDetailModel? _order;
  bool _isLoading = true;
  bool _notFound = false;

  static const Map<String, Color> _statusColors = {
    'Pending': Color(0xFFF97316),
    'Confirmed': Color(0xFF3B82F6),
    'Preparing': Color(0xFF3B82F6),
    'Ready': Color(0xFFA855F7),
    'PickedUp': Color(0xFFA855F7),
    'Delivered': AppColors.brand,
    'Cancelled': Color(0xFFDC2626),
    'Refunded': Color(0xFFDC2626),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final order = await _adminService.getOrderDetail(widget.orderId);
    if (!mounted) return;
    setState(() {
      _order = order;
      _notFound = order == null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailAppBar(title: 'طلب #${widget.orderId}'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notFound
              ? const Center(child: Text('تعذر إيجاد هذا الطلب'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: _buildContent(_order!),
                  ),
                ),
    );
  }

  Widget _buildContent(AdminOrderDetailModel o) {
    final statusColor = _statusColors[o.status] ?? Colors.grey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(o.orderNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(o.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('₪${o.finalAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, color: Colors.grey[700], fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        _sectionCard('التوقيت', [
          if (o.orderTime != null) _row('وقت الإنشاء', _fmt(o.orderTime!)),
          if (o.updatedAt != null) _row('آخر تحديث', _fmt(o.updatedAt!)),
          if (o.completedTime != null) _row('وقت الإكمال', _fmt(o.completedTime!)),
        ]),

        if (o.isGrouped) ...[
          const SizedBox(height: 14),
          _sectionCard('رحلة توصيل مجمّعة #${o.deliveryGroupId}', [
            _row('حالة الرحلة', o.deliveryGroupStatus ?? '-'),
            const SizedBox(height: 8),
            ...o.deliveryGroupStores.map((s) {
              final isCurrent = s.orderId == o.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: brandColor.withValues(alpha: 0.12),
                      child: Text('${s.pickupSequence}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: brandColor)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.storeName ?? 'متجر'}${isCurrent ? ' (هذا الطلب)' : ''}',
                        style: TextStyle(fontSize: 13, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                      ),
                    ),
                    Text(s.orderStatus, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                  ],
                ),
              );
            }),
          ]),
        ],

        const SizedBox(height: 14),
        _sectionCard('العميل', [
          _row('الاسم', o.customer?.name ?? '-'),
          if (o.customer?.phone != null) _row('الهاتف', o.customer!.phone!),
          if (o.customer?.email != null) _row('البريد', o.customer!.email!),
          _row('عنوان التوصيل', o.deliveryAddress),
          if (o.specialInstructions != null && o.specialInstructions!.isNotEmpty)
            _row('ملاحظات الطلب', o.specialInstructions!),
        ]),

        const SizedBox(height: 14),
        _sectionCard('المتجر', [
          _row('الاسم', o.store?.name ?? '-'),
          if (o.store?.address != null) _row('العنوان', o.store!.address!),
          if (o.store?.phone != null) _row('الهاتف', o.store!.phone!),
        ]),

        const SizedBox(height: 14),
        _sectionCard(
          'السائق',
          o.driver == null
              ? [_row('الحالة', 'لم يُعيّن سائق بعد')]
              : [
                  _row('الاسم', o.driver!.name ?? '-'),
                  if (o.driver?.phone != null) _row('الهاتف', o.driver!.phone!),
                  if (o.driver?.vehicleType != null) _row('نوع المركبة', o.driver!.vehicleType!),
                  _row('شركة التوصيل', o.driver?.companyName ?? 'سائق مستقل'),
                  // ✅ سائق احتياطي (#5) - ثاني أفضل مرشح حاليًا، حساب حي
                  // (مش مخزّن) عبر computeBackupDriver بالباك اند
                  if (o.backupDriver != null) _row('سائق احتياطي', o.backupDriver!.name),
                ],
        ),

        if (o.isGrouped && o.deliveryGroupTimeline.isNotEmpty) ...[
          const SizedBox(height: 14),
          _sectionCard(
            'السجل الزمني الكامل للرحلة',
            o.deliveryGroupTimeline
                .map((e) => _row(
                      e.type == 'pickup' && e.storeName != null ? 'استلام من ${e.storeName}' : e.label,
                      e.at != null ? _fmt(e.at!) : '-',
                    ))
                .toList(),
          ),
        ],

        const SizedBox(height: 14),
        _sectionCard('الدفع', [
          _row('طريقة الدفع', o.paymentMethod),
          _row('حالة الدفع', o.paymentStatus),
          _row('المبلغ الإجمالي', '₪${o.totalAmount.toStringAsFixed(2)}'),
          _row('رسوم التوصيل', '₪${o.deliveryFee.toStringAsFixed(2)}'),
          if (o.discount > 0) _row('الخصم', '-₪${o.discount.toStringAsFixed(2)}'),
          _row('الصافي', '₪${o.finalAmount.toStringAsFixed(2)}'),
        ]),

        if (o.items.isNotEmpty) ...[
          const SizedBox(height: 14),
          _sectionCard(
            'عناصر الطلب',
            o.items
                .map((i) => _row(
                      '${i.quantity}× ${i.name}${i.variantLabel != null ? ' (${i.variantLabel})' : ''}',
                      '₪${i.subtotal.toStringAsFixed(2)}',
                    ))
                .toList(),
          ),
        ],

        const SizedBox(height: 14),
        _sectionCard('التعيين الذكي (Smart Assignment)', [
          _row('نوع التعيين', o.assignmentType ?? 'لم يُعيّن بعد'),
          if (o.assignedAt != null) _row('وقت التعيين', _fmt(o.assignedAt!)),
          if (o.assignmentReason != null) ..._buildReasonRows(o.assignmentReason!),
          _row('عدد محاولات العرض', '${o.offerHistory.length}'),
        ]),

        if (o.statusHistory.isNotEmpty) ...[
          const SizedBox(height: 14),
          _sectionCard(
            'سجل الحالات',
            o.statusHistory
                .map((e) => _row(e.status, e.at != null ? _fmt(e.at!) : '-'))
                .toList(),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  List<Widget> _buildReasonRows(Map<String, dynamic> reason) {
    final rows = <Widget>[];
    if (reason['score'] != null) {
      rows.add(_row('نقاط التسجيل', (reason['score'] as num).toStringAsFixed(2)));
    }
    if (reason['distance_km'] != null) {
      rows.add(_row('المسافة وقت الاختيار', '${(reason['distance_km'] as num).toStringAsFixed(1)} كم'));
    }
    if (reason['breakdown'] is List) {
      for (final b in (reason['breakdown'] as List)) {
        if (b is Map && b['factor'] != null) {
          rows.add(_row('  · ${b['factor']}', b['score'].toString()));
        }
      }
    }
    return rows;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey[600]))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
