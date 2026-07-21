// src/utils/deliveryFee.js
//
// حساب رسم التوصيل الصحيح حسب مدينة/منطقة الزبون الفعلية مقابل مدينة/منطقة
// المتجر - بدون أي تخمين من إحداثيات GPS (الإحداثيات فقط للخرائط/تتبع
// السائق/حسابات مسافة مستقبلية، مش لتحديد التسعير). القيم متوافقة مع نفس
// الاتفاقية المستخدمة فعليًا بمسار إنشاء متجر حقيقي (راجع
// Frontend/lib/data/palestine_areas.dart و store_setup_screen.dart).

const REGION_WEST_BANK = 'West Bank';
const REGION_GAZA = 'Gaza Strip';
const REGION_ISRAEL = 'Israel';

/**
 * يحدد رسم التوصيل الصحيح لطلب معيّن حسب مدينة/منطقة توصيل الزبون مقابل
 * مدينة/منطقة المتجر - القواعد بالترتيب:
 *  1) الزبون بمنطقة "Israel" (الأراضي المحتلة) -> delivery_fee_occupied_areas
 *     (بغض النظر عن مدينة/منطقة المتجر - هاد التسعير الأعلى دايمًا أولوية)
 *  2) نفس مدينة المتجر بالظبط -> delivery_fee_inside_city
 *  3) غير هيك (مدينة تانية، بس ضمن نفس منظومة الضفة/غزة) -> delivery_fee_outside_city
 *
 * @param {object} store - كائن Restaurant (لازم يكون فيه city, region,
 *   delivery_fee_inside_city, delivery_fee_outside_city, delivery_fee_occupied_areas)
 * @param {string} deliveryCity - مدينة توصيل الزبون (من قائمة palestineAreas الثابتة)
 * @param {string} deliveryRegion - 'West Bank' | 'Gaza Strip' | 'Israel'
 * @returns {number}
 */
function calculateDeliveryFee(store, deliveryCity, deliveryRegion) {
  if (deliveryRegion === REGION_ISRAEL) {
    return parseFloat(store.delivery_fee_occupied_areas);
  }

  if (deliveryCity === store.city && deliveryRegion === store.region) {
    return parseFloat(store.delivery_fee_inside_city);
  }

  // ✅ أي حالة تانية (مدينة/منطقة مختلفة عن المتجر، ما دام مش "Israel") -
  // بما فيها الحالة النادرة يلي المتجر نفسه بمنطقة غير منطقة الزبون
  return parseFloat(store.delivery_fee_outside_city);
}

module.exports = {
  calculateDeliveryFee,
  REGION_WEST_BANK,
  REGION_GAZA,
  REGION_ISRAEL,
};
