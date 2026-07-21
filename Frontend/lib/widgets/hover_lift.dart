// lib/widgets/hover_lift.dart
//
// ودجة عامة لتأثير "hover" على الويب (ترفع العنصر شوي للأعلى + ظل يكبر) -
// نفس التأثير المستخدم بـ StoreCard/StorePromoCard، بس معمّم لأي محتوى
// (كروت Features/Categories/Why PickNGo/Testimonials) بدون تكرار الكود.

import 'package:flutter/material.dart';

class HoverLift extends StatefulWidget {
  final Widget child;
  final double liftPx;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  // ✅ اختياري - 1.0 يعني بدون تكبير (نفس السلوك القديم لكل نقاط الاستخدام
  // الحالية). لو انبعت >1.0 (مثلاً 1.03) بيتكبّر العنصر حوالين مركزه مع الرفع.
  final double scale;

  const HoverLift({
    super.key,
    required this.child,
    this.liftPx = 6,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.scale = 1.0,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scaled = widget.scale != 1.0;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      transformAlignment: Alignment.center,
      transform: Matrix4.identity()
        ..translateByDouble(0.0, _hovering ? -widget.liftPx : 0.0, 0.0, 1.0)
        ..scaleByDouble(
          _hovering ? widget.scale : 1.0,
          _hovering ? widget.scale : 1.0,
          1.0,
          1.0,
        ),
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        boxShadow: _hovering
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: scaled ? 0.16 : 0.12),
                  blurRadius: scaled ? 26 : 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: widget.child,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: widget.onTap != null
          ? GestureDetector(onTap: widget.onTap, child: content)
          : content,
    );
  }
}
