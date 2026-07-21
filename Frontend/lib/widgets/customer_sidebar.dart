// lib/widgets/customer_sidebar.dart
//
// Sidebar ثابتة للزبون (ويب، عرض > 900) - نفس محتوى CustomerDrawer بس
// معروضة دايمًا جنب المحتوى بدل ما تكون قائمة منزلقة.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/api_constants.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_themes.dart';
import '../providers/auth_provider.dart';
import '../screens/home/home_screen.dart';
import '../screens/landing/landing_screen.dart';
import 'customer_nav_items.dart';

class CustomerSidebar extends ConsumerWidget {
  // ✅ أي شاشة بتفتح عن طريق MainLayout فيها تمرر id البند المطابق إلها هون
  // (مثلاً 'home' أو 'categories') فيتحدد تلقائيًا كـ"نشط" بنفس ستايل Home
  // القديم (خلفية نعناعي + نص/أيقونة ملوّنة + ظل خفيف). null = بدون تمييز،
  // نفس سلوك باقي الشاشات اليوم (Cart/Orders/...) اللي ما إلها id مطابق بعد.
  final String? activeNavId;

  const CustomerSidebar({super.key, this.activeNavId});

  static const Color brandColor = AppColors.brand;

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
    final items = buildCustomerNavItems(context, closeBefore: () {});

    // ✅ Material بدل Container(decoration: BoxDecoration(color: ...)) - نفس
    // إصلاح admin_sidebar.dart: لون الخلفية لازم يكون على أقرب Material سلف
    // لـ ListTile وإلا خلفيته/ink splashes ما بتنرسم. الحدّ (border) بضل على
    // Container داخلي بدون لون، هاد ما بأثر على الـ ink lookup.
    return Material(
      color: Theme.of(context).cardColor,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              InkWell(
                onTap: () => goToProfile(context, closeBefore: () {}),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final avatarUrl = ApiConstants.resolveImageUrl(
                            user?.profilePicture,
                          );
                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: brandColor.withValues(alpha: 0.1),
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            onBackgroundImageError: avatarUrl != null
                                ? (_, _) {}
                                : null,
                            child: avatarUrl == null
                                ? const Icon(
                                    Icons.person_outline,
                                    size: 22,
                                    color: brandColor,
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (user != null)
                              Text(
                                user.email,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
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
              const Divider(height: 1),
              const SizedBox(height: 8),
              _buildNavTile(
                context,
                icon: Icons.home_outlined,
                label: AppLocalizations.t(locale, 'drawer_home'),
                isActive: activeNavId == 'home',
                onTap: () => _goHome(context),
              ),
              for (final item in items)
                _buildNavTile(
                  context,
                  icon: item.icon,
                  label: item.label,
                  isActive: activeNavId == item.id,
                  onTap: item.onTap,
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  leading: const Icon(
                    Icons.logout,
                    size: 20,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    AppLocalizations.t(locale, 'drawer_logout'),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
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

  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Container(
        decoration: isActive
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              )
            : null,
        child: ListTile(
          dense: true,
          selected: isActive,
          selectedTileColor: AppColors.secondaryContainer,
          selectedColor: AppColors.onSecondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          leading: Icon(
            icon,
            size: 20,
            color: isActive ? AppColors.onSecondaryContainer : null,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
