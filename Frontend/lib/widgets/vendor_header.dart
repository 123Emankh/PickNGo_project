// lib/widgets/vendor_header.dart
//
// هيدر لوحة صاحب المحل (Vendor/Business) — نفس القالب البصري لـ AppHeader/
// AdminHeader: نفس الارتفاع/الألوان/الظل الزجاجي/المسافات/الأيقونات، بمحتوى
// مناسب للوحة (اسم المتجر بدل اسم التطبيق، خانة بحث الطلبات/المنتجات،
// شارة حالة الاعتماد، بدل السلة وشعار الأدمن).
//
// ✅ مستخرج من _buildHeader() القديمة بـ business_dashboard_screen.dart -
// كانت أول عنصر داخل SingleChildScrollView (بتختفي بالتمرير)، صارت هون
// ودجة ثابتة (Pinned) خارج منطقة التمرير تمامًا متل باقي اللوحات.
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_themes.dart';
import '../data/models/store_model.dart';
import '../providers/auth_provider.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/profile/profile_screen.dart';
import 'app_header.dart';
import 'notification_bell.dart';

class VendorHeader extends ConsumerWidget implements PreferredSizeWidget {
  final bool isWeb;
  final double padding;
  final StoreModel? store;
  final TextEditingController searchController;

  const VendorHeader({
    super.key,
    required this.isWeb,
    required this.padding,
    required this.store,
    required this.searchController,
  });

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

  Widget _buildStatusBadge(BuildContext context, Locale locale) {
    final status = store?.approvalStatus;
    final isPending = (status ?? 'Pending').toLowerCase() == 'pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPending ? Colors.blueGrey.withValues(alpha: 0.12) : brandColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPending ? AppLocalizations.t(locale, 'bizdash_pending_approval') : (status ?? ''),
        style: TextStyle(
          color: isPending ? Colors.blueGrey.shade700 : brandColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final user = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      decoration: BoxDecoration(color: brandColor, borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        store?.name ?? AppLocalizations.t(locale, 'app_name'),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: iconColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(context, locale),
                  ],
                ),
              ),
              if (isWeb)
                Container(
                  width: 300,
                  height: 42,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceLow,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.t(locale, 'bizdash_search_hint'),
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
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
                            style: TextStyle(color: iconColor, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        if (isWeb && user != null) const SizedBox(width: 6),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: brandColor.withValues(alpha: 0.1),
                          child: const Icon(Icons.storefront_outlined, size: 16, color: brandColor),
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
