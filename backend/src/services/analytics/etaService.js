// src/services/analytics/etaService.js
//
// تقدير وقت التوصيل (ETA) - معادلة إحصائية بسيطة (لا Machine Learning):
// المسافة (Haversine) + متوسطات فعلية من status_history لآخر طلبات مسلّمة
// لنفس المتجر (تحل محل الثوابت الافتراضية لو توفر عدد عينات كافٍ) + تحميل
// السائق الحالي (عدد طلباته النشطة الأخرى) + حالة الطلب الحالية (تحدد
// المراحل المتبقية). لا جدول جديد - كل شي محسوب من orders.status_history.
const { Op } = require('sequelize');
const { Order } = require('../../models');
const { estimateStageDurations } = require('../../utils/geo');

const HISTORY_SAMPLE_SIZE = 30; // آخر N طلب مسلّم لنفس المتجر - كافي لمتوسط معقول بدون استعلام ثقيل
const MIN_SAMPLES_FOR_HISTORY = 3; // أقل عدد عينات نثق فيها قبل ما نستبدل الثابت الافتراضي بمتوسط حقيقي
const PER_ACTIVE_ORDER_DELAY_MIN = 6; // تأخير تقديري لكل طلب إضافي شغال عليه نفس السائق حاليًا بالتوازي
const MAX_ACTIVE_ORDER_DELAY_MIN = 18; // سقف التأخير - ما منضخّمه لأكثر من ~3 طلبات مزاحمة

const ORDER_STAGES = ['Pending', 'Confirmed', 'Preparing', 'Ready', 'PickedUp', 'Delivered'];
const DRIVER_ACTIVE_STATUSES = ['Confirmed', 'Preparing', 'Ready', 'PickedUp'];

function minutesBetween(fromAt, toAt) {
  if (!fromAt || !toAt) return null;
  const diff = (new Date(toAt) - new Date(fromAt)) / 60000;
  return diff > 0 ? diff : null;
}

// ✅ أول ظهور لكل حالة بسجل status_history - كافي لحساب مدة كل مرحلة
// (Confirmed→Ready = تحضير، Ready→PickedUp = استلام، PickedUp→Delivered = توصيل)
function extractStageDurationsFromHistory(history) {
  const at = {};
  for (const entry of history || []) {
    if (!at[entry.status]) at[entry.status] = entry.at;
  }
  return {
    preparing: minutesBetween(at.Confirmed, at.Ready),
    pickup: minutesBetween(at.Ready, at.PickedUp),
    delivery: minutesBetween(at.PickedUp, at.Delivered)
  };
}

// ✅ متوسط حقيقي لكل مرحلة من آخر طلبات مسلّمة فعليًا لنفس المتجر - يحل محل
// الثوابت الافتراضية بالكامل لو توفر عدد عينات كافٍ (MIN_SAMPLES_FOR_HISTORY)،
// وإلا null (يرجع الاستخدام لـ estimateStageDurations الثابت كـ fallback)
async function getHistoricalStageAverages(restaurantId) {
  const orders = await Order.findAll({
    where: { restaurant_id: restaurantId, status: 'Delivered' },
    attributes: ['status_history'],
    order: [['completed_time', 'DESC']],
    limit: HISTORY_SAMPLE_SIZE
  });

  const samples = { preparing: [], pickup: [], delivery: [] };
  // ✅ بعض الطلبات المسلّمة (خصوصًا قديمة/مزروعة يدويًا) ممكن يكون
  // status_history فيها null أو ناقص - ما بتساهم بأي متوسط، فما لازم تُحسب
  // ضمن "عدد العينات" المعروض للمستخدم (كان bug: orders.length يعدّها حتى
  // لو ما ساهمت بشي، فيضخّم الثقة المعروضة زورًا)
  let usableOrders = 0;
  for (const order of orders) {
    const durations = extractStageDurationsFromHistory(order.status_history);
    let contributed = false;
    for (const stage of Object.keys(samples)) {
      if (durations[stage] !== null) {
        samples[stage].push(durations[stage]);
        contributed = true;
      }
    }
    if (contributed) usableOrders += 1;
  }

  const avg = (arr) => (arr.length >= MIN_SAMPLES_FOR_HISTORY ? arr.reduce((a, b) => a + b, 0) / arr.length : null);
  return {
    preparing: avg(samples.preparing),
    pickup: avg(samples.pickup),
    delivery: avg(samples.delivery),
    sample_size: usableOrders
  };
}

// ✅ عدد الطلبات "النشطة" الحالية لنفس السائق (غير الطلب الحالي) - كل ما زاد
// كل ما المتوقع يتأخر أكتر (السائق مشغول بطلبات تانية بالتوازي)
async function getDriverActiveLoad(driverId, excludeOrderId) {
  if (!driverId) return 0;
  return Order.count({
    where: {
      driver_id: driverId,
      order_id: { [Op.ne]: excludeOrderId },
      status: { [Op.in]: DRIVER_ACTIVE_STATUSES }
    }
  });
}

// ===========================
// 📌 نقطة الدخول الوحيدة: تقدير الوقت المتبقي لتسليم طلب معيّن
// order: نسخة Order محمّلة (لازم تتضمن store لو متاح - نفس اللي getOrderTracking
// عندها أصلًا)، distanceKm: مسافة المتجر↔التوصيل (Haversine - محسوبة مسبقًا بالكونترولر)
// ===========================
async function predictOrderEta(order, distanceKm) {
  if (['Delivered', 'Cancelled', 'Refunded'].includes(order.status)) return null;

  const [historical, activeLoad] = await Promise.all([
    getHistoricalStageAverages(order.restaurant_id),
    getDriverActiveLoad(order.driver_id || order.offered_driver_id, order.order_id)
  ]);

  const fallback = estimateStageDurations(distanceKm, order.store ? order.store.prep_time_minutes : undefined);
  const stageDurations = {
    preparing: historical.preparing ?? fallback.preparing,
    pickup: historical.pickup ?? fallback.pickup,
    delivery: historical.delivery ?? fallback.delivery
  };

  const loadDelayMin = Math.min(activeLoad * PER_ACTIVE_ORDER_DELAY_MIN, MAX_ACTIVE_ORDER_DELAY_MIN);

  const durationByStage = { Preparing: stageDurations.preparing, Ready: stageDurations.pickup, PickedUp: stageDurations.delivery };
  const currentIndex = ORDER_STAGES.indexOf(order.status);
  const remainingStages = currentIndex >= 0 ? ORDER_STAGES.slice(currentIndex) : ORDER_STAGES;
  const baseRemainingMin = remainingStages.reduce((sum, stage) => sum + (durationByStage[stage] || 0), 0);
  const totalRemainingMin = Math.max(1, Math.round(baseRemainingMin + loadDelayMin));

  return {
    stage_durations_min: {
      preparing: Math.round(stageDurations.preparing),
      pickup: Math.round(stageDurations.pickup),
      delivery: Math.round(stageDurations.delivery)
    },
    driver_active_load: activeLoad,
    load_delay_min: Math.round(loadDelayMin),
    total_remaining_min: totalRemainingMin,
    estimated_delivery_at: new Date(Date.now() + totalRemainingMin * 60 * 1000),
    based_on_history: historical.preparing !== null || historical.pickup !== null || historical.delivery !== null,
    history_sample_size: historical.sample_size
  };
}

module.exports = { predictOrderEta, getHistoricalStageAverages, getDriverActiveLoad };
