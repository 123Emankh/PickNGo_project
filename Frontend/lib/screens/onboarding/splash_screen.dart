// lib/screens/onboarding/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';
import 'onboarding_screen.dart';

const String kOnboardingSeenKey = 'seen_onboarding';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideNextScreen();
  }

  Future<void> _decideNextScreen() async {
    // ✅ نستنى شوي عشان الشعار يبين، وبنفس الوقت auth بيتهيأ بالخلفية
    final minSplashTime = Future.delayed(const Duration(milliseconds: 1200));

    // ✅ ننتظر لحد ما authProvider يخلص التهيئة (isInitialized = true)
    while (!ref.read(authProvider).isInitialized) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    await minSplashTime;
    if (!mounted) return;

    final authState = ref.read(authProvider);

    if (authState.isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool(kOnboardingSeenKey) ?? false;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            seenOnboarding ? const LoginScreen() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.delivery_dining,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'PickNGo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
