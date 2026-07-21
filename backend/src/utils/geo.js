// src/utils/geo.js
// حساب المسافة/وقت التوصيل التقديري وحالة "مفتوح الآن" اعتمادًا على إحداثيات/أوقات المتجر.
const EARTH_RADIUS_KM = 6371;

function haversineKm(lat1, lng1, lat2, lng2) {
  if ([lat1, lng1, lat2, lng2].some((v) => v === null || v === undefined || isNaN(v))) {
    return null;
  }
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ثوابت تقدير الوقت - مشتركة بين estimateDeliveryRange (شارة "20-35 min" على
// بطاقة المتجر) و estimateStageDurations (تفاصيل كل مرحلة بشاشة التتبع)
const PREP_TIME_MIN = 10; // وقت تحضير الطلب الثابت
const AVG_SPEED_KMH = 25; // سرعة توصيل متوسطة داخل المدينة
const PICKUP_TRANSIT_MIN = 5; // وقت تقديري لاستلام السائق الطلب من المتجر بعد ما يصير Ready

// ✅ prepTimeMin اختياري - لو المتجر محدد وقت تحضير خاص فيه (restaurants.prep_time_minutes)
// منستخدمه بدل الثابت العام، غير هيك نفس السلوك القديم تمامًا
function estimateDeliveryRange(distanceKm, prepTimeMin = PREP_TIME_MIN) {
  if (distanceKm === null || distanceKm === undefined) return '20-35 min';
  const travelMin = (distanceKm / AVG_SPEED_KMH) * 60;
  const low = Math.max(10, Math.round(prepTimeMin + travelMin - 5));
  const high = Math.round(prepTimeMin + travelMin + 10);
  return `${low}-${high} min`;
}

// وقت تقديري (بالدقايق) لكل مرحلة لسا ما وصلتها - يستخدمها getOrderTracking
// لعرض "الوقت المتوقع" لكل مرحلة قدام السائق/الزبون. مش دقيق 100% (ما في
// بيانات تاريخية كافية لحساب متوسط حقيقي لسا)، بس تقدير معقول وموحّد.
function estimateStageDurations(distanceKm, prepTimeMin = PREP_TIME_MIN) {
  const travelMin = distanceKm !== null && distanceKm !== undefined
    ? Math.round((distanceKm / AVG_SPEED_KMH) * 60)
    : 15;
  return {
    preparing: prepTimeMin,
    pickup: PICKUP_TRANSIT_MIN,
    delivery: Math.max(5, travelMin)
  };
}

function isOpenNow(openingTime, closingTime, isOpenFlag) {
  if (isOpenFlag === false) return false; // تعطيل يدوي من صاحب المتجر يغلب أي شي
  if (!openingTime || !closingTime) return isOpenFlag !== false;

  const now = new Date();
  const [oh, om] = openingTime.split(':').map(Number);
  const [ch, cm] = closingTime.split(':').map(Number);
  const nowMin = now.getHours() * 60 + now.getMinutes();
  const openMin = oh * 60 + om;
  const closeMin = ch * 60 + cm;

  if (closeMin === openMin) return true; // مفتوح 24 ساعة
  if (closeMin > openMin) return nowMin >= openMin && nowMin < closeMin;
  // حالة التوقيت اللي يعدي منتصف الليل (مثلاً يفتح 20:00 ويسكر 02:00)
  return nowMin >= openMin || nowMin < closeMin;
}

module.exports = { haversineKm, estimateDeliveryRange, estimateStageDurations, isOpenNow, PICKUP_TRANSIT_MIN, AVG_SPEED_KMH };
