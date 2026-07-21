// lib/widgets/admin_drawer.dart
//
// Drawer الأدمن (موبايل) - نفس القالب البصري لـ CustomerDrawer/VendorDrawer:
// رأس بلون البطاقة (Theme.cardColor) + أفاتار بالأخضر الأساسي + عناصر
// مدوّرة (AppRadius.md)، بدل الشريط الغامق المستقل اللي كان موجود سابقًا.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_themes.dart';
import '../providers/auth_provider.dart';
import '../screens/landing/landing_screen.dart';
import 'admin_nav_items.dart';

class AdminDrawer extends ConsumerWidget {
  const AdminDrawer({super.key});

  static const Color brandColor = AppColors.brand;

  void _closeDrawer(BuildContext context) => Navigator.pop(context);

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
    final items = buildAdminNavItems(context, closeBefore: () => _closeDrawer(context));

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: brandColor.withValues(alpha: 0.1),
                    child: const Icon(Icons.admin_panel_settings_outlined, size: 24, color: brandColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: brandColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(color: brandColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  leading: Icon(item.icon, size: 20),
                  title: Text(item.label, style: const TextStyle(fontSize: 13)),
                  onTap: item.onTap,
                ),
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                leading: const Icon(Icons.logout, size: 20, color: Colors.redAccent),
                title: Text(
                  AppLocalizations.t(locale, 'adrawer_logout'),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
                onTap: () => _handleLogout(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
