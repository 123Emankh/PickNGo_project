// src/services/analytics/adminAnalyticsService.js
//
// لوحة تحليلات الأدمن - كلها مبنية من الجداول الموجودة أصلًا (orders +
// delivery_groups) لفترة زمنية معيّنة (افتراضيًا آخر 14 يوم)، بدون أي جدول
// جديد. تجمع: الطلبات اليومية، الإيرادات، أنشط المتاجر، أفضل السائقين أداءً
// (عبر driverAnalyticsService)، نجاح التعيين الذكي، ونسبة الطلبات المجمّعة.
const { Op } = require('sequelize');
const { Order, Restaurant, User } = require('../../models');
const { computeAllDriversPerformance } = require('./driverAnalyticsService');

function round2(n) {
  return Math.round(n * 100) / 100;
}

async function computeAdminAnalytics({ days = 14 } = {}) {
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  since.setHours(0, 0, 0, 0);

  const orders = await Order.findAll({
    where: { order_time: { [Op.gte]: since } },
    attributes: [
      'order_id', 'restaurant_id', 'status', 'final_amount', 'order_time',
      'delivery_group_id', 'assignment_type', 'status_history', 'driver_id'
    ]
  });

  // ---- الطلبات اليومية + الإيرادات (المسلّمة فقط تُحتسب إيرادًا فعليًا) ----
  const dailyMap = new Map();
  for (const o of orders) {
    const day = o.order_time.toISOString().slice(0, 10);
    if (!dailyMap.has(day)) dailyMap.set(day, { date: day, orders: 0, revenue: 0 });
    const bucket = dailyMap.get(day);
    bucket.orders += 1;
    if (o.status === 'Delivered') bucket.revenue += parseFloat(o.final_amount);
  }
  const totalOrders = orders.length;
  // ✅ نجمع الإيراد الخام (قبل التقريب) لكل يوم قبل ما نحسب المجموع الكلي -
  // تقريب كل يوم لحاله ثم جمع المقرّبات ممكن يراكم فرق بسيط (سنت أو اثنين)
  // عن المجموع الحقيقي على فترات طويلة
  const totalRevenue = round2([...dailyMap.values()].reduce((sum, d) => sum + d.revenue, 0));
  const daily = [...dailyMap.values()]
    .map((d) => ({ ...d, revenue: round2(d.revenue) }))
    .sort((a, b) => a.date.localeCompare(b.date));

  // ---- أنشط المتاجر (عدد طلبات بالفترة) ----
  const storeCounts = new Map();
  for (const o of orders) storeCounts.set(o.restaurant_id, (storeCounts.get(o.restaurant_id) || 0) + 1);
  const topStoreIds = [...storeCounts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 5).map(([id]) => id);
  const topStoreRows = topStoreIds.length
    ? await Restaurant.findAll({ where: { restaurant_id: topStoreIds }, attributes: ['restaurant_id', 'name'] })
    : [];
  const topStores = topStoreIds.map((id) => ({
    store_id: id.toString(),
    name: (topStoreRows.find((s) => s.restaurant_id === id) || {}).name || '',
    order_count: storeCounts.get(id)
  }));

  // ---- نجاح التعيين الذكي: من الطلبات يلي فعلًا احتاجت تعيين سائق، شو نسبة
  // يلي انعيّنت تلقائيًا (Auto) بدل ما تحتاج قبول يدوي أو تضل بدون سائق.
  // ✅ "احتاجت تعيين" ما بيعتمد بس على status_history (بعض الطلبات القديمة/
  // المزروعة يدويًا status_history فيها null رغم وصولها فعليًا لـ Ready وما
  // بعدها - لوحظ فعليًا بالبيانات الحقيقية) - نستخدم كمان الحالة الحالية
  // وassignment_type كإشارات احتياطية.
  const neededAssignment = orders.filter((o) => {
    const reachedReadyInHistory = Array.isArray(o.status_history) && o.status_history.some((h) => h.status === 'Ready');
    const reachedReadyByStatus = ['Ready', 'PickedUp', 'Delivered'].includes(o.status);
    return reachedReadyInHistory || reachedReadyByStatus || !!o.assignment_type;
  });
  const autoAssigned = neededAssignment.filter((o) => o.assignment_type === 'Auto').length;
  // ✅ "يدوي" = assignment_type='Manual' الصريح، أو أي طلب عنده سائق فعليًا
  // (driver_id) بدون assignment_type مسجّل (بيانات قديمة/مزروعة يدويًا -
  // بما إنه Auto ما بيصير أبدًا بدون تسجيل assignment_type='Auto' بمحرك
  // التعيين، فأي سائق موجود بدونه هو بالتعريف "مش تلقائي"). كل طلب بيقع
  // بمجموعة وحدة فقط من الثلاثة تحت - مجموعهم لازم يساوي needed_assignment دومًا.
  const manualAssigned = neededAssignment.filter((o) => o.assignment_type !== 'Auto' && !!o.driver_id).length;
  const unassignedCount = neededAssignment.filter((o) => !o.driver_id).length;
  const smartAssignment = {
    needed_assignment: neededAssignment.length,
    auto_assigned: autoAssigned,
    manual_assigned: manualAssigned,
    unassigned: unassignedCount,
    success_rate: neededAssignment.length ? round2(autoAssigned / neededAssignment.length) : null
  };

  // ---- نسبة الطلبات المجمّعة (Delivery Groups) ----
  const groupedOrders = orders.filter((o) => o.delivery_group_id).length;
  const groupedOrderRate = totalOrders ? round2(groupedOrders / totalOrders) : null;

  // ---- أفضل السائقين أداءً (بعدد الطلبات المكتملة خلال كامل تاريخهم، مش
  // مقيّد بالفترة - أداء تراكمي أدق من عيّنة قصيرة) ----
  const drivers = await User.findAll({
    // ✅ نفس باج NULL business_type اللي انلقى بمحرك التعيين الذكي - راجع
    // scoringEngine.js.fetchBaseCandidateDrivers
    where: { role: 'Driver', [Op.or]: [{ business_type: { [Op.ne]: 'Fleet / Company' } }, { business_type: null }] },
    attributes: ['user_id', 'full_name']
  });
  const driverPerf = await computeAllDriversPerformance(drivers.map((d) => d.user_id));
  const perfByDriver = new Map(driverPerf.map((p) => [p.driver_id, p]));
  const topDrivers = drivers
    .map((d) => ({ driver_id: d.user_id.toString(), name: d.full_name, ...perfByDriver.get(d.user_id) }))
    .filter((d) => d.completed_orders > 0)
    .sort((a, b) => b.completed_orders - a.completed_orders)
    .slice(0, 5);

  return {
    period_days: days,
    total_orders: totalOrders,
    total_revenue: totalRevenue,
    daily,
    top_stores: topStores,
    top_drivers: topDrivers,
    smart_assignment: smartAssignment,
    grouped_order_rate: groupedOrderRate,
    grouped_orders: groupedOrders
  };
}

module.exports = { computeAdminAnalytics };
