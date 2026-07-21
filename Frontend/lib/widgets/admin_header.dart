// lib/widgets/admin_header.dart
//
// هيدر لوحة تحكم الأدمن — نفس القالب البصري لـ AppHeader (هيدر الزبون):
// نفس الارتفاع/الألوان/الظل الزجاجي/المسافات/الأيقونات، بس بمحتوى مختلف
// (شارة "Admin" بدل السلة، ما في بحث منتجات لأنه مالوش معنى بسياق إداري).
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_themes.dart';
import 'app_header.dart';
import 'notification_bell.dart';

class AdminHeader extends ConsumerWidget implements PreferredSizeWidget {
  final bool isWeb;
  final double padding;

  const AdminHeader({super.key, required this.isWeb, required this.padding});

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
    final locale = Localizations.localeOf(context);
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
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (!isWeb)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 8),
                      child: InkWell(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.menu, color: iconColor, size: 22),
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: brandColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.t(locale, 'app_name'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: brandColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'Admin',
                      style: TextStyle(
                        color: brandColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline, size: 18, color: iconColor),
                            const SizedBox(width: 10),
                            Text(AppLocalizations.t(locale, 'header_profile')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                            const SizedBox(width: 10),
                            Text(AppLocalizations.t(locale, 'header_logout')),
                          ],
                        ),
                      ),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isWeb && user != null)
                          Text(
                            user.fullName,
                            style: TextStyle(
                              color: iconColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        if (isWeb && user != null) const SizedBox(width: 6),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: brandColor.withValues(alpha: 0.1),
                          child: const Icon(Icons.admin_panel_settings_outlined, size: 16, color: brandColor),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[600]),
                      ],
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
