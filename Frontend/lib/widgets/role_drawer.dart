// lib/widgets/role_drawer.dart
//
// شاشات مشتركة بين أكتر من دور (Orders/Profile/Notifications) بتحتاج
// تعرض الـ Drawer الصحيح حسب دور المستخدم الحالي - دالة وحدة بدل ما نكرر
// نفس الـ ternary بكل شاشة.

import 'package:flutter/material.dart';
import 'admin_drawer.dart';
import 'customer_drawer.dart';
import 'driver_drawer.dart';
import 'vendor_drawer.dart';

Widget? roleDrawerFor(String? role) {
  switch (role) {
    case 'Customer':
      return const CustomerDrawer();
    case 'Restaurant':
      return const VendorDrawer();
    case 'Driver':
      return const DriverDrawer();
    case 'Admin':
      return const AdminDrawer();
    default:
      return null;
  }
}
