// lib/screens/driver/smart_offer_dialog.dart
//
// Phase 3 - Smart Assignment: نافذة عرض تعيين ذكي جديد على السائق - بتوصل
// من driver_home_screen (بث لحظي عبر order:offer، أو fallback GET
// /api/orders/offers/mine). فيها عداد تنازلي حقيقي مبني على expires_at
// الفعلي القادم من السيرفر (مش تقدير محلي)، وزري قبول/رفض.
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/offer_model.dart';

// ✅ نفس OFFER_TIMEOUT_MS بالباك إند (assignmentService.js/groupAssignmentService.js) -
// تُستخدم بس لنسبة شريط التقدّم البصري؛ الانتهاء الفعلي محكوم بـ expires_at
const _kOfferTotalSeconds = 120;

class SmartOfferDialog extends StatefulWidget {
  final DeliveryOfferModel offer;
  final Future<bool> Function() onAccept;
  final Future<bool> Function() onReject;

  const SmartOfferDialog({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<SmartOfferDialog> createState() => _SmartOfferDialogState();
}

class _SmartOfferDialogState extends State<SmartOfferDialog> {
  static const Color brandColor = AppColors.brand;

  Timer? _ticker;
  Duration _remaining = Duration.zero;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final remaining = widget.offer.expiresAt.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
    if (_remaining == Duration.zero) {
      _ticker?.cancel();
      if (!_isResponding) Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _handle(Future<bool> Function() action) async {
    if (_isResponding) return;
    setState(() => _isResponding = true);
    final success = await action();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _isResponding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final seconds = _remaining.inSeconds;
    final urgent = seconds <= 15;
    final ratio = (seconds / _kOfferTotalSeconds).clamp(0.0, 1.0);
    final timerColor = urgent ? AppColors.error : brandColor;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: brandColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.bolt, color: brandColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'عرض توصيل جديد',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: timerColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '00:${seconds.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: timerColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: Theme.of(context).dividerColor,
                    valueColor: AlwaysStoppedAnimation(timerColor),
                  ),
                ),
                const SizedBox(height: 18),

                if (offer.isGroup) ...[
                  Row(
                    children: [
                      Icon(Icons.route_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'مجموعة توصيل - ${offer.orderCount} طلبات',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...offer.stores.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: brandColor.withValues(alpha: 0.12),
                              child: Text(
                                '${s.pickupSequence}',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: brandColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.name ?? 'متجر',
                                style: const TextStyle(fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                ] else ...[
                  Row(
                    children: [
                      Icon(Icons.storefront_outlined, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          offer.storeName ?? 'متجر',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (offer.storeAddress != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 26),
                      child: Text(
                        offer.storeAddress!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (offer.distanceKm != null)
                      _pill(Icons.social_distance_outlined, '${offer.distanceKm!.toStringAsFixed(1)} كم'),
                    _pill(Icons.payments_outlined, '+₪${offer.deliveryFee.toStringAsFixed(2)}'),
                  ],
                ),

                if (offer.reasonLabel != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 15, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            offer.reasonLabel!,
                            style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isResponding ? null : () => _handle(widget.onReject),
                        child: const Text('رفض', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isResponding ? null : () => _handle(widget.onAccept),
                        child: _isResponding
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('قبول', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[700]),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        ],
      ),
    );
  }
}
