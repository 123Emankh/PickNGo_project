// lib/services/location_service.dart
//
// نقطة الحصول الوحيدة على موقع المستخدم الحالي بكل التطبيق (زبون/سائق عام،
// مش تتبع الطلب الحي يلي إله socket خاص فيه). أي ميزة مستقبلية بدها موقع
// المستخدم (Grouped Delivery, Route Optimization, Heat Map, Delivery Zones)
// لازم تمر من هون بدل ما تكرر منطق الصلاحيات/الفشل الصامت بكل شاشة.
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  /// يحاول يجيب موقع المستخدم الحالي. بيرجع null بصمت (بدون رمي استثناء) لو:
  /// خدمة الموقع مطفية، الصلاحية مرفوضة، أو صار أي خطأ/timeout - الشاشات
  /// اللي بتستخدمه لازم تتعامل مع null كـ "فالباك بدون موقع"، مش كخطأ.
  static Future<LatLng?> getCurrentLocationSilently() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }
}
