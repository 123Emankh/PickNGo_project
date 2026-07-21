// lib/screens/post_auth_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/store_provider.dart';
import 'home/home_screen.dart';
import 'business/store_setup_screen.dart';
import 'business/pending_approval_screen.dart';
import 'business/business_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'driver/driver_home_screen.dart';
import 'driver/company_dashboard_screen.dart';
import 'driver/company_pending_approval_screen.dart';

/// نقطة القرار الوحيدة لوين نوجه المستخدم بعد تسجيل الدخول أو التحقق من OTP.
/// - Admin -> AdminDashboardScreen
/// - Driver -> DriverHomeScreen
/// - Customer -> HomeScreen (بدون تغيير بالسلوك الحالي)
/// - Restaurant (Business Owner):
///     ما عندو متجر بعد      -> StoreSetupScreen
///     متجره Pending         -> PendingApprovalScreen
///     متجره Rejected        -> PendingApprovalScreen (وفيها زر تعديل وإعادة تقديم)
///     متجره Approved        -> BusinessDashboardScreen
class PostAuthRouter extends ConsumerStatefulWidget {
  const PostAuthRouter({super.key});

  @override
  ConsumerState<PostAuthRouter> createState() => _PostAuthRouterState();
}

class _PostAuthRouterState extends ConsumerState<PostAuthRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user?.role == 'Restaurant') {
        ref.read(storeProvider.notifier).fetchMyStore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    if (user?.role == 'Admin') {
      return const AdminDashboardScreen();
    }

    if (user?.role == 'Driver') {
      if (user!.businessType == 'Fleet / Company') {
        return user.status == 'Approved'
            ? const CompanyDashboardScreen()
            : const CompanyPendingApprovalScreen(); // بيغطي Pending و Rejected
      }
      return const DriverHomeScreen();
    }

    if (user?.role != 'Restaurant') {
      // Customer / أي دور تاني: نفس السلوك الحالي بدون تغيير
      return const HomeScreen();
    }

    final storeState = ref.watch(storeProvider);

    if (!storeState.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final store = storeState.store;
    if (store == null) {
      return const StoreSetupScreen();
    }

    switch (store.approvalStatus) {
      case 'Approved':
        return const BusinessDashboardScreen();
      case 'Rejected':
      case 'Pending':
      default:
        return const PendingApprovalScreen();
    }
  }
}
