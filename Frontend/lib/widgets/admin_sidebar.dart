// lib/widgets/admin_sidebar.dart
//
// Sidebar ثابتة للأدمن (ويب، عرض > 900) - نفس القالب البصري لـ
// CustomerSidebar/VendorSidebar: خلفية Theme.cardColor بدل الشريط الغامق
// المستقل، عناصر مدوّرة (AppRadius.md) بدل ListTile مسطّحة بألوان بيضاء ثابتة.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_themes.dart';
import '../providers/auth_provider.dart';
import '../screens/landing/landing_screen.dart';
import 'admin_nav_items.dart';

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key});

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
    final items = buildAdminNavItems(context, closeBefore: () {});

    return Material(
      color: Theme.of(context).cardColor,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: brandColor.withValues(alpha: 0.1),
                      child: const Icon(Icons.admin_panel_settings_outlined, size: 20, color: brandColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (user != null)
                            Text(
                              user.email,
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
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
      ),
    );
  }
}
