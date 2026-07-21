// lib/screens/loyalty/loyalty_screen.dart
//
// "نقاطي" - رصيد النقاط الحالي + سجل كل حركة (كسب/استبدال/سحب/إرجاع)،
// نفس نمط vendor_reviews_screen.dart (تحميل + حالة فارغة/خطأ + قائمة).
import 'package:flutter/material.dart';
import '../../services/loyalty_service.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/app_card.dart';
import '../../core/theme/app_themes.dart';
import '../../core/i18n/app_localizations.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  static const Color brandColor = AppColors.brand;
  final _loyaltyService = LoyaltyService();

  bool _isLoading = true;
  String? _error;
  int _balance = 0;
  List<LoyaltyTransactionModel> _transactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _loyaltyService.getMyLoyalty(limit: 50);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) {
        _balance = result.balance;
        _transactions = result.transactions;
      } else {
        _error = result.message;
      }
    });
  }

  String _typeLabel(Locale locale, String type) {
    switch (type) {
      case 'Earned':
        return AppLocalizations.t(locale, 'loyalty_type_earned');
      case 'Redeemed':
        return AppLocalizations.t(locale, 'loyalty_type_redeemed');
      case 'Reversed':
        return AppLocalizations.t(locale, 'loyalty_type_reversed');
      case 'Refunded':
        return AppLocalizations.t(locale, 'loyalty_type_refunded');
      default:
        return type;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Earned':
        return Icons.add_circle_outline;
      case 'Redeemed':
        return Icons.remove_circle_outline;
      case 'Reversed':
        return Icons.undo;
      case 'Refunded':
        return Icons.replay_circle_filled_outlined;
      default:
        return Icons.stars_outlined;
    }
  }

  Color _typeColor(String type) {
    return (type == 'Earned' || type == 'Refunded') ? brandColor : Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return MainLayout(
      builder: (context, isWeb, padding, width) {
        return RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Center(child: Text(_error!, style: TextStyle(color: Colors.grey[600]))),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.t(locale, 'loyalty_title'),
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 20),
                              _balanceCard(locale),
                              const SizedBox(height: 24),
                              Text(
                                AppLocalizations.t(locale, 'loyalty_history_title'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 12),
                              if (_transactions.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: Text(
                                      AppLocalizations.t(locale, 'loyalty_history_empty'),
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                )
                              else
                                ..._transactions.map((tx) => _buildTransactionCard(locale, tx)),
                            ],
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  Widget _balanceCard(Locale locale) {
    return AppCard(
      color: brandColor,
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.t(locale, 'loyalty_balance_label'),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$_balance', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    AppLocalizations.t(locale, 'loyalty_points_unit'),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.t(locale, 'loyalty_balance_hint'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Locale locale, LoyaltyTransactionModel tx) {
    final sign = tx.points > 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            Icon(_typeIcon(tx.type), color: _typeColor(tx.type), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_typeLabel(locale, tx.type), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  if (tx.description != null) ...[
                    const SizedBox(height: 2),
                    Text(tx.description!, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                  ],
                  if (tx.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${tx.createdAt!.year}-${tx.createdAt!.month.toString().padLeft(2, '0')}-${tx.createdAt!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '$sign${tx.points}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _typeColor(tx.type)),
            ),
          ],
        ),
      ),
    );
  }
}
