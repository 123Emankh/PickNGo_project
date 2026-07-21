// lib/screens/categories/categories_screen.dart
//
// شاشة "الفئات" - عرض كل فئات المتاجر كبطاقات (أيقونة ملوّنة + اسم)، بنفس
// هوية شاشة All Stores (breadcrumb، عنوان+عدّاد، بحث) لكن بدون فلاتر
// التقييم/مفتوح الآن لأنها مش منطقية لصفحة فئات. الضغط عالبطاقة يودّي لـ
// StoresScreen مفلترة على الفئة (initialCategoryId) - نفس مسار كرت الفئة
// بالصفحة الرئيسية (home_screen.dart _buildCategoriesSection).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/category_model.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/main_layout.dart';
import '../stores/stores_screen.dart';
import '../../core/i18n/app_localizations.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  final bool isGuest;

  const CategoriesScreen({super.key, this.isGuest = false});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static int _gridColumnsForWidth(double width) {
    if (width > 1600) return 6;
    if (width > 1300) return 5;
    if (width > 950) return 4;
    if (width > 650) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final locale = Localizations.localeOf(context);

    return MainLayout(
      isGuest: widget.isGuest,
      activeNavId: 'categories',
      builder: (context, isWeb, padding, width) {
        final crossAxisCount = _gridColumnsForWidth(width);
        final categories = categoriesAsync.valueOrNull ?? [];
        final filtered = _query.trim().isEmpty
            ? categories
            : categories
                .where(
                  (c) => c.name.toLowerCase().contains(
                    _query.trim().toLowerCase(),
                  ),
                )
                .toList();

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBreadcrumb(locale),
              const SizedBox(height: 12),
              _buildHeader(locale, filtered.length),
              const SizedBox(height: 20),
              _buildSearchField(locale),
              const SizedBox(height: 24),
              if (categoriesAsync.isLoading)
                _buildSkeletonGrid(crossAxisCount)
              else if (filtered.isEmpty)
                _buildEmptyState(locale)
              else
                _buildCategoriesGrid(filtered, crossAxisCount),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreadcrumb(Locale locale) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              AppLocalizations.t(locale, 'stores_breadcrumb_home'),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.chevron_right, size: 14, color: Colors.grey[500]),
        ),
        Text(
          AppLocalizations.t(locale, 'categories_title'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Locale locale, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.t(locale, 'categories_title'),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.t(
            locale,
            'categories_results_count',
          ).replaceFirst('{count}', '$count'),
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSearchField(Locale locale) {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: AppLocalizations.t(locale, 'categories_search_hint'),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() {
                  _searchController.clear();
                  _query = '';
                }),
              )
            : null,
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid(
    List<CategoryModel> categories,
    int crossAxisCount,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.92,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) =>
          _CategoryCard(category: categories[index], isGuest: widget.isGuest),
    );
  }

  Widget _buildSkeletonGrid(int crossAxisCount) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.92,
      ),
      itemCount: crossAxisCount * 2,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Locale locale) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.category_outlined,
                size: 56,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.t(locale, 'categories_empty_state'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.t(locale, 'categories_empty_state_subtitle'),
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة فئة واحدة - نفس لغة تصميم StoreCard (خلفية بيضاء، حواف مدوّرة،
/// hover-lift وظل ناعم) لكن بمحتوى دائرة أيقونة ملوّنة بدل صورة متجر، لأن
/// الفئة نفسها ما إلها صورة.
class _CategoryCard extends StatefulWidget {
  final CategoryModel category;
  final bool isGuest;

  const _CategoryCard({required this.category, required this.isGuest});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = widget.category.color;
    final locale = Localizations.localeOf(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovering ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: isDark
              ? Border.all(color: theme.dividerColor)
              : Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? 0.24 : (_hovering ? 0.12 : 0.05),
              ),
              blurRadius: _hovering ? 22 : 10,
              offset: Offset(0, _hovering ? 10 : 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoresScreen(
                  initialCategoryId: widget.category.id,
                  isGuest: widget.isGuest,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 18,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.category.iconData,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.t(locale, 'categories_card_browse'),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 12, color: color),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
