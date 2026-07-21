// src/services/analytics/driverAnalyticsService.js
//
// تحليلات أداء السائق - كلها محسوبة من بيانات موجودة أصلًا (orders.status_history
// وorders/delivery_groups.offer_history) بدون أي جدول جديد. مصمّمة لحساب كل
// السائقين دفعة وحدة (استعلامين اثنين بس بغض النظر عن العدد) عشان تُستخدم
// بكفاءة من شاشة "أدائي" (سائق واحد) ومن لوحة تحليلات الأدمن (كل السائقين) سوا.
const { Op } = require('sequelize');
const { Order, DeliveryGroup } = require('../../models');

const TERMINAL_DRIVER_STATUSES = ['Delivered', 'Cancelled', 'Refunded'];

function round2(n) {
  return Math.round(n * 100) / 100;
}

function minutesBetween(fromAt, toAt) {
  if (!fromAt || !toAt) return null;
  const diff = (new Date(toAt) - new Date(fromAt)) / 60000;
  return diff > 0 ? diff : null;
}

// ✅ أول ظهور لـ PickedUp وDelivered بسجل الحالة - مدة التوصيل الفعلية لطلب واحد
function deliveryMinutesFromHistory(history) {
  const at = {};
  for (const entry of history || []) {
    if (!at[entry.status]) at[entry.status] = entry.at;
  }
  return minutesBetween(at.PickedUp, at.Delivered);
}

// ===========================
// 📌 إحصاءات عروض التعيين الذكي (Smart Assignment) لكل سائق - مبنية من
// offer_history (فردي + مجمّع) لكل الطلبات/المجموعات يلي عندها سجل. استعلام
// واحد لكل جدول بغض النظر عن عدد السائقين (Map<driver_id, counts>).
// ===========================
async function fetchOfferStatsByDriver() {
  const [orderRows, groupRows] = await Promise.all([
    Order.findAll({ where: { offer_history: { [Op.ne]: null } }, attributes: ['offer_history'], raw: true }),
    DeliveryGroup.findAll({ where: { offer_history: { [Op.ne]: null } }, attributes: ['offer_history'], raw: true })
  ]);

  const map = new Map();
  const bump = (driverId, key) => {
    if (!driverId) return;
    if (!map.has(driverId)) map.set(driverId, { accepted: 0, rejected: 0, expired: 0, pending: 0 });
    map.get(driverId)[key] += 1;
  };

  for (const row of [...orderRows, ...groupRows]) {
    for (const h of row.offer_history || []) {
      if (!h.driver_id) continue;
      if (h.status === 'Accepted') bump(h.driver_id, 'accepted');
      else if (h.status === 'Rejected') bump(h.driver_id, 'rejected');
      else if (h.status === 'Expired') bump(h.driver_id, 'expired');
      else if (h.status === 'Offered') bump(h.driver_id, 'pending'); // لسا معلّق وقت الحساب
    }
  }
  return map;
}

// ===========================
// 📌 إحصاءات التسليم لكل سائق (كل الطلبات يلي اتعيّنت له عبر تاريخه، مو بس
// الحالية) - عدد المكتملة/الملغاة بعد التعيين + عيّنات مدة التوصيل الفعلية.
// استعلام واحد بغض النظر عن عدد السائقين.
// ===========================
async function fetchDeliveryStatsByDriver() {
  const rows = await Order.findAll({
    where: { driver_id: { [Op.ne]: null } },
    attributes: ['driver_id', 'status', 'status_history']
  });

  const map = new Map();
  for (const row of rows) {
    if (!map.has(row.driver_id)) map.set(row.driver_id, { delivered: 0, cancelled: 0, durations: [] });
    const bucket = map.get(row.driver_id);
    if (row.status === 'Delivered') {
      bucket.delivered += 1;
      const dur = deliveryMinutesFromHistory(row.status_history);
      if (dur !== null) bucket.durations.push(dur);
    } else if (TERMINAL_DRIVER_STATUSES.includes(row.status) && row.status !== 'Delivered') {
      bucket.cancelled += 1;
    }
  }
  return map;
}

// ✅ يبني كائن المؤشرات الخمسة المطلوبة لسائق واحد من الخرائط المجهّزة مسبقًا
function buildPerformanceFromMaps(driverId, offerMap, deliveryMap) {
  const offer = offerMap.get(driverId) || { accepted: 0, rejected: 0, expired: 0, pending: 0 };
  const delivery = deliveryMap.get(driverId) || { delivered: 0, cancelled: 0, durations: [] };

  const resolvedOffers = offer.accepted + offer.rejected + offer.expired;
  const avgDeliveryTimeMin = delivery.durations.length
    ? Math.round(delivery.durations.reduce((a, b) => a + b, 0) / delivery.durations.length)
    : null;
  // ✅ معدل الالتزام: من كل الطلبات يلي وصلت لحالة نهائية بعد ما اتعيّنت لهاد
  // السائق، شو نسبة يلي فعلًا سلّمها بنجاح (Delivered) بدل ما تنلغى/تُرفض بعد التعيين
  const commitmentDenominator = delivery.delivered + delivery.cancelled;

  return {
    completed_orders: delivery.delivered,
    avg_delivery_time_min: avgDeliveryTimeMin,
    avg_delivery_time_sample_size: delivery.durations.length,
    smart_assignment: {
      total_offers: resolvedOffers + offer.pending,
      accepted: offer.accepted,
      rejected: offer.rejected,
      expired: offer.expired,
      pending: offer.pending,
      acceptance_rate: resolvedOffers ? round2(offer.accepted / resolvedOffers) : null,
      rejection_rate: resolvedOffers ? round2(offer.rejected / resolvedOffers) : null
    },
    commitment_rate: commitmentDenominator ? round2(delivery.delivered / commitmentDenominator) : null
  };
}

// ===========================
// 📌 أداء سائق واحد (شاشة "أدائي" بتطبيق السائق)
// ===========================
async function computeDriverPerformance(driverId) {
  const [offerMap, deliveryMap] = await Promise.all([fetchOfferStatsByDriver(), fetchDeliveryStatsByDriver()]);
  return buildPerformanceFromMaps(driverId, offerMap, deliveryMap);
}

// ===========================
// 📌 أداء كل السائقين دفعة وحدة (لوحة الأدمن) - نفس تكلفة الاستعلام لسائق واحد
// ===========================
async function computeAllDriversPerformance(driverIds) {
  const [offerMap, deliveryMap] = await Promise.all([fetchOfferStatsByDriver(), fetchDeliveryStatsByDriver()]);
  return driverIds.map((id) => ({ driver_id: id, ...buildPerformanceFromMaps(id, offerMap, deliveryMap) }));
}

module.exports = { computeDriverPerformance, computeAllDriversPerformance };
