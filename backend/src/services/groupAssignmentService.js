// src/services/groupAssignmentService.js
//
// Grouped Delivery - نسخة "على مستوى المجموعة" من assignmentService.js
// (Phase 3): بدل ما نعرض/نعيّن كل طلب لحاله، منعامل رحلة التوصيل المجمّعة
// (DeliveryGroup) كوحدة وحدة - سائق واحد ياخد كل طلباتها سوا. بيعيد استخدام
// scoringEngine.rankCandidates بدون أي تعديل عليه: منبني "طلب اصطناعي"
// (store = أول متجر بالرحلة، required_vehicle_type/preferred_company_id =
// أول قيمة غير فارغة بين أعضاء المجموعة) ومنمرره لنفس محرك التسجيل.
//
// مجموعات delivery_group_id=null (الأغلبية) ما إلها علاقة بهاد الملف إطلاقًا -
// بتضل تمشي بمسار assignmentService.js الأصلي متل قبل تمامًا.
const { Op } = require('sequelize');
const { DeliveryGroup, DeliveryGroupItem, Order, Restaurant, User, sequelize } = require('../models');
const { rankCandidates } = require('./assignment/scoringEngine');
const { buildOfferReasonLabel, MAX_CONCURRENT_ACTIVE_ORDERS } = require('./assignment/factors');
const ACTIVE_ORDER_STATUSES = { [Op.notIn]: ['Delivered', 'Cancelled', 'Refunded'] };
const { setDriverStatus } = require('./driverStatusService');
const { createNotification } = require('./notificationService');
const { getLiveGroupingSettings } = require('./groupingService');

const OFFER_TIMEOUT_MS = 2 * 60 * 1000; // نفس مهلة العرض الفردي (دقيقتين)
const SWEEP_INTERVAL_MS = 20 * 1000;

function withGroupContext(groupId) {
  return DeliveryGroup.findByPk(groupId, {
    include: [
      {
        model: DeliveryGroupItem,
        as: 'items',
        include: [{ model: Order, as: 'order', include: [{ model: Restaurant, as: 'store' }] }]
      }
    ]
  });
}

// ✅ Defensive: group.items لازم يكون مصفوفة دايمًا (Sequelize بترجعها []
// حتى لو ما في صفوف مطابقة عند استخدام include) - بس أي طلب لمجموعة بدون
// include (أو instance مبني يدويًا باختبار/سكربت) ممكن يوصل هون بـ items
// undefined. الافتراض الآمن: مصفوفة فاضية، مش رمي استثناء.
function sortedItems(group) {
  const items = Array.isArray(group && group.items) ? group.items : [];
  return [...items].sort((a, b) => a.pickup_sequence - b.pickup_sequence);
}

// ✅ عناصر المجموعة "الصالحة للعرض" بس (عندها طلب محمّل فعليًا). أي نقطة
// استهلاك خارجية (لوحة أدمن/شاشة سائق/تتبّع) لازم تستخدم هاد بدل sortedItems
// مباشرة قبل ما تعمل .map/.reduce على i.order.* - عشان عنصر واحد فاسد
// (طلب محذوف/بيانات قديمة) ما يفجّر عرض الرحلة كاملة، بس يختفي هو بس مع
// تسجيل تحذير بدل استثناء يوقف الطلب.
function validSortedItems(group) {
  const items = sortedItems(group);
  const valid = items.filter((i) => i && i.order);
  if (valid.length !== items.length) {
    console.warn(`⚠️ DeliveryGroup #${group && group.group_id}: ${items.length - valid.length} عنصر بدون طلب محمّل - تم تجاهلها بالعرض`);
  }
  return valid;
}

// ✅ بوابة صرامة كاملة (all-or-nothing) لأي قرار تعيين فعلي (عرض سائق/تسجيل) -
// مختلفة عن validSortedItems (اللي بتسمح بعرض جزئي). مجموعة بدون أي عنصر
// إطلاقًا، أو فيها عنصر واحد بيانات ناقصة (طلب مش محمّل)، لازم تُعتبر "غير
// صالحة للتعيين" بالكامل - منسمحش نبني رحلة تعيين حول فجوة مجهولة الحالة.
function hasValidItems(group) {
  const items = sortedItems(group);
  return items.length > 0 && items.every((i) => i && i.order);
}

// ✅ كل عضو بالمجموعة لازم يكون Ready قبل ما نعرض الرحلة على سائق - لأنه
// السائق لازم يقدر يستلم من كل المتاجر بنفس الجولة. مجموعة بدون عناصر
// صالحة (سباق تزامن بالإلغاء، أو بيانات تالفة) لازم "مش جاهزة" صراحة - مش
// true بالخطأ (كل عنصر بمصفوفة فاضية "يحقق" .every منطقيًا - vacuous truth)
// وإلا بتدخل مسار التعيين وتفجّر buildScoringOrderInput.
function allMembersReady(group) {
  if (!hasValidItems(group)) return false;
  return sortedItems(group).every((item) => item.order.status === 'Ready');
}

// ✅ أولوية للمجموعة الأكبر (توصية #4): لو في مجموعة تانية Forming، كل
// أعضاءها Ready، بلا سائق وبلا عرض معلّق، وعدد طلباتها أكبر من مجموعتنا -
// منرجّعها، وهاد بخلي tryAutoAssignGroup يأجّل عرض مجموعتنا الأصغر (تحت)
// ويسيب الفرصة للـ sweep الدوري (sweepPendingGroupsBySize) يعرض الأكبر أولًا.
async function findLargerPendingGroup(currentGroup) {
  const currentSize = sortedItems(currentGroup).length;
  const candidates = await DeliveryGroup.findAll({
    where: {
      status: 'Forming',
      driver_id: null,
      offered_driver_id: null,
      group_id: { [Op.ne]: currentGroup.group_id }
    },
    include: [
      {
        model: DeliveryGroupItem,
        as: 'items',
        include: [{ model: Order, as: 'order', include: [{ model: Restaurant, as: 'store' }] }]
      }
    ]
  });

  return candidates.find((g) => sortedItems(g).length > currentSize && allMembersReady(g)) || null;
}

// ✅ "طلب اصطناعي" لمحرك التسجيل: أول متجر بالرحلة للمسافة، وأول قيمة
// غير فارغة لنوع المركبة/الشركة المفضّلة بين كل أعضاء المجموعة. order_id
// بيكون لطلب الترسيخ الحقيقي (anchor) - مهم عشان فلتر "عرض تاني معلّق"
// بمحرك التسجيل يشتغل صح (يستثني هاد الطلب بالذات، مش undefined).
// ✅ Validation صريح: بيرجع null (مش رمي استثناء) لو المجموعة بدون عناصر
// صالحة - نفس فحص hasValidItems يلي allMembersReady بتستخدمه، بس هون defense
// in depth إضافية لأي نداء مستقبلي يتخطى allMembersReady بالغلط.
function buildScoringOrderInput(group) {
  if (!hasValidItems(group)) return null;

  const items = sortedItems(group);
  const anchor = items[0].order;
  const requiredVehicleType = items.map((i) => i.order.required_vehicle_type).find(Boolean) || null;
  const preferredCompanyId = items.map((i) => i.order.preferred_company_id).find(Boolean) || null;

  return {
    order_id: anchor.order_id,
    store: anchor.store,
    required_vehicle_type: requiredVehicleType,
    preferred_company_id: preferredCompanyId
  };
}

function collectTriedDriverIds(group) {
  const history = Array.isArray(group.offer_history) ? group.offer_history : [];
  return [...new Set(history.filter((h) => h.driver_id && h.status !== 'Accepted').map((h) => h.driver_id))];
}

function appendOfferHistory(group, entry) {
  group.offer_history = [...(group.offer_history || []), { at: new Date(), ...entry }];
}

// ✅ يقفل العرض المعلّق على مستوى المجموعة وكل طلباتها الأعضاء سوا - هاد هو
// اللي بخلي getAvailableOrders/scoringEngine الفرديين يشتغلوا صح بدون أي
// تعديل عليهم (كل عضو عنده offered_driver_id/offer_expires_at متل ما لو
// كان طلب فردي معروض عليه)
async function clearPendingOfferOnGroup(group, transaction) {
  group.offered_driver_id = null;
  group.offer_expires_at = null;
  await group.save({ transaction });
  await Order.update(
    { offered_driver_id: null, offer_expires_at: null },
    { where: { delivery_group_id: group.group_id }, transaction }
  );
}

/**
 * يحاول يلاقي أفضل سائق لرحلة توصيل مجمّعة ويعرضها عليه ككل. ما بيعمل شي لو
 * المجموعة مش Forming، أو عندها سائق أصلًا، أو لسا في عضو مش Ready.
 */
async function tryAutoAssignGroup(groupId, io, { excludeDriverIds = [] } = {}) {
  const group = await withGroupContext(groupId);
  if (!group || group.status !== 'Forming' || group.driver_id) return null;
  if (!allMembersReady(group)) return null;

  // ✅ أولوية للمجموعة الأكبر - بس بأول محاولة (excludeDriverIds فاضية).
  // إعادة محاولة بعد رفض/انتهاء عرض (excludeDriverIds غير فاضية) ما منأجّلها
  // عشان ما تعلق مجموعة صغيرة للأبد لو ضلت مجموعة أكبر Forming بدون سائق متاح.
  if (excludeDriverIds.length === 0) {
    const largerPending = await findLargerPendingGroup(group);
    if (largerPending) return null;
  }

  // ✅ Defense in depth: allMembersReady فوق أصلًا بتضمن hasValidItems(group)،
  // بس منتحقق صراحة هون كمان قبل أي عملية فعلية تعتمد على عناصر المجموعة -
  // لو رجعت null (نظريًا ما لازم يصير بعد الفحص فوق)، منسجّل تحذير ونطلع
  // بأمان بدل ما نمرر null لمحرك التسجيل ويطيح بـ TypeError
  const scoringInput = buildScoringOrderInput(group);
  if (!scoringInput) {
    console.warn(`⚠️ tryAutoAssignGroup: DeliveryGroup #${groupId} بدون عناصر صالحة رغم اجتيازها allMembersReady - تجاهل`);
    return null;
  }
  const candidates = await rankCandidates(scoringInput, excludeDriverIds);

  if (!candidates.length) {
    await clearPendingOfferOnGroup(group, null);
    appendOfferHistory(group, { driver_id: null, status: 'NoCandidate' });
    await group.save();
    return null;
  }

  // ✅ نفس منطق قفل-صف-السائق المستخدم بـ assignmentService.js.tryAutoAssign -
  // يسكّر نفس نافذة السباق (مجموعتين/طلب ومجموعة بيصيروا جاهزين بنفس اللحظة
  // ويرتّبوا نفس السائق قبل ما أي منهم يكتب عرضه).
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
          delivery_group_id: { [Op.ne]: group.group_id }
        },
        transaction: t
      });
      if (stillHasOtherOffer > 0) return false;

      group.offered_driver_id = driverId;
      group.offer_expires_at = new Date(Date.now() + OFFER_TIMEOUT_MS);
      appendOfferHistory(group, {
        driver_id: driverId,
        status: 'Offered',
        reason: { score: candidate.score, breakdown: candidate.breakdown, distance_km: candidate.distanceKm, active_orders: candidate.activeOrders }
      });
      await group.save({ transaction: t });
      await Order.update(
        { offered_driver_id: driverId, offer_expires_at: group.offer_expires_at },
        { where: { delivery_group_id: group.group_id }, transaction: t }
      );
      return true;
    });

    if (claimed) {
      top = candidate;
      break;
    }
  }

  if (!top) {
    await clearPendingOfferOnGroup(group, null);
    appendOfferHistory(group, { driver_id: null, status: 'NoCandidate' });
    await group.save();
    return null;
  }

  if (io) {
    const items = sortedItems(group);
    io.to(`driver-orders:${top.driver.user_id}`).emit('order:offer', {
      is_group: true,
      group_id: group.group_id,
      order_count: items.length,
      order_ids: items.map((i) => i.order.order_id),
      stores: items.map((i) => ({
        restaurant_id: i.order.store ? i.order.store.restaurant_id : null,
        name: i.order.store ? i.order.store.name : null,
        address: i.order.store ? i.order.store.address : null,
        pickup_sequence: i.pickup_sequence
      })),
      delivery_address: items[0].order.delivery_address,
      distance_km: top.distanceKm,
      delivery_fee: items.reduce((sum, i) => sum + parseFloat(i.order.delivery_fee || 0), 0),
      reason_label: buildOfferReasonLabel(top.breakdown, top.distanceKm),
      expires_at: group.offer_expires_at
    });
  }

  // ✅ Phase 4 - إشعار مخزّن للسائق برحلة التوصيل المجمّعة (مكمّل لبث order:offer)
  const anchorStoreName = sortedItems(group)[0]?.order?.store?.name || 'متجر';
  createNotification({
    userId: top.driver.user_id,
    title: 'عرض توصيل جديد (رحلة مجمّعة)',
    body: `رحلة تبدأ من ${anchorStoreName}${top.distanceKm !== null ? ` (${top.distanceKm.toFixed(1)} كم)` : ''}`,
    type: 'SmartAssignmentOffer',
    relatedType: 'DeliveryGroup',
    relatedId: group.group_id,
    io
  }).catch((err) => console.error('❌ createNotification (SmartAssignmentOffer/group) error:', err));

  return top.driver.user_id;
}

/**
 * فقط يشغّل تحقق الجاهزية + محاولة التعيين إذا لسا ما في سائق - تُنادى من
 * updateOrderStatus لما أي عضو بالمجموعة يصير Ready (بدل tryAutoAssign الفردي)
 */
async function tryAutoAssignGroupIfReady(groupId, io) {
  return tryAutoAssignGroup(groupId, io);
}

/**
 * رد السائق المعروض عليه رحلة مجمّعة (قبول/رفض)
 */
async function respondToGroupOffer(groupId, driverId, action, io) {
  const group = await withGroupContext(groupId);
  if (!group) return { success: false, code: 'NOT_FOUND' };

  if (group.offered_driver_id !== driverId) {
    return { success: false, code: 'NOT_OFFERED' };
  }
  if (!group.offer_expires_at || new Date(group.offer_expires_at) < new Date()) {
    return { success: false, code: 'EXPIRED' };
  }

  const history = Array.isArray(group.offer_history) ? [...group.offer_history] : [];
  const lastOfferIndex = [...history].reverse().findIndex((h) => h.driver_id === driverId && h.status === 'Offered');
  const idx = lastOfferIndex >= 0 ? history.length - 1 - lastOfferIndex : -1;

  if (action === 'accept') {
    if (idx >= 0) history[idx] = { ...history[idx], status: 'Accepted' };
    group.offer_history = history;
    group.offered_driver_id = null;
    group.offer_expires_at = null;
    group.driver_id = driverId;
    group.assigned_at = new Date();
    group.assignment_type = 'Auto';
    group.assignment_reason = idx >= 0 ? history[idx].reason : null;
    group.status = 'Assigned';
    await group.save();

    await Order.update(
      {
        driver_id: driverId,
        assigned_at: group.assigned_at,
        assignment_type: 'Auto',
        assignment_reason: group.assignment_reason,
        offered_driver_id: null,
        offer_expires_at: null
      },
      { where: { delivery_group_id: group.group_id } }
    );

    await setDriverStatus(driverId, 'Busy', io);

    if (io) {
      for (const item of sortedItems(group)) {
        io.to(`order:${item.order.order_id}`).emit('order:assigned', {
          order_id: item.order.order_id,
          driver_id: driverId,
          assignment_type: 'Auto',
          group_id: group.group_id
        });
      }
    }

    // ✅ إشعار واحد بس (مش وحد لكل طلب بالمجموعة - كلهم لنفس الزبون أصلًا،
    // راجع groupingService.maybeGroupOrder) - relatedId بيشاور لأول طلب
    // بالرحلة (anchor) عشان الضغط عليه يفتح تتبّع حقيقي وشغّال
    const anchorOrder = sortedItems(group)[0]?.order;
    if (anchorOrder) {
      createNotification({
        userId: group.customer_id,
        title: 'تم تعيين سائق لطلبك',
        body: 'رحلة توصيلك المجمّعة بالطريق - السائق بقبل التوصيل الآن',
        type: 'OrderStatus',
        relatedType: 'Order',
        relatedId: anchorOrder.order_id,
        io
      }).catch((err) => console.error('❌ createNotification (OrderStatus/group-offer-accepted) error:', err));
    }

    return { success: true, group };
  }

  // reject
  if (idx >= 0) history[idx] = { ...history[idx], status: 'Rejected' };
  group.offer_history = history;
  await group.save();
  await clearPendingOfferOnGroup(group, null);

  await tryAutoAssignGroup(groupId, io, { excludeDriverIds: collectTriedDriverIds(group) });
  return { success: true, group: await withGroupContext(groupId) };
}

/**
 * القبول اليدوي (المسار الفعلي المستخدم اليوم بتطبيق السائق - "قبول
 * المجموعة" من قائمة الطلبات المتاحة). ما بيغيّر حالة أي طلب - بس بيثبّت
 * السائق على الرحلة كاملة، تمامًا متل ما القبول اليدوي الفردي بيثبّت
 * driver_id بدون ما يغيّر حالة الطلب (حالة الطلب تتغيّر لاحقًا لما السائق
 * فعليًا يستلم من كل متجر).
 */
async function acceptGroupManually(groupId, driverId, io) {
  const group = await withGroupContext(groupId);
  if (!group) return { success: false, code: 'NOT_FOUND' };
  if (group.status !== 'Forming' || group.driver_id) {
    return { success: false, code: 'ALREADY_ASSIGNED' };
  }
  if (!allMembersReady(group)) {
    return { success: false, code: 'NOT_READY' };
  }
  if (group.offered_driver_id && group.offered_driver_id !== driverId) {
    return { success: false, code: 'OFFERED_TO_ANOTHER_DRIVER' };
  }

  // ✅ نفس حد التعيين الذكي الأقصى - كان غير مطبّق إطلاقًا بمسار القبول
  // اليدوي (فردي كان أو مجمّع)، راجع نفس الفحص بـ orderController.js
  const activeOrderCount = await Order.count({ where: { driver_id: driverId, status: ACTIVE_ORDER_STATUSES } });
  if (activeOrderCount >= MAX_CONCURRENT_ACTIVE_ORDERS) {
    return { success: false, code: 'MAX_ACTIVE_ORDERS_REACHED' };
  }

  const assignedAt = new Date();
  group.driver_id = driverId;
  group.assigned_at = assignedAt;
  group.assignment_type = 'Manual';
  group.assignment_reason = { type: 'manual', note: 'Driver self-assigned group from open orders list' };
  group.status = 'Assigned';
  group.offered_driver_id = null;
  group.offer_expires_at = null;
  await group.save();

  await Order.update(
    {
      driver_id: driverId,
      assigned_at: assignedAt,
      assignment_type: 'Manual',
      assignment_reason: group.assignment_reason,
      offered_driver_id: null,
      offer_expires_at: null
    },
    { where: { delivery_group_id: group.group_id } }
  );

  await setDriverStatus(driverId, 'Busy', io);

  if (io) {
    for (const item of sortedItems(group)) {
      io.to(`order:${item.order.order_id}`).emit('order:assigned', {
        order_id: item.order.order_id,
        driver_id: driverId,
        assignment_type: 'Manual',
        group_id: group.group_id
      });
    }
  }

  return { success: true, group: await withGroupContext(groupId) };
}

/**
 * فحص دوري لعروض المجموعات المنتهية - نفس منطق sweepExpiredOffers الفردي
 */
async function sweepExpiredGroupOffers(io) {
  try {
    const expired = await DeliveryGroup.findAll({
      where: {
        offered_driver_id: { [Op.ne]: null },
        offer_expires_at: { [Op.lt]: new Date() }
      }
    });
    if (!expired.length) return;

    // ✅ مفتاح "Auto Assign Driver" بيتحكم بس بإعادة محاولة التعيين التلقائي
    // بعد انتهاء مهلة عرض سابق - تنظيف حالة العرض المنتهي (تحت) بيصير دايمًا
    const settings = await getLiveGroupingSettings();

    // ✅ كل مجموعة بمحاولتها الخاصة (try/catch داخل الحلقة) - مجموعة وحدة
    // فيها حالة استثنائية (بيانات ناقصة، خطأ شبكة مؤقت...) ما لازم توقف
    // معالجة باقي المجموعات بنفس الدورة (كانت المشكلة الأصلية: استثناء بأول
    // عنصر بيهرب لـ catch الخارجي ويلغي كل المجموعات المتبقية بهاد الدور)
    for (const group of expired) {
      try {
        const expiredDriverId = group.offered_driver_id;
        const history = Array.isArray(group.offer_history) ? [...group.offer_history] : [];
        const lastOfferIndex = [...history].reverse().findIndex((h) => h.driver_id === expiredDriverId && h.status === 'Offered');
        const idx = lastOfferIndex >= 0 ? history.length - 1 - lastOfferIndex : -1;
        if (idx >= 0) history[idx] = { ...history[idx], status: 'Expired' };
        group.offer_history = history;
        await group.save();
        await clearPendingOfferOnGroup(group, null);

        if (settings.auto_assign_driver) {
          await tryAutoAssignGroup(group.group_id, io, { excludeDriverIds: collectTriedDriverIds(group) });
        }
      } catch (groupError) {
        console.error(`❌ sweepExpiredGroupOffers error on group #${group.group_id}:`, groupError);
      }
    }
  } catch (error) {
    console.error('❌ sweepExpiredGroupOffers error:', error);
  }
}

/**
 * شبكة أمان دورية لتوصية #4 (أولوية للمجموعة الأكبر): tryAutoAssignGroup
 * بيأجّل أي مجموعة صغيرة لو في وحدة أكبر منها Forming/جاهزة/بلا سائق -
 * هاد السويب هو اللي فعليًا "بيحرّك" العروض بترتيب صحيح (الأكبر أولًا) كل
 * ما يدور، بدل ما تضل كل المجموعات تتأجل لبعضها للأبد.
 */
async function sweepPendingGroupsBySize(io) {
  try {
    const pending = await DeliveryGroup.findAll({
      where: { status: 'Forming', driver_id: null, offered_driver_id: null },
      include: [
        {
          model: DeliveryGroupItem,
          as: 'items',
          include: [{ model: Order, as: 'order', include: [{ model: Restaurant, as: 'store' }] }]
        }
      ]
    });

    // ✅ Self-healing: مجموعة Forming بلا أي عنصر صالح (سباق تزامن بإلغاء
    // آخر طلب فيها - راجع orderController.updateOrderStatus، أو بيانات تالفة
    // قديمة) لازم تُغلق صراحة (Cancelled) بدل ما تضل عالقة Forming للأبد
    // وتُعاد قراءتها/تُستبعد بصمت كل 20 ثانية من غير أي أثر بلوحة الأدمن.
    const orphans = pending.filter((g) => !hasValidItems(g));
    for (const orphan of orphans) {
      try {
        console.warn(`⚠️ sweepPendingGroupsBySize: DeliveryGroup #${orphan.group_id} بدون عناصر صالحة - إغلاقها تلقائيًا (Cancelled)`);
        orphan.status = 'Cancelled';
        await orphan.save();
      } catch (orphanError) {
        console.error(`❌ sweepPendingGroupsBySize: تعذّر إغلاق المجموعة اليتيمة #${orphan.group_id}:`, orphanError);
      }
    }

    const ready = pending.filter((g) => allMembersReady(g));
    ready.sort((a, b) => {
      const sizeDiff = sortedItems(b).length - sortedItems(a).length;
      if (sizeDiff !== 0) return sizeDiff;
      return new Date(a.created_at) - new Date(b.created_at);
    });

    // ✅ نفس منطق try/catch لكل مجموعة لحالها المطبّق بـ sweepExpiredGroupOffers -
    // مجموعة وحدة بمشكلة ما توقف باقي المجموعات الجاهزة بنفس الدورة
    for (const group of ready) {
      try {
        await tryAutoAssignGroup(group.group_id, io, { excludeDriverIds: collectTriedDriverIds(group) });
      } catch (groupError) {
        console.error(`❌ sweepPendingGroupsBySize error on group #${group.group_id}:`, groupError);
      }
    }
  } catch (error) {
    console.error('❌ sweepPendingGroupsBySize error:', error);
  }
}

let sweepTimer = null;
function startGroupAssignmentSweep(io) {
  if (sweepTimer) return;
  sweepTimer = setInterval(() => {
    sweepExpiredGroupOffers(io);
    sweepPendingGroupsBySize(io);
  }, SWEEP_INTERVAL_MS);
}

module.exports = {
  tryAutoAssignGroup,
  tryAutoAssignGroupIfReady,
  respondToGroupOffer,
  acceptGroupManually,
  sweepExpiredGroupOffers,
  sweepPendingGroupsBySize,
  startGroupAssignmentSweep,
  allMembersReady,
  withGroupContext,
  sortedItems,
  validSortedItems,
  hasValidItems,
  buildScoringOrderInput
};
