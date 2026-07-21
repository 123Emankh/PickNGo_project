// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash/splash_screen.dart'; // 👈 شاشة التحميل الأولى
import 'core/theme/theme_notifier.dart';
import 'core/theme/app_themes.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'core/i18n/locale_notifier.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/auth_provider.dart';
import 'widgets/chat/chat_floating_button.dart';
import 'core/navigation/root_navigator.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    // Force desktop Windows apps to stay in Light mode per user request.
    final bool isWindowsDesktop =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final effectiveThemeMode = isWindowsDesktop ? ThemeMode.light : themeMode;

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'PickNGo',
      debugShowCheckedModeBanner: false,
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: effectiveThemeMode,
      // Localization
      locale: ref.watch(localeNotifierProvider),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
      // ✅ تكبير بسيط وموحّد لكل نصوص التطبيق (كتير شاشات كانت بتستخدم أحجام
      // خط صغيرة يدويًا) بدون ما نلمس تفضيلات سهولة الوصول لو المستخدم كبّرها أكتر.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final clampedScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 1.12,
          maxScaleFactor: 1.6,
        );
        // ✅ زر المساعد الذكي العائم: هنا هو الحل الوحيد اللي بيغطي كل شاشات
        // الأدوار الأربعة *و* الشاشات المدفوعة فوقها (سلة/تتبع/...) بنقطة
        // حقن واحدة - ما في "shell" مشترك بالتطبيق (كل دور شاشته الجذرية
        // Scaffold مستقل - راجع home_screen/driver_home_screen/
        // business_dashboard_screen/admin_dashboard_screen).
        final isAuthenticated = ref.watch(authProvider).isAuthenticated;
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedScaler),
          child: Stack(
            children: [
              child!,
              if (isAuthenticated)
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: SafeArea(child: const ChatFloatingButton()),
                ),
            ],
          ),
        );
      },
      home: const SplashScreen(), // 👈 نقطة الدخول: شاشة تحميل ثم Landing
    );
  }
}
