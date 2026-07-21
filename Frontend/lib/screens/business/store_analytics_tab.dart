// lib/screens/business/store_analytics_tab.dart
//
// Store Analytics: أكثر المنتجات مبيعًا، ساعات الذروة، متوسط قيمة الطلب،
// نسبة الإلغاء، عدد العملاء المتكررين. كل الأرقام من backend/src/services/
// analytics/storeAnalyticsService.js (GET /api/stores/my-store/analytics) -
// قائمة/إحصاء بسيط، بدون Machine Learning.
import 'package:flutter/material.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/analytics_model.dart';
import '../../services/store_service.dart';
import '../../widgets/insight_card.dart';

class StoreAnalyticsTabContent extends StatefulWidget {
  const StoreAnalyticsTabContent({super.key});

  @override
  State<StoreAnalyticsTabContent> createState() => _StoreAnalyticsTabContentState();
}

class _StoreAnalyticsTabContentState extends State<StoreAnalyticsTabContent> {
  final _storeService = StoreService();
  bool _isLoading = true;
  StoreAnalyticsModel? _analytics;

  static const _blue = Color(0xFF3B82F6);
  static const _purple = Color(0xFFA855F7);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final analytics = await _storeService.getMyStoreAnalytics();
    if (!mounted) return;
    setState(() {
      _analytics = analytics;
      _isLoading = false;
    });
  }

  String _percent(double? rate) => rate != null ? '${(rate * 100).toStringAsFixed(0)}%' : '—';

  Color get _mutedText => Theme.of(context).brightness == Brightness.dark
      ? Colors.grey[400]!
      : Colors.grey[600]!;

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
        child: Center(child: Text('تعذّر تحميل التحليلات', style: TextStyle(color: _mutedText))),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isWide ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  // ✅ ارتفاع مناسب للمحتوى الغني الجديد (بدل 1.15 يلي كان
                  // بيخلي الكروت طويلة جداً وفاضية بعرض الديسكتوب).
                  childAspectRatio: isWide ? 1.55 : 1.05,
                  children: [
                    InsightCard(
                      icon: Icons.receipt_long_outlined,
                      iconColor: AppColors.brand,
                      value: '₪${(analytics.avgOrderValue ?? 0).toStringAsFixed(2)}',
                      label: 'متوسط قيمة الطلب',
                      sub: 'بناءً على ${analytics.totalOrders} طلب',
                    ),
                    InsightCard(
                      icon: Icons.cancel_outlined,
                      iconColor: AppColors.error,
                      value: _percent(analytics.cancellationRate),
                      label: 'نسبة الإلغاء',
                      sub: '${analytics.cancelledOrders} من ${analytics.totalOrders} طلب',
                      ratio: analytics.cancellationRate,
                      ratioColor: AppColors.error,
                    ),
                    InsightCard(
                      icon: Icons.repeat,
                      iconColor: _purple,
                      value: '${analytics.repeatCustomers}',
                      label: 'عملاء متكررون',
                      sub: analytics.repeatCustomerRate != null
                          ? '${_percent(analytics.repeatCustomerRate)} من عملائك'
                          : 'من إجمالي العملاء',
                      ratio: analytics.repeatCustomerRate,
                      ratioColor: _purple,
                    ),
                    InsightCard(
                      icon: Icons.groups_outlined,
                      iconColor: _blue,
                      value: '${analytics.uniqueCustomers}',
                      label: 'إجمالي العملاء',
                      sub: analytics.repeatCustomers > 0
                          ? 'منهم ${analytics.repeatCustomers} متكرر'
                          : 'زبون فريد',
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const AnalyticsSectionHeader(
                  icon: Icons.local_fire_department_outlined,
                  iconColor: AppColors.accent,
                  title: 'أكثر المنتجات مبيعًا',
                ),
                const SizedBox(height: 14),
                if (analytics.topProducts.isEmpty)
                  const AnalyticsEmptyBlock(
                    icon: Icons.inventory_2_outlined,
                    text: 'لا توجد بيانات مبيعات كافية بعد',
                  )
                else
                  ..._buildTopProducts(analytics.topProducts),
                const SizedBox(height: 28),
                const AnalyticsSectionHeader(
                  icon: Icons.schedule_outlined,
                  iconColor: _blue,
                  title: 'ساعات الذروة',
                ),
                const SizedBox(height: 14),
                if (analytics.peakHours.isEmpty)
                  const AnalyticsEmptyBlock(
                    icon: Icons.bar_chart_outlined,
                    text: 'لا توجد طلبات كافية بعد',
                  )
                else
                  _buildPeakHoursChart(analytics.peakHours),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildTopProducts(List<TopProductStat> products) {
    final maxQty = products.map((p) => p.totalQuantity).reduce((a, b) => a > b ? a : b);
    const rankColors = [Color(0xFFF59E0B), Color(0xFF94A3B8), Color(0xFFB45309)];
    return products.asMap().entries.map((entry) {
      final i = entry.key;
      final p = entry.value;
      final ratio = maxQty > 0 ? p.totalQuantity / maxQty : 0.0;
      final rankColor = i < rankColors.length ? rankColors[i] : Theme.of(context).dividerColor;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(top: 1),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: rankColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('${p.totalQuantity} قطعة', style: TextStyle(color: _mutedText, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: Theme.of(context).dividerColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('إيراد: ₪${p.totalRevenue.toStringAsFixed(2)}', style: TextStyle(color: _mutedText, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPeakHoursChart(List<PeakHourStat> peakHours) {
    final maxCount = peakHours.map((h) => h.count).reduce((a, b) => a > b ? a : b);
    final busiestHour = peakHours.firstWhere((h) => h.count == maxCount);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 15, color: AppColors.brand),
              const SizedBox(width: 6),
              Text(
                'أكثر إزدحامًا الساعة ${busiestHour.hour.toString().padLeft(2, '0')}:00 (${busiestHour.count} طلب)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: peakHours.map((h) {
              final isBusiest = h.hour == busiestHour.hour;
              final heightRatio = maxCount > 0 ? h.count / maxCount : 0.0;
              final barColor = isBusiest ? AppColors.brand : AppColors.brand.withValues(alpha: 0.35);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${h.count}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isBusiest ? AppColors.brand : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28,
                    height: 8 + heightRatio * 80,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${h.hour.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isBusiest ? FontWeight.bold : FontWeight.normal,
                      color: isBusiest ? AppColors.brand : _mutedText,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
