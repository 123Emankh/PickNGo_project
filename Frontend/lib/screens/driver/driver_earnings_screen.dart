// lib/screens/driver/driver_earnings_screen.dart
//
// أرباح السائق: مجموع، عدد الرحلات، وقائمة آخر التوصيلات. كل البيانات
// محسوبة محليًا من OrderService.getMyOrders() الموجودة أصلاً (نفس الاستدعاء
// المستخدم بلوحة السائق الرئيسية) - بدون أي endpoint جديد بالباك إند.
import 'package:flutter/material.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/order_model.dart';
import '../../services/order_service.dart';
import '../../widgets/detail_app_bar.dart';
import '../../widgets/stat_tile.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  final _orderService = OrderService();
  bool _isLoading = true;
  List<OrderModel> _delivered = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _orderService.getMyOrders();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) {
        _delivered = result.orders.where((o) => o.status == 'Delivered').toList()
          ..sort((a, b) => (b.orderTime ?? DateTime(0)).compareTo(a.orderTime ?? DateTime(0)));
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final totalEarnings = _delivered.fold<double>(0, (sum, o) => sum + o.deliveryFee);
    final totalTrips = _delivered.length;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weekEarnings = _delivered
        .where((o) => o.orderTime != null && o.orderTime!.isAfter(weekAgo))
        .fold<double>(0, (sum, o) => sum + o.deliveryFee);

    return Scaffold(
      appBar: const DetailAppBar(title: 'الأرباح والإحصائيات'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final padding = constraints.maxWidth > 900 ? constraints.maxWidth * 0.06 : 20.0;
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'إجمالي الأرباح',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '₪${totalEarnings.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: StatTile(
                                icon: Icons.delivery_dining_outlined,
                                value: '$totalTrips',
                                label: 'إجمالي الرحلات',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatTile(
                                icon: Icons.calendar_month_outlined,
                                iconColor: AppColors.accent,
                                value: '₪${weekEarnings.toStringAsFixed(2)}',
                                label: 'أرباح آخر 7 أيام',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'آخر التوصيلات',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (_delivered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'لا توجد توصيلات مكتملة بعد',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          )
                        else
                          ..._delivered.map(_buildTripRow),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildTripRow(OrderModel order) {
    final isToday = order.orderTime != null && _isSameDay(order.orderTime!, DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, color: AppColors.brand, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  isToday ? 'اليوم' : (order.orderTime?.toString().split(' ').first ?? ''),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '₪${order.deliveryFee.toStringAsFixed(2)}',
            style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
