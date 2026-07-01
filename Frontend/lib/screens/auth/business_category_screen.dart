// lib/screens/auth/business_category_screen.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'signup_screen.dart';

class BusinessCategoryScreen extends StatelessWidget {
  const BusinessCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              // 👈 لمنع تمدد عناصر الـ Grid بشكل مشوه على شاشات المتصفح الكبيرة
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Business Category',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select the category that best describes your store or commercial activity',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.0, // جعل الكروت مربعة ومثالية للتصميم العصري
                      physics: const BouncingScrollPhysics(),
                      children: const [
                        _CategoryCard(
                          title: 'Restaurant',
                          icon: Icons.restaurant_outlined,
                          businessType: 'Restaurant',
                        ),
                        _CategoryCard(
                          title: 'Pharmacy',
                          icon: Icons.local_pharmacy_outlined,
                          businessType: 'Pharmacy',
                        ),
                        _CategoryCard(
                          title: 'Furniture',
                          icon: Icons.chair_outlined,
                          businessType: 'Furniture',
                        ),
                        _CategoryCard(
                          title: 'Other Business',
                          icon: Icons.category_outlined,
                          businessType: 'Other',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String businessType;

  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.businessType,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SignupScreen(
              role: 'Restaurant', // ربط الفئة بدور Restaurant في الباكند بناءً على بنيتكِ الأساسية
              businessType: businessType,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // أيقونة الفئة بتصميم دائري بلون البراند المميز للتطبيق
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}