// lib/data/palestine_areas.dart
//
// نفس محتوى lib/palestineAreas.js بالريأكت بالظبط.

const List<String> palestineAreas = [
  'رام الله والبيرة',
  'نابلس',
  'الخليل',
  'جنين',
  'طولكرم',
  'قلقيلية',
  'بيت لحم',
  'أريحا',
  'سلفيت',
  'طوباس',
  'غزة',
  'خان يونس',
  'رفح',
  'دير البلح',
];

const String occupiedArea = 'داخل الأراضي المحتلة';

final List<String> deliveryAreas = [...palestineAreas, occupiedArea];

/// region + إحداثيات تقريبية لمركز كل مدينة، تُستخدم عشان نبعت
/// city/region/location_lat/location_lng للباك إند بدون ما نضيف
/// حقول جديدة للفورم (الباك إند بيطلبهم إلزاميًا بـ POST /api/stores).
const Map<String, (String region, double lat, double lng)> cityInfo = {
  'رام الله والبيرة': ('West Bank', 31.9038, 35.2034),
  'نابلس': ('West Bank', 32.2211, 35.2544),
  'الخليل': ('West Bank', 31.5326, 35.0998),
  'جنين': ('West Bank', 32.4611, 35.3006),
  'طولكرم': ('West Bank', 32.3108, 35.0286),
  'قلقيلية': ('West Bank', 32.1892, 34.9711),
  'بيت لحم': ('West Bank', 31.7054, 35.2024),
  'أريحا': ('West Bank', 31.8667, 35.4500),
  'سلفيت': ('West Bank', 32.0850, 35.1806),
  'طوباس': ('West Bank', 32.3213, 35.3689),
  'غزة': ('Gaza Strip', 31.5017, 34.4668),
  'خان يونس': ('Gaza Strip', 31.3469, 34.3029),
  'رفح': ('Gaza Strip', 31.2978, 34.2411),
  'دير البلح': ('Gaza Strip', 31.4181, 34.3517),
};
