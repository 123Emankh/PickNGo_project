// lib/screens/driver/driver_performance_screen.dart
//
// تحليلات أداء السائق (Driver Performance Analytics) - قائمة/إحصاء (لا
// Machine Learning): متوسط وقت التوصيل، نسب قبول/رفض عروض التعيين الذكي،
// عدد الطلبات المكتملة، معدّل الالتزام. كل الأرقام من backend/src/services/
// analytics/driverAnalyticsService.js (GET /api/drivers/performance).
import 'package:flutter/material.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/analytics_model.dart';
import '../../services/driver_service.dart';
import '../../widgets/detail_app_bar.dart';
import '../../widgets/insight_card.dart';

class DriverPerformanceScreen extends StatefulWidget {
  const DriverPerformanceScreen({super.key});

  @override
  State<DriverPerformanceScreen> createState() => _DriverPerformanceScreenState();
}

class _DriverPerformanceScreenState extends State<DriverPerformanceScreen> {
  final _driverService = DriverService();
  bool _isLoading = true;
  DriverPerformanceModel? _performance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final performance = await _driverService.getMyPerformance();
    if (!mounted) return;
    setState(() {
      _performance = performance;
      _isLoading = false;
    });
  }

  String _percent(double? rate) => rate != null ? '${(rate * 100).toStringAsFixed(0)}%' : '—';

  Color get _mutedText => Theme.of(context).brightness == Brightness.dark
      ? Colors.grey[400]!
      : Colors.grey[600]!;

  @override
  Widget build(BuildContext context) {
    final perf = _performance;
    return Scaffold(
      appBar: const DetailAppBar(title: 'أدائي'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : perf == null
              ? Center(
                  child: Text('تعذّر تحميل بيانات الأداء', style: TextStyle(color: _mutedText)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final padding = constraints.maxWidth > 900 ? constraints.maxWidth * 0.06 : 20.0;
                      final isWide = constraints.maxWidth > 700;
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: isWide ? 4 : 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              // ✅ نفس إصلاح تحليلات المتجر - ارتفاع مناسب
                              // للمحتوى الغني بدل كروت طويلة فاضية.
                              childAspectRatio: isWide ? 1.55 : 1.05,
                              children: [
                                InsightCard(
                                  icon: Icons.check_circle_outline,
                                  iconColor: AppColors.brand,
                                  value: '${perf.completedOrders}',
                                  label: 'طلبات مكتملة',
                                  sub: 'توصيلة أُنجزت بنجاح',
                                ),
                                InsightCard(
                                  icon: Icons.timer_outlined,
                                  iconColor: AppColors.accent,
                                  value: perf.avgDeliveryTimeMin != null ? '${perf.avgDeliveryTimeMin} د' : '—',
                                  label: 'متوسط وقت التوصيل',
                                  sub: perf.avgDeliveryTimeSampleSize > 0
                                      ? 'من ${perf.avgDeliveryTimeSampleSize} طلب مسلّم'
                                      : 'لا يوجد سجل كافٍ بعد',
                                ),
                                InsightCard(
                                  icon: Icons.thumb_up_alt_outlined,
                                  iconColor: const Color(0xFF3B82F6),
                                  value: _percent(perf.smartAssignment.acceptanceRate),
                                  label: 'نسبة قبول العروض الذكية',
                                  sub: '${perf.smartAssignment.accepted} من ${perf.smartAssignment.totalOffers} عرض',
                                  ratio: perf.smartAssignment.acceptanceRate,
                                  ratioColor: const Color(0xFF3B82F6),
                                ),
                                InsightCard(
                                  icon: Icons.verified_outlined,
                                  iconColor: const Color(0xFFA855F7),
                                  value: _percent(perf.commitmentRate),
                                  label: 'معدّل الالتزام',
                                  sub: 'من الطلبات المقبولة',
                                  ratio: perf.commitmentRate,
                                  ratioColor: const Color(0xFFA855F7),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            const AnalyticsSectionHeader(
                              icon: Icons.bolt_outlined,
                              iconColor: Color(0xFF3B82F6),
                              title: 'تفاصيل عروض التعيين الذكي',
                            ),
                            const SizedBox(height: 14),
                            _buildOfferBreakdown(perf.smartAssignment),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildOfferBreakdown(SmartAssignmentStats stats) {
    if (stats.totalOffers == 0) {
      return const AnalyticsEmptyBlock(
        icon: Icons.mail_outline,
        text: 'ما وصلك عروض تعيين ذكي بعد',
      );
    }

    final segments = [
      (label: 'مقبولة', count: stats.accepted, color: AppColors.brand),
      (label: 'مرفوضة', count: stats.rejected, color: AppColors.error),
      (label: 'منتهية الصلاحية بدون رد', count: stats.expired, color: AppColors.warning),
      if (stats.pending > 0) (label: 'بانتظار الرد حاليًا', count: stats.pending, color: Colors.grey),
    ];

    Widget row(({String label, int count, Color color}) s) {
      final pct = stats.totalOffers > 0 ? (s.count / stats.totalOffers * 100).round() : 0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(s.label, style: const TextStyle(fontSize: 13))),
            Text('$pct%', style: TextStyle(color: _mutedText, fontSize: 12)),
            const SizedBox(width: 8),
            Text('${s.count}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      );
    }

    final visibleSegments = segments.where((s) => s.count > 0).toList();

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
          // ✅ شريط نسب مجزّأ حقيقي (من نفس بيانات stats) - عرض بصري سريع
          // لتوزيع العروض قبل تفاصيل كل صف بالأسفل.
          if (visibleSegments.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: visibleSegments
                      .map((s) => Expanded(flex: s.count, child: Container(color: s.color)))
                      .toList(),
                ),
              ),
            ),
          const SizedBox(height: 4),
          const Divider(height: 20),
          ...segments.map(row),
        ],
      ),
    );
  }
}
