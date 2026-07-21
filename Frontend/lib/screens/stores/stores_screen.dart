// lib/screens/stores/stores_screen.dart
//
// شاشة تصفح كل المتاجر: بحث بالاسم، فلاتر (تقييم/مفتوح الآن)، ترتيب
// (تقييم/مسافة/رواج/الأحدث)، وتحميل صفحات إضافية (infinite scroll) عبر
// storesListNotifierProvider (StateNotifier بديل عن FutureProvider.family
// القديم عشان يدعم "تحميل المزيد").

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/category_model.dart';
import '../../data/models/store_model.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/stores_list_provider.dart';
import '../../providers/stores_query.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/store_card.dart';
import '../../widgets/store_card_skeleton.dart';
import '../../widgets/hover_lift.dart';
import 'store_detail_screen.dart';
import '../../core/i18n/app_localizations.dart';

class StoresScreen extends ConsumerStatefulWidget {
  final String? initialCategoryId; // null = عرض كل المتاجر بدون فلتر
  final bool isGuest; // ضيف (مش مسجل دخول) ولا مستخدم مسجل
  final String? initialSearchQuery; // جاي من حقل البحث بالـ Header المشترك

  const StoresScreen({
    super.key,
    this.initialCategoryId,
    this.isGuest = false,
    this.initialSearchQuery,
  });

  @override
  ConsumerState<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends ConsumerState<StoresScreen> {
  final Color brandColor = AppColors.brand;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  String? _selectedCategoryId;
  double? _minRating;
  bool _openNow = false;
  String _sortBy = 'rating';
  bool _isMapView = false;
  LatLng? _userPos;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!;
    }
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isGuest) {
        ref.read(favoritesProvider.notifier).loadInitial();
      }
      _reload();
      // ✅ أول تحميل بيصير فورًا بدون موقع (فالباك بالترتيب الافتراضي)، وبعد
      // ما الموقع يتحدد منعيد التحميل - عشان "ترتيب حسب المسافة" يشتغل فعليًا
      // ومركز الخارطة يصير عند المستخدم مش أول متجر بالقائمة.
      ref.read(userLocationProvider.future).then((pos) {
        if (!mounted || pos == null) return;
        setState(() => _userPos = pos);
        _reload();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(storesListNotifierProvider.notifier).loadMore();
    }
  }

  void _reload() {
    ref
        .read(storesListNotifierProvider.notifier)
        .updateQuery(
          StoresQuery(
            categoryId: _selectedCategoryId,
            search: _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
            minRating: _minRating,
            openNow: _openNow,
            sortBy: _sortBy,
            lat: _userPos?.latitude,
            lng: _userPos?.longitude,
          ),
        );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  bool get _hasActiveFilters =>
      _selectedCategoryId != null ||
      _minRating != null ||
      _openNow ||
      _searchController.text.trim().isNotEmpty;

  // ✅ UI-only: بترجّع نفس متغيرات الحالة الموجودة أصلًا لقيمها الافتراضية
  // وتعيد التحميل بنفس _reload() - ما بتضيف أي فلتر أو منطق جديد.
  void _clearFilters() {
    setState(() {
      _selectedCategoryId = null;
      _minRating = null;
      _openNow = false;
      _sortBy = 'rating';
      _searchController.clear();
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(storesListNotifierProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final catMap = {for (final c in categories) c.id: c.name};
    final locale = Localizations.localeOf(context);

    return MainLayout(
      isGuest: widget.isGuest,
      builder: (context, isWeb, padding, width) {
        int crossAxisCount = StoreCard.gridColumnsForWidth(width);

        return SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(
            horizontal: padding,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                            // Breadcrumb
                            Row(
                              children: [
                                InkWell(
                                  onTap: () => Navigator.pop(context),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      AppLocalizations.t(
                                        locale,
                                        'stores_breadcrumb_home',
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Icon(
                                    Icons.chevron_right,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    _selectedCategoryId != null
                                        ? (catMap[_selectedCategoryId] ??
                                              AppLocalizations.t(
                                                locale,
                                                'stores_title',
                                              ))
                                        : AppLocalizations.t(
                                            locale,
                                            'stores_title',
                                          ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Header: title + count (left) | sort + view toggle (right)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalizations.t(
                                          locale,
                                          'stores_title',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        AppLocalizations.t(
                                          locale,
                                          'stores_results_count',
                                        ).replaceFirst(
                                          '{count}',
                                          '${listState.stores.length}',
                                        ),
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildSortDropdown(locale),
                                    const SizedBox(width: 10),
                                    _buildViewToggle(locale),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildSearchField(locale),
                            const SizedBox(height: 16),
                            _buildFilterPanel(locale, categories),
                            const SizedBox(height: 24),
                            if (listState.isLoading)
                              StoreGridSkeleton(crossAxisCount: crossAxisCount)
                            else if (listState.stores.isEmpty)
                              _buildEmptyState(locale)
                            else if (_isMapView)
                              _buildStoresMap(listState.stores)
                            else ...[
                              _buildStoresGrid(
                                listState.stores,
                                crossAxisCount,
                                catMap,
                              ),
                              if (listState.isLoadingMore)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
  }

  Widget _buildViewToggle(Locale locale) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _viewToggleButton(
            icon: Icons.grid_view,
            selected: !_isMapView,
            onTap: () => setState(() => _isMapView = false),
          ),
          _viewToggleButton(
            icon: Icons.map_outlined,
            selected: _isMapView,
            onTap: () => setState(() => _isMapView = true),
          ),
        ],
      ),
    );
  }

  Widget _viewToggleButton({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildStoresMap(List<StoreModel> stores) {
    final withLocation = stores
        .where((s) => s.latitude != null && s.longitude != null)
        .toList();
    final center =
        _userPos ??
        (withLocation.isNotEmpty
            ? LatLng(
                withLocation.first.latitude!,
                withLocation.first.longitude!,
              )
            : const LatLng(31.95, 35.2));

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 520,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: _userPos != null ? 12 : 8,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.pickngo.app',
            ),
            MarkerLayer(
              markers: [
                if (_userPos != null)
                  Marker(
                    point: _userPos!,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blueAccent,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ...withLocation.map((store) {
                  return Marker(
                    point: LatLng(store.latitude!, store.longitude!),
                    width: 40,
                    height: 40,
                    child: InkWell(
                      onTap: () => _showStorePreview(store),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.redAccent,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// بطاقة معاينة سريعة تنفتح لما تضغطي على Marker متجر بالخارطة: اسمه،
  /// تقييمه، وقت التوصيل المتوقع، وزر ينقلها لصفحة المتجر الكاملة.
  void _showStorePreview(StoreModel store) {
    final locale = Localizations.localeOf(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    store.imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 56,
                      height: 56,
                      color: Theme.of(context).dividerColor,
                      child: const Icon(
                        Icons.storefront_outlined,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            '${store.averageRating}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.access_time,
                            color: Colors.grey.shade400,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              store.distanceKm != null
                                  ? '${store.deliveryTime} · ${store.distanceKm!.toStringAsFixed(1)} km'
                                  : store.deliveryTime,
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StoreDetailScreen(
                        store: store,
                        isGuest: widget.isGuest,
                      ),
                    ),
                  );
                },
                child: Text(AppLocalizations.t(locale, 'storesmap_view_store')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(Locale locale) {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: AppLocalizations.t(locale, 'stores_search_hint'),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _reload();
                },
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

  // ---------------- Sort (بالهيدر جنب View Toggle) ----------------
  Widget _buildSortDropdown(Locale locale) {
    return _dropdownChip<String>(
      value: _sortBy,
      items: const ['rating', 'distance', 'popularity', 'newest'],
      icon: Icons.sort,
      labelBuilder: (v) => AppLocalizations.t(locale, 'stores_sort_$v'),
      onChanged: (v) => setState(() {
        _sortBy = v ?? 'rating';
        _reload();
      }),
    );
  }

  // ---------------- Filter Panel: فئات + تقييم + مفتوح الآن، مع Clear All ----------------
  Widget _buildFilterPanel(Locale locale, List<CategoryModel> categories) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.t(locale, 'stores_filters_label'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              if (_hasActiveFilters)
                InkWell(
                  onTap: _clearFilters,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      AppLocalizations.t(locale, 'stores_clear_filters'),
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCategoryChips(categories),
          const SizedBox(height: 10),
          Row(
            children: [
              _dropdownChip<double?>(
                value: _minRating,
                items: const [null, 3.0, 4.0, 4.5],
                icon: Icons.star_border,
                labelBuilder: (v) => v == null
                    ? AppLocalizations.t(locale, 'stores_filter_rating_any')
                    : '$v+ ★',
                onChanged: (v) => setState(() {
                  _minRating = v;
                  _reload();
                }),
              ),
              const SizedBox(width: 8),
              _chip(
                label: AppLocalizations.t(locale, 'stores_filter_open_now'),
                isSelected: _openNow,
                onTap: () => setState(() {
                  _openNow = !_openNow;
                  _reload();
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdownChip<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
    IconData? icon,
  }) {
    return HoverLift(
      liftPx: 2,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        alignment: Alignment.center,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            icon: Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.grey[600],
            ),
            items: items
                .map(
                  (v) => DropdownMenuItem<T>(
                    value: v,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          labelBuilder(v),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            selectedItemBuilder: (context) => items
                .map(
                  (v) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          labelBuilder(v),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(List<CategoryModel> categories) {
    final locale = Localizations.localeOf(context);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip(
            label: AppLocalizations.t(locale, 'stores_chip_all'),
            isSelected: _selectedCategoryId == null,
            onTap: () => setState(() {
              _selectedCategoryId = null;
              _reload();
            }),
          ),
          const SizedBox(width: 8),
          ...categories.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(
                label: cat.name,
                isSelected: _selectedCategoryId == cat.id,
                onTap: () => setState(() {
                  _selectedCategoryId = cat.id;
                  _reload();
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return HoverLift(
      liftPx: 2,
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.accent
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
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
                color: brandColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.storefront_outlined,
                size: 56,
                color: brandColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.t(locale, 'stores_empty_state'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.t(locale, 'stores_empty_state_subtitle'),
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: brandColor,
                  side: BorderSide(color: brandColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: Text(AppLocalizations.t(locale, 'stores_clear_filters')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStoresGrid(
    List<dynamic> stores,
    int crossAxisCount,
    Map<String, String> catMap,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: StoreCard.gridItemHeight,
      ),
      itemCount: stores.length,
      itemBuilder: (context, index) {
        final store = stores[index];
        final categoryName = catMap[store.categoryId] ?? '';
        return StoreCard(
          store: store,
          categoryName: categoryName,
          isGuest: widget.isGuest,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    StoreDetailScreen(store: store, isGuest: widget.isGuest),
              ),
            );
          },
        );
      },
    );
  }
}
