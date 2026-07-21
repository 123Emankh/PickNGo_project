// lib/widgets/app_header.dart
//
// هيدر مشترك لكل الشاشات بعد تسجيل الدخول (Home / Cart / إلخ) - عشان
// ما نكرر نفس كود اللوجو والبحث والسلة والإشعارات واسم المستخدم بكل شاشة.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/landing/landing_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/stores/stores_screen.dart';
import '../core/i18n/app_localizations.dart';
import '../core/i18n/locale_notifier.dart';
import '../core/theme/app_themes.dart';
import '../core/theme/theme_notifier.dart';
import 'notification_bell.dart';

class AppHeader extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final bool isWeb;
  final double padding;

  const AppHeader({super.key, required this.isWeb, required this.padding});

  static const Color brandColor = AppColors.brand;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  ConsumerState<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends ConsumerState<AppHeader> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LandingScreen()),
      (route) => false,
    );
  }

  void _goSearch([String? query]) {
    final q = (query ?? _searchController.text).trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            StoresScreen(initialSearchQuery: q.isEmpty ? null : q),
      ),
    );
  }

  // ✅ عرض ساكن (read-only) لعنوان التوصيل المحفوظ فعلاً بحساب الزبون
  // (نفس city/locationAddress اللي تنعرض/تتعدّل بـ profile_screen.dart) -
  // مش selector تفاعلي. لو ما عنده عنوان محفوظ، ما منعرض شي بدل نص فاضي.
  List<Widget> _buildDeliverToChip(
    BuildContext context,
    WidgetRef ref,
    Locale locale,
  ) {
    final user = ref.watch(authProvider).user;
    final address = user?.city ?? user?.locationAddress;
    if (address == null || address.isEmpty) return const [];

    return [
      const SizedBox(width: 16),
      Container(width: 1, height: 20, color: Theme.of(context).dividerColor),
      const SizedBox(width: 12),
      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
      const SizedBox(width: 4),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(
          '${AppLocalizations.t(locale, 'header_deliver_to')}: $address',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartProvider).totalCount;
    final locale = Localizations.localeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWeb = widget.isWeb;
    final padding = widget.padding;

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
                  // ✅ Global Header: أي شاشة توصلها عن طريق Navigator.push (يعني
                  // مش الشاشة الجذر بعد pushAndRemoveUntil) بتاخد زر Back تلقائيًا
                  // بدل القائمة (☰) - على الويب والموبايل الاثنين. ما في router
                  // بالتطبيق (لا go_router ولا named routes) فـ Navigator.canPop
                  // هو مصدر الحقيقة الوحيد لمعرفة "هل أنا الشاشة الجذر".
                  if (Navigator.canPop(context))
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 8),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.arrow_back,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            size: 22,
                          ),
                        ),
                      ),
                    )
                  else if (!isWeb)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 8),
                      child: InkWell(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.menu,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppHeader.brandColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.local_shipping_outlined,
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
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (isWeb) ..._buildDeliverToChip(context, ref, locale),
                ],
              ),
              if (isWeb)
                Container(
                  width: 400,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightSurfaceLow,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) => _goSearch(value),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.t(
                        locale,
                        'header_search_hint',
                      ),
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                      prefixIcon: InkWell(
                        onTap: () => _goSearch(),
                        borderRadius: BorderRadius.circular(20),
                        child: Icon(
                          Icons.search,
                          color: Colors.grey.shade500,
                          size: 18,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              Row(
                children: [
                  if (!isWeb)
                    IconButton(
                      tooltip: AppLocalizations.t(
                        locale,
                        'header_search_tooltip',
                      ),
                      icon: Icon(
                        Icons.search,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        size: 22,
                      ),
                      onPressed: () => _goSearch(),
                    ),
                  LanguageToggleButton(
                    iconColor: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  ThemeToggleButton(
                    iconColor: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.shopping_cart_outlined,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          size: 22,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CartScreen(),
                            ),
                          );
                        },
                      ),
                      if (cartCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$cartCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  NotificationBell(
                    iconColor: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'logout') {
                        _handleLogout(context, ref);
                      } else if (value == 'orders') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OrdersScreen(),
                          ),
                        );
                      } else if (value == 'profile') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                            const SizedBox(width: 10),
                            Text(AppLocalizations.t(locale, 'header_profile')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'orders',
                        child: Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              AppLocalizations.t(locale, 'header_my_orders'),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.logout,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 10),
                            Text(AppLocalizations.t(locale, 'header_logout')),
                          ],
                        ),
                      ),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isWeb)
                          Text(
                            ref.watch(authProvider).user?.fullName ?? '',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        if (isWeb) const SizedBox(width: 6),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppHeader.brandColor.withValues(
                            alpha: 0.1,
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: AppHeader.brandColor,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: Colors.grey[600],
                        ),
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

/// زر تبديل اللغة (EN/AR/FR) - مشترك بين AppHeader وGuestTopBar، ينعكس فورًا
/// على كل التطبيق لأنه بيكتب مباشرة على localeNotifierProvider (نفس المصدر
/// اللي MaterialApp.locale مربوط عليه بـ main.dart).
class LanguageToggleButton extends ConsumerWidget {
  final Color? iconColor;

  const LanguageToggleButton({super.key, this.iconColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    return PopupMenuButton<Locale>(
      tooltip: AppLocalizations.t(locale, 'settings_language'),
      icon: Icon(Icons.language, color: iconColor, size: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) =>
          ref.read(localeNotifierProvider.notifier).setLocale(value),
      itemBuilder: (context) => [
        for (final option in const [Locale('en'), Locale('ar'), Locale('fr')])
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                if (locale.languageCode == option.languageCode)
                  const Icon(Icons.check, size: 16, color: AppColors.brand)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.t(locale, 'language_${option.languageCode}'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// زر تبديل الوضع الفاتح/الغامق بضغطة وحدة - مشترك بين AppHeader وGuestTopBar.
/// بيكتب على themeNotifierProvider (المصدر اللي MaterialApp.themeMode مربوط
/// عليه) فبينعكس فورًا بكل الشاشات المفتوحة بدون إعادة تشغيل.
class ThemeToggleButton extends ConsumerWidget {
  final Color? iconColor;

  const ThemeToggleButton({super.key, this.iconColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: AppLocalizations.t(locale, 'landing2_theme_tooltip'),
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: iconColor,
        size: 22,
      ),
      onPressed: () => ref
          .read(themeNotifierProvider.notifier)
          .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}
