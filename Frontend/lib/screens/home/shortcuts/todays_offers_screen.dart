// lib/screens/home/shortcuts/todays_offers_screen.dart
//
// "عروض اليوم" - اختصار الصفحة الرئيسية: شبكة متاجر عندها كوبون خصم فعّال
// حاليًا (GET /api/stores?has_discount=true) - شارة الخصم بتظهر تلقائيًا على
// StoreCard (discount_label جاي جاهز من formatStore). نفس نمط favorites_screen.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/store_model.dart';
import '../../../providers/catalog_provider.dart';
import '../../../services/store_service.dart';
import '../../../widgets/main_layout.dart';
import '../../../widgets/store_card.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../stores/store_detail_screen.dart';

class TodaysOffersScreen extends ConsumerStatefulWidget {
  const TodaysOffersScreen({super.key});

  @override
  ConsumerState<TodaysOffersScreen> createState() => _TodaysOffersScreenState();
}

class _TodaysOffersScreenState extends ConsumerState<TodaysOffersScreen> {
  final _storeService = StoreService();
  bool _isLoading = true;
  List<StoreModel> _stores = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _storeService.listStoresPaged(hasDiscount: true, limit: 40);
    if (!mounted) return;
    setState(() {
      _stores = result.stores;
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t(locale, 'todaysoffers_title'),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_stores.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Text(
                        AppLocalizations.t(locale, 'todaysoffers_empty'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: StoreCard.gridColumnsForWidth(width),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: StoreCard.gridItemHeight,
                    ),
                    itemCount: _stores.length,
                    itemBuilder: (context, index) {
                      final store = _stores[index];
                      return StoreCard(
                        store: store,
                        categoryName: catMap[store.categoryId] ?? '',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoreDetailScreen(store: store, isGuest: false),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
