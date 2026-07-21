// lib/screens/admin/widgets/admin_analytics_tab.dart
//
// Admin Analytics Dashboard: طلبات يومية، إيرادات، أنشط المتاجر، أفضل
// السائقين أداءً، نجاح التعيين الذكي، ونسبة الطلبات المجمّعة. كل الأرقام من
// backend/src/services/analytics/adminAnalyticsService.js (GET
// /api/admin/analytics) - إحصاء مباشر على البيانات الفعلية، بدون Machine Learning.
import 'package:flutter/material.dart';
import '../../../core/theme/app_themes.dart';
import '../../../data/models/analytics_model.dart';
import '../../../services/admin_service.dart';
import '../../../widgets/stat_tile.dart';

class AdminAnalyticsTab extends StatefulWidget {
  const AdminAnalyticsTab({super.key});

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  final _adminService = AdminService();
  bool _isLoading = true;
  AdminAnalyticsModel? _analytics;
  int _days = 14;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final analytics = await _adminService.getAnalyticsDashboard(days: _days);
    if (!mounted) return;
    setState(() {
      _analytics = analytics;
      _isLoading = false;
    });
  }

  String _percent(double? rate) => rate != null ? '${(rate * 100).toStringAsFixed(0)}%' : '—';

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final analytics = _analytics;
    if (analytics == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(child: Text('تعذّر تحميل التحليلات', style: TextStyle(color: Colors.grey[600]))),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodSelector(),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: constraints.maxWidth > 700 ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: [
                    StatTile(
                      icon: Icons.shopping_bag_outlined,
                      value: '${analytics.totalOrders}',
                      label: 'طلبات (آخر $_days يوم)',
                    ),
                    StatTile(
                      icon: Icons.attach_money,
                      iconColor: AppColors.accent,
                      value: '₪${analytics.totalRevenue.toStringAsFixed(0)}',
                      label: 'الإيرادات',
                    ),
                    StatTile(
                      icon: Icons.smart_toy_outlined,
                      value: _percent(analytics.smartAssignment.successRate),
                      label: 'نجاح التعيين الذكي',
                    ),
                    StatTile(
                      icon: Icons.call_split,
                      iconColor: AppColors.accent,
                      value: _percent(analytics.groupedOrderRate),
                      label: 'نسبة الطلبات المجمّعة',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('الطلبات اليومية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (analytics.daily.isEmpty)
                  _emptyBox('لا توجد طلبات بهذه الفترة')
                else
                  _buildDailyOrdersChart(analytics.daily),
                const SizedBox(height: 24),
                const Text('الإيرادات اليومية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (analytics.daily.isEmpty)
                  _emptyBox('لا توجد إيرادات بهذه الفترة')
                else
                  _buildDailyRevenueChart(analytics.daily),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTopStores(analytics.topStores)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTopDrivers(analytics.topDrivers)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('نجاح التعيين الذكي - التفصيل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildSmartAssignmentBreakdown(analytics.smartAssignment),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Wrap(
      spacing: 8,
      children: [7, 14, 30, 90].map((d) {
        final isSelected = _days == d;
        return ChoiceChip(
          label: Text('$d يوم'),
          selected: isSelected,
          onSelected: (_) {
            setState(() => _days = d);
            _load();
          },
          selectedColor: AppColors.brand.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.brand : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[400]
              : Colors.grey[600],
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildDailyOrdersChart(List<DailyOrderStat> daily) {
    final maxOrders = daily.map((d) => d.orders).reduce((a, b) => a > b ? a : b);
    return _buildBarRow(
      daily,
      valueOf: (d) => d.orders.toDouble(),
      max: maxOrders.toDouble(),
      labelOf: (d) => '${d.orders}',
      color: AppColors.brand,
    );
  }

  Widget _buildDailyRevenueChart(List<DailyOrderStat> daily) {
    final maxRevenue = daily.map((d) => d.revenue).fold<double>(0, (a, b) => b > a ? b : a);
    return _buildBarRow(
      daily,
      valueOf: (d) => d.revenue,
      max: maxRevenue,
      labelOf: (d) => d.revenue > 0 ? '₪${d.revenue.toStringAsFixed(0)}' : '0',
      color: AppColors.accent,
    );
  }

  Widget _buildBarRow(
    List<DailyOrderStat> daily, {
    required double Function(DailyOrderStat) valueOf,
    required double max,
    required String Function(DailyOrderStat) labelOf,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: daily.map((d) {
            final ratio = max > 0 ? valueOf(d) / max : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(labelOf(d), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    width: 26,
                    height: 6 + ratio * 90,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    d.date.substring(5),
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopStores(List<TopStoreStat> stores) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('أنشط المتاجر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          if (stores.isEmpty)
            Text('لا توجد بيانات كافية', style: TextStyle(color: Colors.grey[600], fontSize: 12))
          else
            ...stores.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(s.name, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${s.orderCount} طلب', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildTopDrivers(List<TopDriverStat> drivers) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('أفضل السائقين أداءً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          if (drivers.isEmpty)
            Text('لا توجد بيانات كافية', style: TextStyle(color: Colors.grey[600], fontSize: 12))
          else
            ...drivers.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(d.name, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${d.performance.completedOrders} توصيلة', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildSmartAssignmentBreakdown(SmartAssignmentSummary stats) {
    Widget row(String label, int count, Color color) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          row('تعيين تلقائي (Auto)', stats.autoAssigned, Colors.green),
          row('تعيين يدوي (Manual)', stats.manualAssigned, Colors.blueGrey),
          row('بدون سائق حتى الآن', stats.unassigned, Colors.orange),
          const Divider(height: 20),
          row('إجمالي الطلبات التي احتاجت تعيينًا', stats.neededAssignment, Colors.grey),
        ],
      ),
    );
  }
}
