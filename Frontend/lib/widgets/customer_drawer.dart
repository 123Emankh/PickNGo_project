// lib/widgets/customer_drawer.dart
//
// Drawer الزبون (موبايل) - رأس فيه اسم/إيميل المستخدم، بعده عناصر التنقل
// المشتركة (customer_nav_items.dart)، وبالآخر تسجيل خروج.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_themes.dart';
import '../providers/auth_provider.dart';
import '../screens/home/home_screen.dart';
import '../screens/landing/landing_screen.dart';
import 'customer_nav_items.dart';

class CustomerDrawer extends ConsumerWidget {
  const CustomerDrawer({super.key});

  static const Color brandColor = AppColors.brand;

  void _closeDrawer(BuildContext context) => Navigator.pop(context);

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

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
    final items = buildCustomerNavItems(context, closeBefore: () => _closeDrawer(context));

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            InkWell(
              onTap: () => goToProfile(context, closeBefore: () => _closeDrawer(context)),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  children: [
                    Builder(builder: (context) {
                      final avatarUrl = ApiConstants.resolveImageUrl(user?.profilePicture);
                      return CircleAvatar(
                        radius: 24,
                        backgroundColor: brandColor.withValues(alpha: 0.1),
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        onBackgroundImageError: avatarUrl != null ? (_, _) {} : null,
                        child: avatarUrl == null
                            ? const Icon(Icons.person_outline, size: 26, color: brandColor)
                            : null,
                      );
                    }),
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
                          if (user != null)
                            Text(
                              user.email,
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(AppLocalizations.t(locale, 'drawer_home')),
              onTap: () => _goHome(context),
            ),
            for (final item in items)
              ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                onTap: item.onTap,
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: Text(
                AppLocalizations.t(locale, 'drawer_logout'),
                style: const TextStyle(color: Colors.redAccent),
              ),
              onTap: () => _handleLogout(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
