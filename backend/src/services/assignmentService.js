// src/services/assignmentService.js
//
// Phase 3 - Smart Assignment: يدير دورة حياة "عرض" الطلب على سائق واحد
// بالذات (offer) فوق نظام الـ Manual Accept الموجود، بدون ما يلغيه:
//   Ready + driver_id=null  →  [محرك التسجيل يختار أفضل سائق] → عرض عليه
//   (offered_driver_id + offer_expires_at) لمدة OFFER_TIMEOUT_MS
//     - قبل خلال المهلة  → driver_id يتحدد (Auto)، Busy، خلص
//     - رفض/تجاهل المهلة → استبعاد هاد السائق وتجربة التالي بالترتيب
//     - ما ضل مرشح مؤهل  → الطلب يرجع بدون أي عرض معلّق = بيظهر تلقائيًا
//       بالقائمة المفتوحة (getAvailableOrders) تمامًا متل قبل Phase 3 - أي
//       التعيين الذكي "Fallback" على النظام الحالي، مش بديل عنه.
const { Op } = require('sequelize');
const { Order, Restaurant, User, sequelize } = require('../models');
const { rankCandidates } = require('./assignment/scoringEngine');
const { buildOfferReasonLabel } = require('./assignment/factors');
const { setDriverStatus } = require('./driverStatusService');
const { createNotification } = require('./notificationService');

const OFFER_TIMEOUT_MS = 2 * 60 * 1000; // مدة رد السائق على العرض (دقيقتين)
const SWEEP_INTERVAL_MS = 20 * 1000; // كل قد إيش نفحص عروض منتهية

function withStore(orderId) {
  return Order.findByPk(orderId, { include: [{ model: Restaurant, as: 'store' }] });
}

// ✅ كل سائق جُرّب على هاد الطلب ولسا ما انقبل (Offered لسا معلّق، أو
// Rejected/Expired) - ما منعرض عليه نفس الطلب مرتين بنفس الدورة
function collectTriedDriverIds(order) {
  const history = Array.isArray(order.offer_history) ? order.offer_history : [];
  return [...new Set(history.filter((h) => h.driver_id && h.status !== 'Accepted').map((h) => h.driver_id))];
}

function appendOfferHistory(order, entry) {
  order.offer_history = [...(order.offer_history || []), { at: new Date(), ...entry }];
}

// ✅ يقفل أي عرض معلّق بدون ما يعيد المحاولة (تستخدمها updateOrderStatus
// وقت إلغاء طلب - ما في داعي نعرضه على حدا بعد هيك)
function clearPendingOffer(order) {
  order.offered_driver_id = null;
  order.offer_expires_at = null;
}

/**
 * يحاول يلاقي أفضل سائق ويعرض عليه الطلب. ما بيغيّر شي لو الطلب مش
 * Ready+غير معيّن (race guard)، أو لو ما في مرشح مؤهل (بترجع null والطلب
 * يضل بحالته الطبيعية = فالباك للقائمة المفتوحة).
 */
async function tryAutoAssign(orderId, io, { excludeDriverIds = [] } = {}) {
  const order = await withStore(orderId);
  if (!order || order.status !== 'Ready' || order.driver_id) return null;

  const candidates = await rankCandidates(order, excludeDriverIds);

  if (!candidates.length) {
    clearPendingOffer(order);
    appendOfferHistory(order, { driver_id: null, status: 'NoCandidate' });
    await order.save();
    return null;
  }

  // ✅ نجرّب كل مرشح بالترتيب جوا معاملة ذرّية: نقفل صف السائق (SELECT ...
  // FOR UPDATE) ونعيد فحص "ما عنده عرض معلّق تاني" لحظة الكتابة الفعلية، مش
  // بس وقت الترتيب (rankCandidates فوق) - يسكّر نافذة سباق حقيقية: طلبين
  // بيصيروا Ready بنفس اللحظة كانوا نظريًا يقدروا يرتّبوا نفس السائق كأفضل
  // مرشح ويعرضوا عليه الاثنين مع بعض قبل ما أي منهم يكتب عرضه. قفل صف
  // السائق (مش صف الطلب) هو اللي بيخلي المحاولتين تتسلسلوا صح.
  let top = null;
  for (const candidate of candidates) {
    const driverId = candidate.driver.user_id;
    // eslint-disable-next-line no-await-in-loop
    const claimed = await sequelize.transaction(async (t) => {
      await User.findByPk(driverId, { transaction: t, lock: t.LOCK.UPDATE });
      const stillHasOtherOffer = await Order.count({
        where: {
          offered_driver_id: driverId,
          offer_expires_at: { [Op.gt]: new Date() },
          order_id: { [Op.ne]: order.order_id }
        },
        transaction: t
      });
      if (stillHasOtherOffer > 0) return false;

      order.offered_driver_id = driverId;
      order.offer_expires_at = new Date(Date.now() + OFFER_TIMEOUT_MS);
      appendOfferHistory(order, {
        driver_id: driverId,
        status: 'Offered',
        reason: { score: candidate.score, breakdown: candidate.breakdown, distance_km: candidate.distanceKm, active_orders: candidate.activeOrders }
      });
      await order.save({ transaction: t });
      return true;
    });

    if (claimed) {
      top = candidate;
      break;
    }
  }

  if (!top) {
    // ✅ كل المرشحين كانوا مشغولين فعليًا لحظة الكتابة (نادر جدًا - نفس
    // لحظة سباق على أكتر من طلب مع بعض) - نفس مسار "ما في مرشح مؤهل"
    clearPendingOffer(order);
    appendOfferHistory(order, { driver_id: null, status: 'NoCandidate' });
    await order.save();
    return null;
  }

  if (io) {
    io.to(`driver-orders:${top.driver.user_id}`).emit('order:offer', {
      is_group: false,
      order_id: order.order_id,
      order_number: order.order_number,
      order_count: 1,
      store_name: order.store ? order.store.name : null,
      store_address: order.store ? order.store.address : null,
      delivery_address: order.delivery_address,
      distance_km: top.distanceKm,
      delivery_fee: parseFloat(order.delivery_fee),
      reason_label: buildOfferReasonLabel(top.breakdown, top.distanceKm),
      expires_at: order.offer_expires_at
    });
  }

  // ✅ Phase 4 - إشعار مخزّن للسائق بالعرض (مكمّل لبث order:offer اللحظي -
  // بيضل موجود بسجل إشعاراته حتى لو فوّت البث أو فتح التطبيق بعدها بشوي)
  createNotification({
    userId: top.driver.user_id,
    title: 'عرض توصيل جديد',
    body: `طلب من ${order.store ? order.store.name : 'متجر'}${top.distanceKm !== null ? ` (${top.distanceKm.toFixed(1)} كم)` : ''}`,
    type: 'SmartAssignmentOffer',
    relatedType: 'Order',
    relatedId: order.order_id,
    io
  }).catch((err) => console.error('❌ createNotification (SmartAssignmentOffer) error:', err));

  return top.driver.user_id;
}

/**
 * رد السائق المعروض عليه (قبول/رفض). يرجّع { success, code, order }.
 * code لو success=false: 'NOT_OFFERED' (مش معروض عليه هاد الطلب أصلًا) أو
 * 'EXPIRED' (المهلة خلصت - غالبًا الـ sweep قدّامه شوي وعرضه لحدا تاني).
 */
async function respondToOffer(orderId, driverId, action, io) {
  const order = await Order.findByPk(orderId);
  if (!order) return { success: false, code: 'NOT_FOUND' };

  if (order.offered_driver_id !== driverId) {
    return { success: false, code: 'NOT_OFFERED' };
  }
  if (!order.offer_expires_at || new Date(order.offer_expires_at) < new Date()) {
    return { success: false, code: 'EXPIRED' };
  }

  const history = Array.isArray(order.offer_history) ? [...order.offer_history] : [];
  const lastOfferIndex = [...history].reverse().findIndex((h) => h.driver_id === driverId && h.status === 'Offered');
  const idx = lastOfferIndex >= 0 ? history.length - 1 - lastOfferIndex : -1;

  if (action === 'accept') {
    if (idx >= 0) history[idx] = { ...history[idx], status: 'Accepted' };
    order.offer_history = history;
    order.offered_driver_id = null;
    order.offer_expires_at = null;
    order.driver_id = driverId;
    order.assigned_at = new Date();
    order.assignment_type = 'Auto';
    order.assignment_reason = idx >= 0 ? history[idx].reason : null;
    await order.save();

    await setDriverStatus(driverId, 'Busy', io);

    if (io) {
      io.to(`order:${order.order_id}`).emit('order:assigned', {
        order_id: order.order_id,
        driver_id: driverId,
        assignment_type: 'Auto'
      });
    }

    // ✅ باج كان موجود: قبول السائق للعرض ما كان يبلّغ الزبون بأي إشعار
    // مخزّن - بس بث order:assigned اللحظي (بيفوّته لو التطبيق مقفول وقتها)
    createNotification({
      userId: order.customer_id,
      title: 'تم تعيين سائق لطلبك',
      body: `طلبك #${order.order_number} بالطريق - السائق بقبل التوصيل الآن`,
      type: 'OrderStatus',
      relatedType: 'Order',
      relatedId: order.order_id,
      io
    }).catch((err) => console.error('❌ createNotification (OrderStatus/offer-accepted) error:', err));

    return { success: true, order };
  }

  // reject
  if (idx >= 0) history[idx] = { ...history[idx], status: 'Rejected' };
  order.offer_history = history;
  clearPendingOffer(order);
  await order.save();

  await tryAutoAssign(orderId, io, { excludeDriverIds: collectTriedDriverIds(order) });
  return { success: true, order: await Order.findByPk(orderId) };
}

/**
 * فحص دوري: أي عرض انتهت مهلته بدون رد - يقفله ويجرب السائق التالي
 * بالترتيب (أو يسيبه بدون عرض = فالباك للقائمة المفتوحة لو ما ضل حدا).
 */
async function sweepExpiredOffers(io) {
  try {
    const expired = await Order.findAll({
      where: {
        offered_driver_id: { [Op.ne]: null },
        offer_expires_at: { [Op.lt]: new Date() }
      }
    });

    for (const order of expired) {
      const expiredDriverId = order.offered_driver_id;
      const history = Array.isArray(order.offer_history) ? [...order.offer_history] : [];
      const lastOfferIndex = [...history].reverse().findIndex((h) => h.driver_id === expiredDriverId && h.status === 'Offered');
      const idx = lastOfferIndex >= 0 ? history.length - 1 - lastOfferIndex : -1;
      if (idx >= 0) history[idx] = { ...history[idx], status: 'Expired' };
      order.offer_history = history;
      clearPendingOffer(order);
      await order.save();

      await tryAutoAssign(order.order_id, io, { excludeDriverIds: collectTriedDriverIds(order) });
    }
  } catch (error) {
    console.error('❌ sweepExpiredOffers error:', error);
  }
}

let sweepTimer = null;
function startAssignmentSweep(io) {
  if (sweepTimer) return;
  sweepTimer = setInterval(() => sweepExpiredOffers(io), SWEEP_INTERVAL_MS);
}

module.exports = {
  tryAutoAssign,
  respondToOffer,
  sweepExpiredOffers,
  startAssignmentSweep,
  clearPendingOffer,
  collectTriedDriverIds,
  OFFER_TIMEOUT_MS
};
