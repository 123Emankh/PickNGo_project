// src/services/assignment/scoringEngine.js
//
// يحسب ويرتّب مرشحين (سائقين) لطلب معيّن: فلترة صارمة (hard filters) أولًا
// (لازم تنطبق كلها وإلا استبعاد كامل)، وبعدين تسجيل نقاط موزون (soft
// factors من factors.js) لترتيب اللي عدّوا الفلترة. ما بيلمس driver_id أو
// أي حالة - بس بيرجّع ترتيب، القرار الفعلي (عرض/تعيين) لـ assignmentService.
const { Op } = require('sequelize');
const { User, Order } = require('../../models');
const { haversineKm } = require('../../utils/geo');
const { getEffectiveStatus } = require('../driverStatusService');
const { SCORING_FACTORS, MAX_ASSIGNMENT_RADIUS_KM, MAX_CONCURRENT_ACTIVE_ORDERS } = require('./factors');

const ACTIVE_ORDER_STATUSES = { [Op.notIn]: ['Delivered', 'Cancelled', 'Refunded'] };

// ✅ سائق "أهل" مبدئيًا (قبل حتى نحسب مسافة/حمل): سائق حقيقي (مش حساب
// شركة)، حسابه معتمد ومفعّل. باقي الفلترة (حالة Available الفعلية، مسافة،
// نوع مركبة، حمل حالي، عرض تاني معلّق) بتصير لكل مرشح بعد ما نجيب بياناته.
async function fetchBaseCandidateDrivers() {
  return User.findAll({
    where: {
      role: 'Driver',
      // ✅ باج حقيقي كان موجود: `business_type: { [Op.ne]: ... }` بلغة SQL
      // بترجم `<>` - ومقارنة NULL بأي إشي بـ SQL نتيجتها NULL (مش true)، يعني
      // أي سائق حسابه `business_type` فاضي (NULL) كان يُستبعد تلقائيًا وصامت
      // من محرك التعيين الذكي بالكامل، للأبد، بدون أي خطأ أو تحذير - لازم
      // نصرّح صراحة إنه NULL مقبول (سائق فردي عادي) وبس 'Fleet / Company'
      // (حساب شركة) هو المستبعد فعليًا.
      [Op.or]: [{ business_type: { [Op.ne]: 'Fleet / Company' } }, { business_type: null }],
      is_active: true,
      status: 'Approved'
    }
  });
}

async function buildCandidateContext(driver, order) {
  const [activeOrders, hasOtherPendingOffer] = await Promise.all([
    Order.count({ where: { driver_id: driver.user_id, status: ACTIVE_ORDER_STATUSES } }),
    Order.count({
      where: {
        offered_driver_id: driver.user_id,
        offer_expires_at: { [Op.gt]: new Date() },
        order_id: { [Op.ne]: order.order_id }
      }
    })
  ]);

  const distanceKm = haversineKm(
    driver.current_lat !== null ? parseFloat(driver.current_lat) : null,
    driver.current_lng !== null ? parseFloat(driver.current_lng) : null,
    order.store ? parseFloat(order.store.location_lat) : null,
    order.store ? parseFloat(order.store.location_lng) : null
  );

  return { driver, distanceKm, activeOrders, hasOtherPendingOffer: hasOtherPendingOffer > 0 };
}

// ✅ كل الشروط اللي لازم تنطبق كلها وإلا استبعاد تام - ما إلها علاقة
// بالتسجيل/الترتيب (سائق يعدّي هون ممكن لسا يترتب أخير لو نقاطه ضعيفة)
function passesHardFilters(candidate, order, excludeDriverIds) {
  const { driver, distanceKm, activeOrders, hasOtherPendingOffer } = candidate;

  if (excludeDriverIds.includes(driver.user_id)) return false;
  if (getEffectiveStatus(driver) !== 'Available') return false;
  if (hasOtherPendingOffer) return false;
  if (activeOrders >= MAX_CONCURRENT_ACTIVE_ORDERS) return false;
  if (distanceKm === null || distanceKm > MAX_ASSIGNMENT_RADIUS_KM) return false;
  if (order.required_vehicle_type && driver.business_type !== order.required_vehicle_type) return false;

  return true;
}

// ✅ معدل موزون على العوامل "القابلة للتطبيق" بس (اللي رجّعت رقم مش null) -
// عشان عامل غير منطبق (زي شركة مفضّلة لطلب ما عنده شركة) ما يخفّض نقاط
// السائق ظلمًا، وما يرفعها كمان.
function scoreCandidate(candidate, order) {
  const breakdown = [];
  let weightedSum = 0;
  let weightTotal = 0;

  for (const factor of SCORING_FACTORS) {
    const value = factor.compute(candidate, order);
    if (value === null || value === undefined) continue;
    weightedSum += value * factor.weight;
    weightTotal += factor.weight;
    breakdown.push({ factor: factor.name, score: Math.round(value * 100) / 100, weight: factor.weight });
  }

  const score = weightTotal > 0 ? weightedSum / weightTotal : 0;
  return { score: Math.round(score * 1000) / 1000, breakdown };
}

/**
 * يرجّع مرشحين مؤهلين لطلب، مرتّبين من الأفضل للأسوأ.
 * ترتيب: النقاط الموزونة تنازليًا، وعند التعادل (فرق أقل من EPSILON) -
 * الأقل حمل حالي، وبعدين الأقرب مسافة (بالضبط زي المطلوب: "الأقل عددًا
 * بالطلبات الحالية ثم الأقرب").
 * @param {object} order - لازم يكون محمّل مع include: [{model: Restaurant, as: 'store'}]
 * @param {number[]} excludeDriverIds - سائقين تم تجربتهم/رفضهم بهاد الدورة، ما نعيد عرضهم
 */
async function rankCandidates(order, excludeDriverIds = []) {
  const drivers = await fetchBaseCandidateDrivers();
  const contexts = await Promise.all(drivers.map((driver) => buildCandidateContext(driver, order)));

  const eligible = contexts.filter((c) => passesHardFilters(c, order, excludeDriverIds));

  const ranked = eligible.map((candidate) => {
    const { score, breakdown } = scoreCandidate(candidate, order);
    return { ...candidate, score, breakdown };
  });

  const EPSILON = 0.02;
  ranked.sort((a, b) => {
    if (Math.abs(a.score - b.score) > EPSILON) return b.score - a.score;
    if (a.activeOrders !== b.activeOrders) return a.activeOrders - b.activeOrders;
    return (a.distanceKm ?? Infinity) - (b.distanceKm ?? Infinity);
  });

  return ranked;
}

module.exports = { rankCandidates, scoreCandidate, passesHardFilters };
