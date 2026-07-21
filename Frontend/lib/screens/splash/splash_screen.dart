// lib/screens/splash/splash_screen.dart
//
// شاشة تحميل أول ما يفتح التطبيق: خلفية خضراء بلون البراند، لوجو PickNGo
// بالنص (نفس شكل الأيقونة المستخدمة بـ navbar شاشة Landing)، وتحتها مؤشر
// تحميل مرسوم يدويًا (شاحنة توصيل وعجلاتها تلف باستمرار). بعد مدة قصيرة
// بتنتقل تلقائيًا لـ LandingScreen.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_themes.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_notifier.dart';
import '../landing/landing_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color brandColor = AppColors.brand;

  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..forward();

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _entranceController,
    curve: Curves.easeOutBack,
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _entranceController,
    curve: const Interval(0, 0.7, curve: Curves.easeOut),
  );

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    // ✅ Timer قابل للإلغاء (مش Future.delayed خام) - نفس نمط باقي التايمرز
    // بالمشروع (app_showcase_phone_widget/promo_banner_carousel)، عشان لو
    // الشاشة انشالت قبل ما تخلص المدة (تنقّل يدوي مبكر، أو تفكيك بتيست) ينلغى
    // فورًا بدل ما يضل معلّق بالخلفية لحد ما ينطلق لحاله.
    _navigationTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LandingScreen()),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeNotifierProvider);
    return Scaffold(
      backgroundColor: brandColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.local_shipping_rounded,
                          color: brandColor,
                          size: 52,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        AppLocalizations.t(locale, 'app_name'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              const _DeliveryLoadingIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ مؤشر تحميل مخصص (بدون أي صورة/asset): شاحنة توصيل بسيطة مرسومة يدويًا
// (CustomPaint) وعجلاتها بتلف باستمرار عبر AnimationController.
class _DeliveryLoadingIndicator extends StatefulWidget {
  static const Color color = Colors.white;
  const _DeliveryLoadingIndicator();

  @override
  State<_DeliveryLoadingIndicator> createState() => _DeliveryLoadingIndicatorState();
}

class _DeliveryLoadingIndicatorState extends State<_DeliveryLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wheelController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat();

  @override
  void dispose() {
    _wheelController.dispose();
    super.dispose();
  }

  Widget _spinningWheel(double size) {
    return AnimatedBuilder(
      animation: _wheelController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _wheelController.value * 2 * math.pi,
          child: child,
        );
      },
      child: CustomPaint(size: Size(size, size), painter: _WheelPainter(color: _DeliveryLoadingIndicator.color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const wheelSize = 22.0;
    return SizedBox(
      width: 116,
      height: 62,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(106, 40),
              painter: _TruckBodyPainter(color: _DeliveryLoadingIndicator.color),
            ),
          ),
          Positioned(bottom: 0, left: 16, child: _spinningWheel(wheelSize)),
          Positioned(bottom: 0, right: 16, child: _spinningWheel(wheelSize)),
        ],
      ),
    );
  }
}

class _TruckBodyPainter extends CustomPainter {
  final Color color;
  _TruckBodyPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // صندوق البضاعة (الجزء الخلفي الأعرض)
    final cargoRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 2, size.width * 0.58, size.height - 6),
      const Radius.circular(5),
    );
    canvas.drawRRect(cargoRect, paint);

    // المقصورة (الجزء الأمامي المائل)
    final cabPath = Path()
      ..moveTo(size.width * 0.58, size.height - 4)
      ..lineTo(size.width * 0.58, size.height * 0.4)
      ..lineTo(size.width * 0.78, size.height * 0.4)
      ..lineTo(size.width, size.height * 0.68)
      ..lineTo(size.width, size.height - 4)
      ..close();
    canvas.drawPath(cabPath, paint);

    // نافذة المقصورة (تفصيلة بسيطة بلون الخلفية عشان تبيّن الشكل)
    final windowPaint = Paint()..color = color.withValues(alpha: 0.35);
    final windowPath = Path()
      ..moveTo(size.width * 0.66, size.height * 0.48)
      ..lineTo(size.width * 0.78, size.height * 0.48)
      ..lineTo(size.width * 0.9, size.height * 0.68)
      ..lineTo(size.width * 0.66, size.height * 0.68)
      ..close();
    canvas.drawPath(windowPath, windowPaint);
  }

  @override
  bool shouldRepaint(covariant _TruckBodyPainter oldDelegate) => oldDelegate.color != color;
}

class _WheelPainter extends CustomPainter {
  final Color color;
  _WheelPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final rimPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(center, radius - 1.2, rimPaint);

    final spokePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final offset = Offset(math.cos(angle), math.sin(angle)) * (radius - 3);
      canvas.drawLine(center, center + offset, spokePaint);
    }

    canvas.drawCircle(center, 2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => oldDelegate.color != color;
}
