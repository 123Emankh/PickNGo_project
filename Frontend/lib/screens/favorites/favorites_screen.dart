// lib/screens/favorites/favorites_screen.dart
//
// شاشة "مفضلتي": قائمة المتاجر يلي الزبون علّم عليها قلب. بتعتمد على
// FavoriteService.listFavorites() مباشرة (بدل provider منفصل) لأنه شاشة
// بسيطة بحالة تحميل واحدة، بنفس روح الأنماط البسيطة الموجودة بالمشروع.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/store_model.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/store_card.dart';
import '../../widgets/store_card_skeleton.dart';
import '../stores/store_detail_screen.dart';
import '../../core/i18n/app_localizations.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  bool _isLoading = true;
  List<StoreModel> _stores = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final stores = await ref.read(favoriteServiceProvider).listFavorites();
    // نحدّث المجموعة العامة للمفضلة (بدل ما تعتمد فقط على loadInitial) عشان
    // القلوب بباقي الشاشات تضل متوافقة مع اللي انعمله هون.
    ref
        .read(favoritesProvider.notifier)
        .setAll(stores.map((s) => s.id).toSet());
    if (!mounted) return;
    setState(() {
      _stores = stores;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final catMap = {for (final c in categories) c.id: c.name};

    return MainLayout(
      builder: (context, isWeb, padding, width) {
        return RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? SingleChildScrollView(
                  padding: EdgeInsets.all(padding),
                  child: StoreGridSkeleton(
                    crossAxisCount: StoreCard.gridColumnsForWidth(width),
                  ),
                )
              : _stores.isEmpty
              ? LayoutBuilder(
                  builder: (context, contentConstraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: contentConstraints.maxHeight,
                      ),
                      child: _buildEmptyState(locale),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, innerConstraints) {
                    int crossAxisCount =
                        StoreCard.gridColumnsForWidth(
                          innerConstraints.maxWidth,
                        );
                    return GridView.builder(
                      padding: EdgeInsets.all(padding),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent:
                                StoreCard.gridItemHeight,
                          ),
                      itemCount: _stores.length,
                      itemBuilder: (context, index) {
                        final store = _stores[index];
                        return StoreCard(
                          store: store,
                          categoryName:
                              catMap[store.categoryId] ?? '',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    StoreDetailScreen(
                                      store: store,
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(Locale locale) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border,
              size: 56,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.t(locale, 'favorites_empty_state'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.t(locale, 'favorites_empty_state_subtitle'),
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
