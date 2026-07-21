// lib/widgets/guest_top_bar.dart
//
// شريط علوي بسيط (لوجو + اسم التطبيق) للزوّار غير المسجّلين - بديل
// AppHeader لما isGuest=true (زوّار ما إلهم حساب/سلة/إشعارات). كان مكرر
// حرفيًا (نفس التصميم بالضبط) بـ stores_screen.dart/product_detail_screen.dart/
// store_detail_screen.dart كـ _buildGuestTopBar خاصة بكل ملف - استُخرج هون.
//
// ✅ بالرغم من إنه بديل مبسّط عن AppHeader (بدون سلة/إشعارات/بروفايل لأن
// الزوّار ما إلهم حساب)، بيشارك معه نفس أزرار تبديل اللغة/الوضع والبحث -
// الزوّار المفروض يقدروا يبدّلوا اللغة والمظهر ويبحثوا بدون تسجيل دخول.
import 'package:flutter/material.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_themes.dart';
import '../screens/stores/stores_screen.dart';
import 'app_header.dart';

class GuestTopBar extends StatefulWidget {
  final double padding;
  final bool isWeb;

  const GuestTopBar({super.key, required this.padding, this.isWeb = false});

  static const Color brandColor = AppColors.brand;

  @override
  State<GuestTopBar> createState() => _GuestTopBarState();
}

class _GuestTopBarState extends State<GuestTopBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _goSearch([String? query]) {
    final q = (query ?? _searchController.text).trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoresScreen(
          isGuest: true,
          initialSearchQuery: q.isEmpty ? null : q,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final locale = Localizations.localeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWeb = widget.isWeb;
    final iconColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: widget.padding, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (canPop)
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
                ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GuestTopBar.brandColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.t(locale, 'app_name'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (isWeb)
            Container(
              width: 360,
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceLow,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => _goSearch(value),
                decoration: InputDecoration(
                  hintText: AppLocalizations.t(locale, 'header_search_hint'),
                  hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  prefixIcon: InkWell(
                    onTap: () => _goSearch(),
                    borderRadius: BorderRadius.circular(20),
                    child: Icon(Icons.search, color: Colors.grey.shade500, size: 18),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isWeb)
                IconButton(
                  tooltip: AppLocalizations.t(locale, 'header_search_tooltip'),
                  icon: Icon(Icons.search, color: iconColor, size: 22),
                  onPressed: () => _goSearch(),
                ),
              LanguageToggleButton(iconColor: iconColor),
              ThemeToggleButton(iconColor: iconColor),
            ],
          ),
        ],
      ),
    );
  }
}
