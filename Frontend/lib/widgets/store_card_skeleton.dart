// lib/widgets/store_card_skeleton.dart
//
// بطاقة/شبكة "هيكلية" (Skeleton) بديلة عن CircularProgressIndicator وقت
// تحميل قوائم المتاجر - نفس شكل StoreCard تقريبًا (صورة + سطور نص) بس
// بنبض شفافية خفيف بدل محتوى حقيقي، أقرب لتجربة تطبيقات التوصيل الاحترافية.

import 'package:flutter/material.dart';
import 'store_card.dart';

class StoreGridSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;

  const StoreGridSkeleton({
    super.key,
    required this.crossAxisCount,
    this.itemCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: StoreCard.gridItemHeight,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const StoreCardSkeleton(),
    );
  }
}

class StoreCardSkeleton extends StatefulWidget {
  const StoreCardSkeleton({super.key});

  @override
  State<StoreCardSkeleton> createState() => _StoreCardSkeletonState();
}

class _StoreCardSkeletonState extends State<StoreCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.45,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark
        ? Colors.white12
        : Colors.grey.shade200;

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) =>
          Opacity(opacity: _opacity.value, child: child),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 148,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 120, height: 14, color: baseColor),
                        const SizedBox(height: 8),
                        Container(width: 80, height: 11, color: baseColor),
                      ],
                    ),
                    Container(width: 140, height: 11, color: baseColor),
                    Container(width: 100, height: 11, color: baseColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
