// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 👈 1. أضيفي هذا السطر لاستيراد المكتبة
import 'screens/auth_screen.dart'; 
import 'screens/welcome_screen.dart';
import 'screens/home/home_screen.dart';

void main() {
  // 👈 2. غلّفي الـ MyApp بـ ProviderScope هنا
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PickNGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF006D32),
        useMaterial3: true,
      ),
      home: const HomeScreen(), 
    );
  }
}