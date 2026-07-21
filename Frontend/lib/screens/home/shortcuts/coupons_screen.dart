// lib/screens/home/shortcuts/coupons_screen.dart
//
// "كوبونات خصم" - اختصار الصفحة الرئيسية: قائمة كل الكوبونات الفعّالة حاليًا
// (GET /api/coupons/active) - كل كوبون كبطاقة "تذكرة" فيها الكود/نسبة الخصم/
// الحد الأدنى/تاريخ الانتهاء/اسم المتجر. الضغط على البطاقة بينسخ الكود.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/coupon_service.dart';
import '../../../widgets/main_layout.dart';
import '../../../widgets/app_card.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_themes.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  static const Color brandColor = AppColors.brand;
  final _couponService = CouponService();
  bool _isLoading = true;
  List<CouponModel> _coupons = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _couponService.getActiveCoupons();
    if (!mounted) return;
    setState(() {
      _coupons = result.coupons;
      _isLoading = false;
    });
  }

  String _discountLabel(CouponModel c) {
    return c.discountType == 'Percentage'
        ? '-${c.discountValue.toStringAsFixed(0)}%'
        : '-₪${c.discountValue.toStringAsFixed(2)}';
  }

  void _copyCode(Locale locale, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.t(locale, 'coupons_code_copied').replaceFirst('{code}', code),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.t(locale, 'coupons_title'),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_coupons.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          AppLocalizations.t(locale, 'coupons_empty'),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  else
                    ..._coupons.map((c) => _buildCouponCard(locale, c)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCouponCard(Locale locale, CouponModel c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => _copyCode(locale, c.code),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                _discountLabel(c),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: brandColor),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        c.code,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.copy, size: 14, color: Colors.grey[500]),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    c.storeName ?? AppLocalizations.t(locale, 'coupons_all_stores'),
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                  ),
                  if (c.minOrderAmount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.t(locale, 'coupons_min_order')
                          .replaceFirst('{amount}', c.minOrderAmount.toStringAsFixed(0)),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                  if (c.validUntil != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.t(locale, 'coupons_valid_until').replaceFirst(
                        '{date}',
                        '${c.validUntil!.year}-${c.validUntil!.month.toString().padLeft(2, '0')}-${c.validUntil!.day.toString().padLeft(2, '0')}',
                      ),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
