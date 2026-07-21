// src/services/grouping/config.js
//
// ⚠️ هاد الملف ما عاد مصدر الحقيقة وقت التشغيل - groupingService.js صار
// يقرا القيم الحية من جدول system_settings (قابل للتعديل من لوحة الأدمن:
// Delivery Management → Grouped Delivery Settings). هاد الكائن هلق بس
// القيم الافتراضية المستخدمة لأول صف بالجدول (seed.js وadminController.js
// findOrCreate) - غيّري هون بس لو بدك تغيّري القيمة الافتراضية الأولية،
// مش لتغيير سلوك التجميع الفعلي (هاد من لوحة الأدمن).
module.exports = {
  GROUPED_DELIVERY_ENABLED: true,

  // أبعد مسافة (كم) بين متجرين لسا معقول نعتبرهم "بنفس المنطقة" لرحلة وحدة
  MAX_STORE_DISTANCE_KM: 0.1,

  // أبعد مسافة (كم) بين نقطتي توصيل لسا معقول نعتبرهم "نفس الوجهة"
  MAX_DROPOFF_DISTANCE_KM: 0.1,

  // أطول فارق زمني (دقايق) بين أول طلب بالمجموعة وطلب جديد لسا يقدر ينضم لها
  MAX_GROUPING_WINDOW_MIN: 10,

  MAX_ORDERS_PER_GROUP: 4,
  MAX_STORES_PER_TRIP: 4,

  // محجوز للمستقبل - ما في نظام تقييم سائقين حاليًا
  MINIMUM_DRIVER_RATING: 0,

  AUTO_ASSIGN_DRIVER: true,

  // ✅ ثوابت تقدير التوفير الحقيقي (getGroupingStats) - أرقام معقولة تقريبية،
  // مش مقاسة فعليًا (نفس فلسفة AVG_SPEED_KMH بـ utils/geo.js). بالدينار الأردني.
  FUEL_COST_PER_KM_JD: 0.6,
  CO2_KG_PER_KM: 0.15
};
