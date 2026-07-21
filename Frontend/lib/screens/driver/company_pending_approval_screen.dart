// lib/screens/driver/company_pending_approval_screen.dart
//
// شاشة تُعرض لصاحب حساب شركة التوصيل بعد التسجيل، وتوريه حالة الموافقة:
// - Pending: قيد المراجعة من الأدمن
// - Rejected: مرفوض
// مبنية على user.status مباشرة (الشركة نفسها User row، مفيش جدول منفصل إلها).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../landing/landing_screen.dart';

class CompanyPendingApprovalScreen extends ConsumerStatefulWidget {
  const CompanyPendingApprovalScreen({super.key});

  @override
  ConsumerState<CompanyPendingApprovalScreen> createState() => _CompanyPendingApprovalScreenState();
}

class _CompanyPendingApprovalScreenState extends ConsumerState<CompanyPendingApprovalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await ref.read(authProvider.notifier).getProfile();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isRejected = user?.status == 'Rejected';

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
                    isRejected ? 'تم رفض حساب الشركة' : 'حسابك قيد المراجعة',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRejected
                        ? 'للأسف تم رفض طلب انضمام شركتك. تواصل مع الدعم لمزيد من التفاصيل.'
                        : 'فريقنا بيراجع بيانات شركتك حاليًا. رح تقدر تدخل على لوحة التحكم فور الموافقة.',
                    style: TextStyle(color: Colors.grey[600], height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: authState.isLoading ? null : _refresh,
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('تحديث الحالة', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    child: Text('تسجيل الخروج', style: TextStyle(color: Colors.grey[600])),
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
