// lib/screens/auth/driver_type_screen.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'signup_screen.dart';

class DriverTypeScreen extends StatelessWidget {
  const DriverTypeScreen({super.key});

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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: ConstrainedBox(
                // 👈 حماية الواجهة من التمدد على الـ Web وجعلها متناسقة
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Type',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select the category that best describes your delivery method',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 32),

                    // 1. خيار الموتور (Motorcycle)
                    _buildVehicleCard(
                      context: context,
                      title: 'Motorcycle',
                      subtitle: 'Personal motorcycle or scooter delivery',
                      icon: Icons.motorcycle_outlined,
                      vehicleValue: 'Motorcycle',
                    ),
                    const SizedBox(height: 16),

                    // 2. خيار السيارة/الكابينة (Car / Cab)
                    _buildVehicleCard(
                      context: context,
                      title: 'Car / Cab',
                      subtitle: 'Personal car or private cab delivery',
                      icon: Icons.directions_car_filled_outlined,
                      vehicleValue: 'Car',
                    ),
                    const SizedBox(height: 16),

                    // 3. خيار شركة توصيل (Delivery Company)
                    _buildVehicleCard(
                      context: context,
                      title: 'Delivery Company',
                      subtitle: 'Manage a fleet of delivery drivers',
                      icon: Icons.local_shipping_outlined,
                      vehicleValue: 'Fleet / Company',
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

  Widget _buildVehicleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required String vehicleValue,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SignupScreen(
              role: 'Driver',
              businessType: vehicleValue, // تمرير نوع المركبة كـ businessType لشاشة التسجيل
            ),
          ),
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
            // الأيقونة محاطة بخلفية خضراء خفيفة متناسقة
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