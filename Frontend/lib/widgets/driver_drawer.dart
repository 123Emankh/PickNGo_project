// lib/widgets/driver_drawer.dart
//
// ✅ إعادة تصميم بصري (UI/UX فقط) - نفس buildDriverNavItems()/authProvider/
// المسارات بالضبط. الإضافات: (1) نقطة حالة صغيرة على الأفاتار تعكس
// driver_status الحقيقي (موجود أصلاً بـ UserModel)، وصورة البروفايل الحقيقية
// (profile_picture) لو موجودة بدل الأيقونة الثابتة دايمًا. (2) المحتوى صار
// Widget مستقل (DriverSidebarContent) قابل للتضمين مباشرة كقائمة جانبية
// ثابتة على الشاشات الواسعة (driver_home_screen.dart)، بدل ما يبقى محصور
// جوا Drawer منبثق بس - DriverDrawer (Drawer المنبثق للموبايل) صار مجرد
// غلاف رفيع فوقه، بدون أي تكرار بالمنطق.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_themes.dart';
import '../providers/auth_provider.dart';
import '../screens/landing/landing_screen.dart';
import '../services/driver_service.dart';
import 'driver_nav_items.dart';

/// Drawer منبثق (الشاشات الضيقة/الموبايل) - يفتح ويقفل فوق المحتوى.
class DriverDrawer extends ConsumerWidget {
  const DriverDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: DriverSidebarContent(onNavigate: () => Navigator.pop(context)),
    );
  }
}

/// نفس محتوى القائمة الجانبية، لكن قابل للتثبيت مباشرة بعرض ثابت على
/// الشاشات الواسعة (بدون Drawer/onNavigate = null فبيبقى ظاهر دايمًا بعد
/// أي ضغطة، عكس الموبايل يلي لازم يسكّر الـ Drawer أول).
class DriverSidebarContent extends ConsumerWidget {
  final VoidCallback? onNavigate;
  final bool bordered;

  const DriverSidebarContent({super.key, this.onNavigate, this.bordered = false});

  static const Color brandColor = AppColors.brand;

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LandingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final user = ref.watch(authProvider).user;
    final items = buildDriverNavItems(context, closeBefore: () => onNavigate?.call());
    final status = parseDriverAvailability(user?.driverStatus);
    final avatarUrl = ApiConstants.resolveImageUrl(user?.profilePicture);

    late Color statusColor;
    late String statusLabel;
    switch (status) {
      case DriverAvailabilityStatus.available:
        statusColor = brandColor;
        statusLabel = 'متصل الآن';
        break;
      case DriverAvailabilityStatus.busy:
        statusColor = AppColors.accent;
        statusLabel = 'مشغول بطلب';
        break;
      case DriverAvailabilityStatus.offline:
        statusColor = Colors.grey;
        statusLabel = 'غير متصل';
        break;
    }

    return Container(
      decoration: bordered
          ? BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
            )
          : null,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [brandColor, AppColors.brandDark],
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? const Icon(Icons.two_wheeler_rounded, size: 26, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        bottom: -1,
                        right: -1,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: brandColor, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (user?.email != null)
                          Text(
                            user!.email,
                            style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.7)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text(statusLabel, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                children: [
                  for (var i = 0; i < items.length; i++)
                    _DrawerItem(icon: items[i].icon, label: items[i].label, onTap: items[i].onTap, active: i == 0),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.redAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () => _handleLogout(context, ref),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 19),
                            const SizedBox(width: 10),
                            Text(
                              AppLocalizations.t(locale, 'ddrawer_logout'),
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// عنصر تنقّل بجانبي بتصميم موحّد: أيقونة بحاوية مدوّرة، ripple + hover على
/// الويب/الديسكتوب (InkWell أصلاً بيدعمهم بدون أي منطق إضافي). أول عنصر
/// ("طلبات متاحة") محدَّد بصريًا كـ "نشط" دايمًا لأنه فعليًا نفس الشاشة
/// الحالية (driver_home_screen) - القائمة أصلاً ما بتُستخدم إلا هون.
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _DrawerItem({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? AppColors.secondaryContainer.withValues(alpha: 0.28) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          hoverColor: AppColors.secondaryContainer.withValues(alpha: 0.18),
          splashColor: AppColors.secondaryContainer.withValues(alpha: 0.3),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: DriverSidebarContent.brandColor.withValues(alpha: active ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 18, color: DriverSidebarContent.brandColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 13.5, fontWeight: active ? FontWeight.bold : FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
