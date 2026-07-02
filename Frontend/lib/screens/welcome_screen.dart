// lib/screens/welcome_screen.dart
import 'package:flutter/material.dart';
import 'auth_screen.dart'; // لاستدعاء صفحة التسجيل عند الضغط على الزر

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // اللون الأخضر الأساسي الخاص بهوية تطبيقكِ
    const primaryColor = Color(0xFF006D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF1), // الخلفية الفاتحة المعتمدة للتطبيق
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // 1. الشعار والاسم في المنتصف العلوي
              Column(
                children: [
                  // محاولة عرض اللوجو القديم، وإذا لم يجده يعرض أيقونة بديلة لحين عمل الـ pull
                  Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.local_shipping, size: 100, color: primaryColor);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'PickNGo',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your Smart Multi-Vendor Delivery Partner',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              // 2. رسالة ترحيبية ومميزات سريعة
              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFFEFF3EB)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        'أهلاً بك في PickNGo 👋',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'منصة ذكية متكاملة تجمع بين العملاء، المتاجر، ومناديب التوصيل في القاهرة لتوفير تجربة طلب وشحن فائقة السرعة.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. أزرار التحكم السفلية للانتقال
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // الانتقال إلى صفحة التسجيل والدخول
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AuthScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Get Started / ابدأ الآن',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}