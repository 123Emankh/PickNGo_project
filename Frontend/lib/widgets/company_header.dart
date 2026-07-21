// lib/widgets/company_header.dart
//
// هيدر لوحة شركة التوصيل (Fleet/Company) — نفس القالب البصري لباقي هيدرز
// اللوحات (AppHeader/AdminHeader/VendorHeader/DriverHeader). قبل هيك
// company_dashboard_screen.dart ما كان فيه أي شريط علوي ثابت أصلاً (زر
// خروج فقط بلا أي chrome)، فهاد أول هيدر حقيقي للوحة.
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_themes.dart';
import '../providers/auth_provider.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/profile/profile_screen.dart';
import 'app_header.dart';
import 'notification_bell.dart';

class CompanyHeader extends ConsumerWidget implements PreferredSizeWidget {
  final bool isWeb;
  final double padding;

  const CompanyHeader({super.key, required this.isWeb, required this.padding});

  static const Color brandColor = AppColors.brand;

  @override
  Size get preferredSize => const Size.fromHeight(64);

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
    final user = ref.watch(authProvider).user;
    final iconColor = Theme.of(context).textTheme.bodyLarge?.color;

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
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(color: brandColor, borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        user?.fullName ?? 'شركة التوصيل',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: iconColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LanguageToggleButton(iconColor: iconColor),
                  ThemeToggleButton(iconColor: iconColor),
                  NotificationBell(iconColor: iconColor),
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
                      child: const Icon(Icons.local_shipping_outlined, size: 16, color: brandColor),
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
