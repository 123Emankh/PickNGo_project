// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/auth_screen.dart'; // 👈 استدعاء ملف الواجهة المخصص

void main() {
  runApp(const PickNGoApp());
}

class PickNGoApp extends StatelessWidget {
  const PickNGoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PickNGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF006D32),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006D32),
          primary: const Color(0xFF006D32),
          background: const Color(0xFFF7FBF1),
        ),
      ),
      home: const AuthScreen(), // 👈 الشاشة قادمة من الملف المنفصل بسلاسة
    );
  }
}