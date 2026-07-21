// lib/widgets/chat/typing_indicator.dart
//
// ثلاث نقاط متحركة بالتتابع (ظهور/اختفاء) لحد ما يجهز رد المساعد الذكي -
// نفس أسلوب fade_slide_in.dart: AnimationController مدمج بفلاتر بدون أي
// مكتبة رسوم متحركة جديدة.
import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  final Color color;

  const TypingIndicator({super.key, required this.color});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _dotOpacity(int index) {
    // ✅ كل نقطة بتبدأ دورتها بتأخير بسيط عن التانية - تأثير "موجة"
    final shifted = (_controller.value + (index * 0.2)) % 1.0;
    return 0.3 + 0.7 * (0.5 - (shifted - 0.5).abs()) * 2;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: _dotOpacity(i).clamp(0.3, 1.0),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
