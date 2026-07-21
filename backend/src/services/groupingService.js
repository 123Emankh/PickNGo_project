// src/services/groupingService.js
//
// Grouped Delivery (Smart Order Clustering): يقرر وقت إنشاء طلب جديد هل
// ينضم لرحلة توصيل مجمّعة موجودة، ينشئ وحدة جديدة مع طلب سابق، أو يضل فردي
// (الحالة الطبيعية/الأغلبية - delivery_group_id يضل null). ما بيلمس أي شي
// تاني بالطلب - نداء واحد إضافي بس من createOrder، وفاشل هون ما لازم يفشّل
// الطلب نفسه (نفس فلسفة try/catch حول الكوبون بـ orderController).
const { Op } = require('sequelize');
const { Order, DeliveryGroup, DeliveryGroupItem, Restaurant, SystemSettings } = require('../models');
const { haversineKm, PICKUP_TRANSIT_MIN, AVG_SPEED_KMH } = require('../utils/geo');
const GROUPING_DEFAULTS = require('./grouping/config');

// ✅ حالات الطلب يلي لسا "قابل للتجميع" (ما ضل انسحب لسائق ولا خلص)
const POOLABLE_STATUSES = ['Pending', 'Confirmed', 'Preparing', 'Ready'];

// ✅ إعدادات Grouped Delivery الحية من لوحة الأدمن (system_settings) - قراءة
// طازة بكل استدعاء (مش cache) عشان أي تعديل من الأدمن ينطبق فورًا على أول
// طلب جديد، بدون حاجة لإعادة تشغيل السيرفر. لو ما كان في صف أصلاً (قبل أول
// فتح لصفحة الإعدادات) بنستخدم نفس القيم الافتراضية القديمة.
async function getLiveGroupingSettings(transaction) {
  const [settings] = await SystemSettings.findOrCreate({
    where: { id: 1 },
    defaults: {
      grouped_delivery_enabled: GROUPING_DEFAULTS.GROUPED_DELIVERY_ENABLED,
      max_store_distance: GROUPING_DEFAULTS.MAX_STORE_DISTANCE_KM,
      max_delivery_distance: GROUPING_DEFAULTS.MAX_DROPOFF_DISTANCE_KM,
      max_time_between_orders: GROUPING_DEFAULTS.MAX_GROUPING_WINDOW_MIN,
      max_orders_per_group: GROUPING_DEFAULTS.MAX_ORDERS_PER_GROUP,
      max_stores_per_trip: GROUPING_DEFAULTS.MAX_STORES_PER_TRIP,
      auto_assign_driver: GROUPING_DEFAULTS.AUTO_ASSIGN_DRIVER
    },
    transaction
  });
  return settings;
}

/**
 * يحاول يضم طلب جديد لرحلة توصيل مجمّعة (أو ينشئ وحدة جديدة). لازم يتنادى
 * جوا نفس transaction إنشاء الطلب، بعد Order.create مباشرة.
 * @param {Order} order - الطلب المنشأ حديثًا (لازم delivery_lat/lng محددين)
 * @param {Restaurant} store - متجر الطلب (نفس instance المجاب بـ createOrder)
 * @param {Transaction} transaction
 * @returns {number|null} group_id لو انضم/انشأ مجموعة، أو null لو ضل فردي
 */
async function maybeGroupOrder(order, store, transaction) {
  try {
    if (!store || store.location_lat == null || store.location_lng == null) return null;
    if (order.delivery_lat == null || order.delivery_lng == null) return null;

    const settings = await getLiveGroupingSettings(transaction);
    if (!settings.grouped_delivery_enabled) return null;

    const maxStoreDistanceKm = parseFloat(settings.max_store_distance);
    const maxDropoffDistanceKm = parseFloat(settings.max_delivery_distance);
    const maxGroupSize = Math.min(settings.max_orders_per_group, settings.max_stores_per_trip);
    const windowStart = new Date(Date.now() - settings.max_time_between_orders * 60 * 1000);

    const candidates = await Order.findAll({
      where: {
        customer_id: order.customer_id,
        order_id: { [Op.ne]: order.order_id },
        status: { [Op.in]: POOLABLE_STATUSES },
        driver_id: null,
        created_at: { [Op.gte]: windowStart }
      },
      include: [{ model: Restaurant, as: 'store' }],
      transaction
    });

    // ✅ منفضّل ننضم لمجموعة موجودة قبل ما ننشئ وحدة جديدة من طلبين فرديين
    candidates.sort((a, b) => {
      const aGrouped = a.delivery_group_id ? 0 : 1;
      const bGrouped = b.delivery_group_id ? 0 : 1;
      if (aGrouped !== bGrouped) return aGrouped - bGrouped;
      return new Date(a.created_at) - new Date(b.created_at);
    });

    for (const candidate of candidates) {
      if (!candidate.store || candidate.delivery_lat == null || candidate.delivery_lng == null) continue;

      let anchorStore = candidate.store;
      let anchorDeliveryLat = parseFloat(candidate.delivery_lat);
      let anchorDeliveryLng = parseFloat(candidate.delivery_lng);
      let anchorOrderId = candidate.order_id;
      let anchorCreatedAt = candidate.created_at;
      let existingGroup = null;

      if (candidate.delivery_group_id) {
        existingGroup = await DeliveryGroup.findByPk(candidate.delivery_group_id, { transaction });
        // ✅ مجموعة سائق فيها محدد إلها فعلاً (Assigned/Completed/Cancelled) -
        // ما منزعج رحلة ملتزم فيها سائق أصلًا
        if (!existingGroup || existingGroup.status !== 'Forming') continue;

        // ✅ حد أقصى لعدد الطلبات/المتاجر بالرحلة الوحدة (إعداد أدمن) - لو
        // المجموعة وصلت الحد، ما تنضم إلها طلبات إضافية
        const currentGroupSize = await DeliveryGroupItem.count({
          where: { group_id: existingGroup.group_id },
          transaction
        });
        if (currentGroupSize >= maxGroupSize) continue;

        // ✅ الترسيخ (anchor) دايمًا أول طلب انضم للمجموعة (pickup_sequence=1) -
        // مش بالضرورة "candidate" نفسه لو هو انضم لاحقًا
        const anchorItem = await DeliveryGroupItem.findOne({
          where: { group_id: existingGroup.group_id, pickup_sequence: 1 },
          include: [{ model: Order, as: 'order', include: [{ model: Restaurant, as: 'store' }] }],
          transaction
        });
        if (!anchorItem || !anchorItem.order || !anchorItem.order.store) continue;
        anchorStore = anchorItem.order.store;
        anchorDeliveryLat = parseFloat(anchorItem.order.delivery_lat);
        anchorDeliveryLng = parseFloat(anchorItem.order.delivery_lng);
        anchorOrderId = anchorItem.order.order_id;
        anchorCreatedAt = anchorItem.order.created_at;
      }

      const storeDistanceKm = haversineKm(
        parseFloat(store.location_lat),
        parseFloat(store.location_lng),
        parseFloat(anchorStore.location_lat),
        parseFloat(anchorStore.location_lng)
      );
      const dropoffDistanceKm = haversineKm(
        parseFloat(order.delivery_lat),
        parseFloat(order.delivery_lng),
        anchorDeliveryLat,
        anchorDeliveryLng
      );

      if (storeDistanceKm === null || storeDistanceKm > maxStoreDistanceKm) continue;
      if (dropoffDistanceKm === null || dropoffDistanceKm > maxDropoffDistanceKm) continue;

      // ✅ سبب التجميع (Grouping Reason) - لو وصلنا هون فكل الشروط الأربعة
      // تحققت أصلاً (نفس الزبون جاي من الـ query نفسها، والباقي من فحوصات
      // الـ continue فوق) - بنسجلها عشان تظهر بلوحة الأدمن (Group #X → Reason)
      const timeDifferenceMinutes = Math.round(
        Math.abs(new Date(order.created_at) - new Date(anchorCreatedAt)) / 60000
      );
      const rulesSatisfied = ['same_customer', 'store_distance', 'delivery_distance', 'time_window'];
      const groupingReasonFields = {
        matched_with_order_id: anchorOrderId,
        store_distance_km: storeDistanceKm,
        delivery_distance_km: dropoffDistanceKm,
        time_difference_minutes: timeDifferenceMinutes,
        rules_satisfied: rulesSatisfied
      };

      // ✅ طابقنا - ننضم لمجموعة موجودة، أو ننشئ وحدة جديدة تجمع الطلبين
      if (existingGroup) {
        const maxSeq = await DeliveryGroupItem.max('pickup_sequence', {
          where: { group_id: existingGroup.group_id },
          transaction
        });
        await DeliveryGroupItem.create(
          {
            group_id: existingGroup.group_id,
            order_id: order.order_id,
            pickup_sequence: (maxSeq || 0) + 1,
            ...groupingReasonFields
          },
          { transaction }
        );
        order.delivery_group_id = existingGroup.group_id;
        await order.save({ transaction });
        return existingGroup.group_id;
      }

      const newGroup = await DeliveryGroup.create(
        { customer_id: order.customer_id, status: 'Forming' },
        { transaction }
      );
      await DeliveryGroupItem.bulkCreate(
        [
          // ✅ أول عضو (anchor) - بدون سبب تجميع، هو ما "انضم" لشي، هو بداية المجموعة
          { group_id: newGroup.group_id, order_id: candidate.order_id, pickup_sequence: 1 },
          { group_id: newGroup.group_id, order_id: order.order_id, pickup_sequence: 2, ...groupingReasonFields }
        ],
        { transaction }
      );
      await Order.update(
        { delivery_group_id: newGroup.group_id },
        { where: { order_id: candidate.order_id }, transaction }
      );
      order.delivery_group_id = newGroup.group_id;
      await order.save({ transaction });
      return newGroup.group_id;
    }

    return null;
  } catch (error) {
    console.error('❌ maybeGroupOrder error:', error);
    return null;
  }
}

/**
 * إحصائيات Grouped Delivery للوحة الأدمن - راجع adminController.getDashboardStats
 */
async function getGroupingStats() {
  // ✅ بداية اليوم بتوقيت السيرفر - لعدّاد "Grouped Deliveries Today" بصفحة
  // إعدادات لوحة الأدمن (يعطي الأدمن إحساس فوري بأثر إعداداته الحالية)
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);

  const [totalGroups, ordersGrouped, groupsCreatedToday] = await Promise.all([
    DeliveryGroup.count(),
    Order.count({ where: { delivery_group_id: { [Op.ne]: null } } }),
    DeliveryGroup.count({ where: { created_at: { [Op.gte]: startOfToday } } })
  ]);

  const avgOrdersPerGroup = totalGroups > 0 ? Math.round((ordersGrouped / totalGroups) * 100) / 100 : 0;
  // ✅ عدد الرحلات الموفّرة = فرق عدد الطلبات المجمّعة عن عدد الرحلات (كل رحلة
  // بدل ما تاخد سائق منفصل لكل طلب فيها، أخدت واحد بس)
  const tripsSaved = Math.max(0, ordersGrouped - totalGroups);
  // ✅ تقدير مش دقيق 100% (نفس فلسفة estimateStageDurations بـ geo.js) - بس
  // معقول: كل رحلة موفّرة كانت رح تاخد PICKUP_TRANSIT_MIN دقيقة إضافية لحالها
  const timeSavedMinEstimate = tripsSaved * PICKUP_TRANSIT_MIN;

  // ✅ تقدير وقود/تكلفة/CO2 موفّرين - كل دقيقة موفّرة تتحول لمسافة عبر
  // AVG_SPEED_KMH (نفس ثابت geo.js)، وبعدين لتكلفة/انبعاثات عبر ثوابت
  // grouping/config.js. تقدير تقريبي صريح، مش قياس فعلي - نفس فلسفة باقي
  // التقديرات بهاد الملف.
  const fuelSavedKmEstimate = Math.round(((timeSavedMinEstimate / 60) * AVG_SPEED_KMH) * 10) / 10;
  const costSavedJdEstimate = Math.round(fuelSavedKmEstimate * GROUPING_DEFAULTS.FUEL_COST_PER_KM_JD * 100) / 100;
  const co2SavedKgEstimate = Math.round(fuelSavedKmEstimate * GROUPING_DEFAULTS.CO2_KG_PER_KM * 100) / 100;

  return {
    total_groups: totalGroups,
    orders_grouped: ordersGrouped,
    avg_orders_per_group: avgOrdersPerGroup,
    trips_saved: tripsSaved,
    time_saved_min_estimate: timeSavedMinEstimate,
    fuel_saved_km_estimate: fuelSavedKmEstimate,
    cost_saved_jd_estimate: costSavedJdEstimate,
    co2_saved_kg_estimate: co2SavedKgEstimate,
    groups_created_today: groupsCreatedToday
  };
}

// ✅ Simulation (لوحة الأدمن - Delivery Simulation): نفس شروط المطابقة
// الجوهرية المستخدمة بـ maybeGroupOrder (مسافة المتاجر/التوصيل/الفارق
// الزمني) بس كدالة نقية بدون قاعدة بيانات - عشان الأدمن يجرب سيناريو
// افتراضي (إحداثيات + فارق وقت) ويشوف هل كانت رح تنجمع من عدمه، بنفس
// الإعدادات الحية الحالية. ما بتلمس/تستخدمها maybeGroupOrder نفسها (هناك
// شرط الوقت مضمون مسبقًا عبر فلترة الاستعلام على نافذة متجددة - راجع
// getLiveGroupingSettings/windowStart فوق)، هون بنفحصه صراحة لأنه ما في
// استعلام قاعدة بيانات بالسيناريو الافتراضي.
function evaluateGroupingMatch({ storeDistanceKm, dropoffDistanceKm, timeDifferenceMinutes }, settings) {
  const maxStoreDistanceKm = parseFloat(settings.max_store_distance);
  const maxDropoffDistanceKm = parseFloat(settings.max_delivery_distance);
  const maxTimeMinutes = settings.max_time_between_orders;

  const checks = {
    same_customer: true,
    store_distance: storeDistanceKm !== null && storeDistanceKm <= maxStoreDistanceKm,
    delivery_distance: dropoffDistanceKm !== null && dropoffDistanceKm <= maxDropoffDistanceKm,
    time_window: timeDifferenceMinutes !== null && timeDifferenceMinutes <= maxTimeMinutes
  };

  const rulesSatisfied = Object.keys(checks).filter((key) => checks[key]);
  const rulesFailed = Object.keys(checks).filter((key) => !checks[key]);

  return {
    matched: rulesFailed.length === 0,
    rulesSatisfied,
    rulesFailed,
    thresholds: {
      max_store_distance_km: maxStoreDistanceKm,
      max_delivery_distance_km: maxDropoffDistanceKm,
      max_time_between_orders_min: maxTimeMinutes
    }
  };
}

module.exports = {
  maybeGroupOrder,
  getGroupingStats,
  getLiveGroupingSettings,
  evaluateGroupingMatch,
  POOLABLE_STATUSES
};
