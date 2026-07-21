// lib/screens/checkout/order_success_screen.dart
//
// شاشة تأكيد بعد ما يتم إنشاء الطلب (أو الطلبات - إذا كانت السلة من أكتر
// من متجر) بنجاح.

import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_themes.dart';
import '../../widgets/main_layout.dart';
import '../landing/landing_screen.dart';
import '../orders/orders_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final List<String> orderNumbers;
  final bool hasPartialFailure;
  final List<String> failedPaymentOrderNumbers;
  final double totalSavings;

  const OrderSuccessScreen({
    super.key,
    required this.orderNumbers,
    this.hasPartialFailure = false,
    this.failedPaymentOrderNumbers = const [],
    this.totalSavings = 0,
  });

  static const Color brandColor = AppColors.brand;

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      builder: (context, isWeb, padding, width) => SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: brandColor,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.t(
                      Localizations.localeOf(context),
                      'ordersuccess_title',
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    orderNumbers.length > 1
                        ? AppLocalizations.t(
                            Localizations.localeOf(context),
                            'ordersuccess_orders_placed_plural',
                          ).replaceAll('{count}', '${orderNumbers.length}')
                        : AppLocalizations.t(
                            Localizations.localeOf(context),
                            'ordersuccess_orders_placed_singular',
                          ),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  if (totalSavings > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: brandColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'وفرت ₪${totalSavings.toStringAsFixed(2)} بالكوبون',
                        style: const TextStyle(
                          color: brandColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      children: orderNumbers
                          .map(
                            (number) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    number,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    AppLocalizations.t(
                                      Localizations.localeOf(context),
                                      'ordersuccess_status_pending',
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  if (failedPaymentOrderNumbers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...failedPaymentOrderNumbers.map(
                            (number) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    number,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'دفع لم يكتمل',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'تم إنشاء هذه الطلبات لكن عملية الدفع لم تكتمل - يمكنك إعادة محاولة الدفع لاحقًا من صفحة الطلبات.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (hasPartialFailure) ...[
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.t(
                        Localizations.localeOf(context),
                        'ordersuccess_partial_failure_note',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const OrdersScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      child: Text(
                        AppLocalizations.t(
                          Localizations.localeOf(context),
                          'ordersuccess_track_orders',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: brandColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: brandColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LandingScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      child: Text(
                        AppLocalizations.t(
                          Localizations.localeOf(context),
                          'ordersuccess_continue_shopping',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
