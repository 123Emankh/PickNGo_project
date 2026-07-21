// lib/screens/business/vendor_reviews_screen.dart
//
// تقييمات محل صاحب المحل الحالي: قائمة بكل تقييمات الزبائن (نجوم + تعليق)،
// تجيب المتجر من storeProvider (نفس نمط business_dashboard_screen.dart)
// عشان الشاشة تضل مستقلة وقابلة للفتح من أي مكان (Drawer/Sidebar).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../providers/store_provider.dart';
import '../../services/review_service.dart';
import '../../widgets/detail_app_bar.dart';

class VendorReviewsScreen extends ConsumerStatefulWidget {
  const VendorReviewsScreen({super.key});

  @override
  ConsumerState<VendorReviewsScreen> createState() => _VendorReviewsScreenState();
}

class _VendorReviewsScreenState extends ConsumerState<VendorReviewsScreen> {
  final _reviewService = ReviewService();

  bool _isLoading = true;
  String? _error;
  List<ReviewModel> _reviews = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    var store = ref.read(storeProvider).store;
    if (store == null) {
      await ref.read(storeProvider.notifier).fetchMyStore();
      if (!mounted) return;
      store = ref.read(storeProvider).store;
    }
    if (store == null) {
      setState(() {
        _isLoading = false;
        _error = 'Store not found';
      });
      return;
    }

    final result = await _reviewService.getStoreReviews(store.id);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) {
        _reviews = result.reviews;
      } else {
        _error = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return Scaffold(
      appBar: DetailAppBar(title: AppLocalizations.t(locale, 'vendorreviews_title')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.grey[600])))
              : _reviews.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.t(locale, 'vendorreviews_empty'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) => _buildReviewCard(_reviews[index]),
                      ),
                    ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.amber,
                  ),
                ),
              ),
              const Spacer(),
              if (review.createdAt != null)
                Text(
                  '${review.createdAt!.year}-${review.createdAt!.month.toString().padLeft(2, '0')}-${review.createdAt!.day.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
            ],
          ),
          if (review.customerName != null) ...[
            const SizedBox(height: 6),
            Text(
              review.customerName!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.comment!, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
