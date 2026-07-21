// lib/providers/location_provider.dart
//
// مصدر الحقيقة الوحيد لموقع المستخدم الحالي بكل الشاشات (Home/Stores/Store
// Detail، ولاحقًا أي ميزة هدفها Grouped Delivery/Route Optimization/Heat
// Map/Delivery Zones). FutureProvider عادي = يتحسب مرة وحدة لحد ما حدا
// يعمل invalidate (نفس فلسفة "نسأل عن الموقع مرة واحدة بالجلسة" يلي كانت
// موجودة أصلًا بـ home_screen، بس هلق موحّدة ومشتركة).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';

final userLocationProvider = FutureProvider<LatLng?>((ref) {
  return LocationService.getCurrentLocationSilently();
});
