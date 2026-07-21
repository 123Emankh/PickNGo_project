// lib/widgets/driver_header.dart
//
// هيدر لوحة السائق — نفس القالب البصري لـ AppHeader/AdminHeader/VendorHeader:
// نفس الارتفاع/الألوان/الظل الزجاجي/المسافات/الأيقونات، بمحتوى مناسب للوحة
// (اختصار الأرباح بدل السلة، بدون خانة بحث).
//
// ✅ مستخرج من _buildHeader() القديمة بـ driver_home_screen.dart - كانت
// بطاقة زجاجية مدوّرة داخل SingleChildScrollView (بتختفي بالتمرير)، صارت
// هون ودجة ثابتة (Pinned) خارج منطقة التمرير تمامًا متل باقي اللوحات.
// شريط حالة الاتصال (متاح/مشغول/غير متصل + Switch) بقي بمكانه بمحتوى
// الشاشة (أول عنصر تحت الهيدر) لأنه محتوى تفاعلي خاص بالشاشة مش chrome عام.
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_themes.dart';
import '../providers/auth_provider.dart';
import '../screens/driver/driver_earnings_screen.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/profile/profile_screen.dart';
import 'app_header.dart';
import 'notification_bell.dart';

class DriverHeader extends ConsumerWidget implements PreferredSizeWidget {
  final bool isWeb;
  final double padding;
  // ✅ تسجيل خروج السائق بده تنظيف خاص (إيقاف location ping) قبل logout()
  // العام - راجع _stopLocationPing() بـ driver_home_screen.dart. لازم نستخدم
  // نفس الكولباك المُمرَّر من الشاشة بدل منطق logout عام هون، وإلا الموقع
  // بضل يترسل للسيرفر بعد الخروج فعليًا.
  final Future<void> Function()? onLogout;

  const DriverHeader({super.key, required this.isWeb, required this.padding, this.onLogout});

  static const Color brandColor = AppColors.brand;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    if (onLogout != null) {
      await onLogout!();
      return;
    }
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LandingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final iconColor = Theme.of(context).textTheme.bodyLarge?.color;
    final avatarUrl = ApiConstants.resolveImageUrl(user?.profilePicture);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.86),
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // ✅ على الشاشات الواسعة القائمة الجانبية ثابتة دايمًا (بدون
                  // Scaffold.drawer إطلاقًا) - هاد الفحص الديناميكي بيقرر يعرض
                  // زر القائمة المنسدلة أو لأ، بدل ما نمرر flag يدوي.
                  Builder(
                    builder: (context) {
                      final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
                      if (!hasDrawer) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 4, right: 8),
                        child: InkWell(
                          onTap: () => Scaffold.of(context).openDrawer(),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.menu, color: iconColor, size: 22),
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(color: brandColor, borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'لوحة السائق',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: iconColor),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LanguageToggleButton(iconColor: iconColor),
                  ThemeToggleButton(iconColor: iconColor),
                  NotificationBell(iconColor: iconColor),
                  IconButton(
                    icon: Icon(Icons.bar_chart_rounded, color: brandColor),
                    tooltip: 'الأرباح والإحصائيات',
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverEarningsScreen()));
                    },
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) {
                      if (value == 'logout') {
                        _handleLogout(context, ref);
                      } else if (value == 'profile') {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline, size: 18, color: iconColor),
                            const SizedBox(width: 10),
                            const Text('الملف الشخصي'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                            const SizedBox(width: 10),
                            const Text('تسجيل الخروج'),
                          ],
                        ),
                      ),
                    ],
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: brandColor.withValues(alpha: 0.12),
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? Icon(Icons.person, color: brandColor, size: 17) : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
