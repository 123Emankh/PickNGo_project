// lib/screens/cart/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/cart_provider.dart';
import '../../data/models/cart_item_model.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/app_card.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_themes.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  static const Color brandColor = AppColors.brand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    // تجميع العناصر حسب اسم المتجر
    final Map<String, List<CartItem>> grouped = {};
    for (final item in cart.items) {
      grouped.putIfAbsent(item.storeName, () => []).add(item);
    }

    return MainLayout(
      builder: (context, isWeb, padding, width) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: padding,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: Colors.grey[600],
                  ),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: Text(
                    AppLocalizations.t(
                      Localizations.localeOf(context),
                      'cart_continue_shopping',
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.t(
                            Localizations.localeOf(context),
                            'cart_title',
                          ),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${cart.totalCount} ${cart.totalCount == 1 ? AppLocalizations.t(Localizations.localeOf(context), 'cart_item_singular') : AppLocalizations.t(Localizations.localeOf(context), 'cart_items_plural')}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (cart.items.isNotEmpty)
                      TextButton(
                        onPressed: () => cartNotifier.clear(),
                        child: Text(
                          AppLocalizations.t(
                            Localizations.localeOf(context),
                            'cart_clear_all',
                          ),
                          style: const TextStyle(
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (cart.isEmpty)
                  _buildEmptyState(context)
                else ...[
                  // هنا يتم عرض كل متجر وبداخله منتجاته وحسبته وزر الـ Checkout الخاص به
                  ...grouped.entries.map(
                    (entry) => _buildStoreGroup(
                      context,
                      entry.key,
                      entry.value,
                      cartNotifier,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 72,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.t(
                Localizations.localeOf(context),
                'cart_empty_title',
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.t(
                Localizations.localeOf(context),
                'cart_empty_subtitle',
              ),
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.t(
                  Localizations.localeOf(context),
                  'cart_browse_stores',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreGroup(
    BuildContext context,
    String storeName,
    List<CartItem> items,
    CartNotifier cartNotifier,
  ) {
    // 1. حساب الحسبة الكلية لهذا المتجر المحدد فقط
    double storeSubtotal = items.fold(0, (sum, item) => sum + item.subtotal);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 24,
      ), // زيادة المسافة بين المتاجر قليلاً لمظهر أفضل
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس المتجر
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Text(
              storeName.isEmpty
                  ? AppLocalizations.t(
                      Localizations.localeOf(context),
                      'cart_store_fallback',
                    )
                  : storeName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),

          // عرض منتجات هذا المتجر فقط
          ...items.map((item) => _buildItemRow(context, item, cartNotifier)),

          // 2. بلوك الحسبة وزر الـ Checkout الخاص بهذا المتجر فقط بالأسفل
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${AppLocalizations.t(Localizations.localeOf(context), 'cart_subtotal_label')} ($storeName)',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    Text(
                      '₪${storeSubtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.t(
                    Localizations.localeOf(context),
                    'cart_delivery_fees_note',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
                const Divider(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // نمرر المنتجات الخاصة بهذا المتجر فقط لشاشة الـ Checkout
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CheckoutScreen(
                          storeName: storeName,
                          checkoutItems: items,
                          totalPrice: storeSubtotal,
                        ),
                      ),
                    );
                  },
                  icon: Text(
                    AppLocalizations.t(
                      Localizations.localeOf(context),
                      'cart_proceed_to_checkout',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  label: const Icon(Icons.arrow_forward, size: 16),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildItemRow(
    BuildContext context,
    CartItem item,
    CartNotifier cartNotifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              item.product.imageUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.selectedVariant != null
                      ? '${item.product.name} (${item.selectedVariant!.label})'
                      : item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.selectedAddons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '+ ${item.selectedAddons.map((a) => a.name).join('، ')}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (item.selectedExclusionLabels.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '- ${item.selectedExclusionLabels.join('، ')}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (item.selectedOptions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.selectedOptions
                          .map((o) => '${o.groupName}: ${o.label}')
                          .join('، '),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  '₪${item.unitPrice.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _qtyButton(
                context: context,
                icon: Icons.remove,
                onTap: () => cartNotifier.decrement(item.lineKey),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              _qtyButton(
                context: context,
                icon: Icons.add,
                onTap: () => cartNotifier.increment(item.lineKey),
              ),
            ],
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 56,
            child: Text(
              '₪${item.subtotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 20,
            ),
            onPressed: () => cartNotifier.removeItem(item.lineKey),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Icon(
          icon,
          size: 13,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }
}
