// lib/widgets/home_skeleton.dart
//
// بديل هيكلي (Skeleton) لأول تحميل للصفحة الرئيسية - بدل CircularProgressIndicator
// وحيد بنص الشاشة، نفس تقنية store_card_skeleton.dart بالضبط (نبض شفافية
// AnimationController فوق مربعات رمادية، بدون مكتبة shimmer) بس بشكل يقارب
// تخطيط Home الفعلي (شورتكتس/Hero/فئات/متاجر) عشان الانتقال للمحتوى الحقيقي
// يحس أخف.

import 'package:flutter/material.dart';
import 'store_card_skeleton.dart';

class HomeSkeleton extends StatefulWidget {
  final double padding;
  final int crossAxisCount;

  const HomeSkeleton({
    super.key,
    required this.padding,
    required this.crossAxisCount,
  });

  @override
  State<HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<HomeSkeleton>
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

  Widget _block({
    double? width,
    required double height,
    BorderRadius? radius,
  }) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark
        ? Colors.white12
        : Colors.grey.shade200;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: radius ?? BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: widget.padding, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _opacity,
            builder: (context, child) =>
                Opacity(opacity: _opacity.value, child: child),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    4,
                    (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: i < 3 ? 12 : 0,
                        ),
                        child: _block(
                          height: 140,
                          radius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _block(
                  width: double.infinity,
                  height: 300,
                  radius: BorderRadius.circular(32),
                ),
                const SizedBox(height: 24),
                Row(
                  children: List.generate(
                    5,
                    (i) => Padding(
                      padding: EdgeInsetsDirectional.only(end: i < 4 ? 14 : 0),
                      child: _block(
                        width: 64,
                        height: 64,
                        radius: BorderRadius.circular(32),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          StoreGridSkeleton(
            crossAxisCount: widget.crossAxisCount,
            itemCount: widget.crossAxisCount * 2,
          ),
        ],
      ),
    );
  }
}
