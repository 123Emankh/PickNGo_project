// lib/screens/auth/role_selection_screen.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'signup_screen.dart';
import 'business_category_screen.dart';
import 'driver_type_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87), // لون زر الرجوع
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: ConstrainedBox(
                // 👈 تحديد حد أقصى للعرض لجعل الواجهة ملمومة ومنظمة في منتصف المتصفح
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Who Are You?',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose your account type to continue',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 32),
                    
                    // قائمة الخيارات بالإنجليزية بدلاً من الـ ListView لتجنب مشاكل الارتفاع داخل الـ Center
                    _RoleCard(
                      title: 'Customer',
                      subtitle: 'Order food, medicine, groceries, and more',
                      icon: Icons.shopping_bag_outlined,
                      role: 'Customer',
                    ),
                    const SizedBox(height: 16),
                    _RoleCard(
                      title: 'Store Owner / Business',
                      subtitle: 'Manage your restaurant, pharmacy, or retail store',
                      icon: Icons.storefront_outlined,
                      role: 'Restaurant',
                    ),
                    const SizedBox(height: 16),
                    _RoleCard(
                      title: 'Delivery Driver',
                      subtitle: 'Earn money by delivering orders with your vehicle',
                      icon: Icons.two_wheeler_outlined,
                      role: 'Driver',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String role;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Widget nextScreen;
        switch (role) {
          case 'Customer':
            nextScreen = const SignupScreen(role: 'Customer');
            break;
          case 'Restaurant':
            nextScreen = const BusinessCategoryScreen();
            break;
          case 'Driver':
            nextScreen = const DriverTypeScreen();
            break;
          default:
            nextScreen = SignupScreen(role: role);
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // الأيقونة محاطة بخلفية خضراء خفيفة متناسقة مع هوية التطبيق
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}