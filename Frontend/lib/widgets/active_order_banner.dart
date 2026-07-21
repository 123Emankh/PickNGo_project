// lib/widgets/active_order_banner.dart
//
// ودجة عائمة (floating pill) بأسفل الشاشة الرئيسية لما يكون عند الزبون طلب
// لسا قيد التنفيذ (مش Delivered/Cancelled/Refunded) - بيوديه مباشرة لشاشة
// التتبع. مصممة كـ overlay فوق المحتوى (PositionedDirectional) مو عنصر
// عادي بجريان الصفحة.

import 'package:flutter/material.dart';
import '../core/theme/app_themes.dart';
import '../core/i18n/app_localizations.dart';
import '../data/models/order_model.dart';
import '../screens/orders/order_tracking_screen.dart';

const _terminalStatuses = {'Delivered', 'Cancelled', 'Refunded'};

class ActiveOrderBanner extends StatelessWidget {
  final List<OrderModel> orders;

  const ActiveOrderBanner({super.key, required this.orders});

  OrderModel? get _activeOrder {
    for (final order in orders) {
      if (!_terminalStatuses.contains(order.status)) return order;
    }
    return null;
  }

  String _statusLabel(Locale locale, String status) {
    // بنعيد استخدام مفاتيح حالة الطلب الموجودة أصلاً بلوحة تحكم المطعم
    // (bizdash_status_*) بدل ما نكرر نفس الترجمات من جديد.
    return AppLocalizations.t(locale, 'bizdash_status_${status.toLowerCase()}');
  }

  @override
  Widget build(BuildContext context) {
    final order = _activeOrder;
    if (order == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderTrackingScreen(orderId: order.id),
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.t(locale, 'activeorder_banner_title'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _statusLabel(locale, order.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
