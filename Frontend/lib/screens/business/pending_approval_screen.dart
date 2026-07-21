// lib/screens/business/pending_approval_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import '../../widgets/custom_button.dart';
import '../landing/landing_screen.dart';
import 'store_setup_screen.dart';
import 'business_dashboard_screen.dart';

/// شاشة تُعرض لصاحب المحل بعد ما يقدّم بياناته، وتوريه حالة الطلب:
/// - Pending: قيد المراجعة
/// - Rejected: مرفوض + السبب + زر تعديل وإعادة تقديم
/// لو صار Approved أثناء التحديث، بتوديه أوتوماتيك عالـ Dashboard.
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await ref.read(storeProvider.notifier).fetchMyStore();
  }

  @override
  Widget build(BuildContext context) {
    final storeState = ref.watch(storeProvider);
    final store = storeState.store;

    // ✅ لو صار الموافقة بالخلفية، وديه عالداشبورد مباشرة
    if (store != null && store.approvalStatus == 'Approved') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BusinessDashboardScreen()),
        );
      });
    }

    final isRejected = store?.approvalStatus == 'Rejected';
    final locale = Localizations.localeOf(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: (isRejected ? Colors.red : AppTheme.primaryColor).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRejected ? Icons.error_outline : Icons.hourglass_top_rounded,
                      size: 64,
                      color: isRejected ? Colors.red : AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isRejected
                        ? AppLocalizations.t(locale, 'pending_title_rejected')
                        : AppLocalizations.t(locale, 'pending_title_review'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRejected
                        ? AppLocalizations.t(locale, 'pending_desc_rejected')
                        : AppLocalizations.t(locale, 'pending_desc_review'),
                    style: TextStyle(color: Colors.grey[600], height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  if (isRejected && (store?.rejectionReason?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Text(
                        store!.rejectionReason!,
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (isRejected)
                    CustomButton(
                      text: AppLocalizations.t(locale, 'pending_edit_resubmit'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StoreSetupScreen(),
                          ),
                        );
                      },
                    )
                  else
                    CustomButton(
                      text: AppLocalizations.t(locale, 'pending_refresh_status'),
                      isLoading: storeState.isLoading,
                      onPressed: _refresh,
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LandingScreen()),
                        (route) => false,
                      );
                    },
                    child: Text(
                      AppLocalizations.t(locale, 'pending_logout'),
                      style: TextStyle(color: Colors.grey[600]),
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
