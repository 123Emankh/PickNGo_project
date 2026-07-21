// lib/screens/home/shortcuts/new_arrivals_screen.dart
//
// "وصل حديثاً" - اختصار الصفحة الرئيسية: شبكة منتجات (كل المتاجر) مرتبة
// الأحدث أولًا (GET /api/stores/new-arrivals). نفس نمط favorites_screen.dart
// البسيط (تحميل مرة وحدة + حالة فارغة)، بس بـ ProductCard بدل StoreCard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/product_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/store_service.dart';
import '../../../widgets/main_layout.dart';
import '../../../widgets/product_card.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../stores/product_detail_screen.dart';

class NewArrivalsScreen extends ConsumerStatefulWidget {
  const NewArrivalsScreen({super.key});

  @override
  ConsumerState<NewArrivalsScreen> createState() => _NewArrivalsScreenState();
}

class _NewArrivalsScreenState extends ConsumerState<NewArrivalsScreen> {
  final _storeService = StoreService();
  bool _isLoading = true;
  List<ProductModel> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final products = await _storeService.getNewArrivals(limit: 40);
    if (!mounted) return;
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

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
                  AppLocalizations.t(locale, 'newarrivals_title'),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Text(
                        AppLocalizations.t(locale, 'newarrivals_empty'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = width > 950 ? 4 : (width > 650 ? 3 : 2);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.76,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          final storeName = product.storeName;
                          return ProductCard(
                            product: product,
                            storeName: storeName,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailScreen(
                                    product: product,
                                    storeName: storeName,
                                    isGuest: false,
                                  ),
                                ),
                              );
                            },
                            onAddToCart: () {
                              ref.read(cartProvider.notifier).addProduct(product, storeName);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.t(locale, 'home_added_to_cart')
                                        .replaceFirst('{item}', product.name),
                                  ),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
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
