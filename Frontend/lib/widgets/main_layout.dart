// lib/widgets/main_layout.dart
//
// الغلاف المشترك لكل الشاشات الرئيسية بعد تسجيل الدخول (Home/Orders/Cart/
// Checkout/Loyalty/Favorites/Stores): Scaffold + LayoutBuilder + Sidebar
// (ويب) + AppHeader (أو GuestTopBar للزوّار) بمكان واحد بدل ما تعيد كل
// شاشة كتابة نفس الهيكل. المحتوى الفعلي لكل شاشة بيجي عبر [builder].
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'app_header.dart';
import 'customer_sidebar.dart';
import 'guest_top_bar.dart';
import 'role_drawer.dart';

class MainLayout extends ConsumerWidget {
  final Widget Function(BuildContext context, bool isWeb, double padding, double width) builder;
  final bool isGuest;
  // ✅ id بند الـ Sidebar اللي لازم يظهر "نشط" لهاد الشاشة (راجع
  // CustomerSidebar._buildNavTile) - مثلاً 'home' أو 'categories'. null (الافتراضي)
  // يعني بدون تمييز، نفس سلوك باقي الشاشات اليوم.
  final String? activeNavId;

  const MainLayout({
    super.key,
    required this.builder,
    this.isGuest = false,
    this.activeNavId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = isGuest ? null : ref.watch(authProvider).user?.role;
    // ✅ نفس شرط orders_screen.dart الحالي بالضبط (الشاشة الوحيدة المشتركة
    // بين أدوار متعددة) - باقي الشاشات المحوّلة لـ MainLayout دورها دايمًا
    // 'Customer' أصلاً، فالنتيجة نفسها بدون داعي لتمييز خاص.
    final showSidebar = !isGuest && role == 'Customer';

    return Scaffold(
      drawer: isGuest ? null : roleDrawerFor(role),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth > 900;
          final padding = isWeb ? constraints.maxWidth * 0.08 : 16.0;
          return Row(
            children: [
              if (isWeb && showSidebar) CustomerSidebar(activeNavId: activeNavId),
              Expanded(
                child: Column(
                  children: [
                    isGuest
                        ? GuestTopBar(padding: padding, isWeb: isWeb)
                        : AppHeader(isWeb: isWeb, padding: padding),
                    Expanded(child: builder(context, isWeb, padding, constraints.maxWidth)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
