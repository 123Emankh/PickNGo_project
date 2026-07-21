// src/services/loyaltyService.js
//
// نظام النقاط (Loyalty & Rewards): يكسب الزبون نقاط عند تسليم طلبه فعليًا،
// ويقدر يستبدلها كخصم بالـ checkout. نفس فلسفة الملفات المشابهة بالمشروع:
//   - إعدادات حية من system_settings (getLiveLoyaltySettings) - نفس نمط
//     groupingService.getLiveGroupingSettings بالضبط.
//   - دفتر أستاذ (LoyaltyTransaction) هو مصدر الحقيقة الوحيد للرصيد -
//     User.loyalty_points نسخة مخزّنة/مكافئة بس، تتحدث بنفس المعاملة دايمًا.
//   - كل عملية (كسب/استبدال/عكس/استرجاع) بمعاملة ذرّية مع قفل صف المستخدم
//     (SELECT ... FOR UPDATE) - يمنع سباق تزامن يخلي رصيد سالب أو مزدوج.
const { Op } = require('sequelize');
const { User, Order, LoyaltyTransaction, SystemSettings, sequelize } = require('../models');
const LOYALTY_DEFAULTS = require('./loyalty/config');
const { createNotification } = require('./notificationService');

class LoyaltyError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

// ✅ إعدادات Loyalty الحية من لوحة الأدمن (system_settings) - قراءة طازة بكل
// استدعاء، نفس منطق groupingService.getLiveGroupingSettings بالضبط
async function getLiveLoyaltySettings(transaction) {
  const [settings] = await SystemSettings.findOrCreate({
    where: { id: 1 },
    defaults: {
      loyalty_enabled: LOYALTY_DEFAULTS.LOYALTY_ENABLED,
      points_earn_rate: LOYALTY_DEFAULTS.POINTS_EARN_RATE,
      points_redeem_rate: LOYALTY_DEFAULTS.POINTS_REDEEM_RATE
    },
    transaction
  });
  return settings;
}

function computeEarnedPoints(finalAmount, settings) {
  const rate = parseFloat(settings.points_earn_rate) || 0;
  // ✅ نطرح دايمًا (Math.floor) - ما منمنح نقطة كسر عشان الرصيد يضل عدد صحيح دايمًا
  return Math.max(0, Math.floor(parseFloat(finalAmount) * rate));
}

// ✅ يكتب حركة بدفتر الأستاذ ويحدّث الرصيد المخزّن بنفس المعاملة - نقطة
// الكتابة الوحيدة على User.loyalty_points بكل الملف، لضمان تطابقه دايمًا
// مع مجموع الحركات (نفس ضمانة recalculateStoreRating للتقييمات).
async function writeLedgerEntry({ userId, orderId, type, points, description }, transaction) {
  // ✅ قفل صف المستخدم (SELECT ... FOR UPDATE) - يسلسل أي عمليتين متزامنتين
  // على نفس المستخدم (كسب/استبدال بنفس اللحظة) بدل ما يقرؤوا نفس الرصيد
  // القديم مع بعض ويكتبوا نتيجة خاطئة (سباق تزامن كلاسيكي على رصيد رقمي)
  const user = await User.findByPk(userId, { transaction, lock: transaction.LOCK.UPDATE });
  if (!user) throw new LoyaltyError('User not found', 404);

  const newBalance = user.loyalty_points + points;
  if (newBalance < 0) {
    throw new LoyaltyError('Insufficient points balance', 400);
  }

  await LoyaltyTransaction.create({
    user_id: userId,
    order_id: orderId || null,
    type,
    points,
    balance_after: newBalance,
    description: description || null
  }, { transaction });

  await user.update({ loyalty_points: newBalance }, { transaction });
  return newBalance;
}

/**
 * يمنح نقاط طلب Delivered - Idempotent: ما بيمنح مرتين لنفس الطلب (يفحص
 * order.points_earned قبل أي إشي). لازم تُنادى جوا نفس معاملة تحديث حالة
 * الطلب (updateOrderStatus) - فشلها لازم يفشّل التحديث كامل، مش fire-and-forget
 * (بعكس الإشعارات) لأنه عملية مالية بالمعنى الواسع، لازم تضل متسقة مع حالة الطلب.
 */
async function awardPointsForOrder(order, transaction) {
  // ✅ دفاع مضاعف (defense in depth): handleOrderStatusChange فوق هو المسؤول
  // عن استدعاء هاي الدالة بس لما الطلب يدخل Delivered فعليًا، بس ما منوثق
  // بالمنادي بس - أي كود مستقبلي ينادي هاي الدالة مباشرة على طلب مش
  // Delivered لازم ما يمنح شي، نفس فلسفة hasValidItems/passesHardFilters
  // بمحرك التعيين الذكي (فحص صريح بدل الوثوق بالسياق الخارجي)
  if (order.status !== 'Delivered') return 0;

  const settings = await getLiveLoyaltySettings(transaction);
  if (!settings.loyalty_enabled) return 0;
  if (order.points_earned > 0) return 0; // ✅ سبق مُنحت - منع الاحتساب المزدوج

  // ✅ لا نقاط لطلب بطاقة دفعه فشل فعليًا (منع استغلال) - الدفع النقدي
  // (Cash) ما إله payment_status رقمي حقيقي بهاد المشروع (يضل Pending دايمًا)
  // فما منعاقبه؛ بس بطاقة صريحًا Failed لازم تُستبعد.
  if (order.payment_status === 'Failed') return 0;

  const points = computeEarnedPoints(order.final_amount, settings);
  if (points <= 0) return 0;

  await writeLedgerEntry({
    userId: order.customer_id,
    orderId: order.order_id,
    type: 'Earned',
    points,
    description: `طلب #${order.order_number} تم توصيله`
  }, transaction);

  order.points_earned = points;
  order.points_earned_at = new Date();
  await order.save({ transaction });
  return points;
}

/**
 * يسحب نقاط طلب رجع عن Delivered (إلغاء بعد التسليم أو إعادة فتح إدارية) -
 * Idempotent: ما بيسحب شي لو ما كان في نقاط مكسوبة أصلًا لهاد الطلب.
 * لو الطلب يصير Delivered مرة تانية لاحقًا (بعد إعادة فتح)، points_earned
 * بيرجع صفر فمنطق awardPointsForOrder فوق بيسمح بمنح جديد صحيح (مش مزدوج).
 */
async function reverseEarnedPointsForOrder(order, transaction) {
  if (!order.points_earned || order.points_earned <= 0) return;

  const pointsToReverse = order.points_earned;
  await writeLedgerEntry({
    userId: order.customer_id,
    orderId: order.order_id,
    type: 'Reversed',
    points: -pointsToReverse,
    description: `سحب نقاط طلب #${order.order_number} (رجع عن التسليم)`
  }, transaction);

  order.points_earned = 0;
  order.points_earned_at = null;
  await order.save({ transaction });
}

/**
 * يتحقق من صلاحية طلب استبدال نقاط ويحسم النقاط فورًا (جوا نفس معاملة
 * إنشاء الطلب) - يرمي LoyaltyError (مع .status) لو مش صالح، بنفس نمط
 * couponService.resolveCoupon/CouponError تمامًا. الفحص والحسم بنفس القفل/
 * المعاملة يمنع سباق تزامن (طلبين بنفس اللحظة يستبدلوا نفس الرصيد مرتين).
 * @returns {Promise<{pointsRedeemed: number, discountAmount: number}>}
 */
async function resolvePointsRedemption({ userId, requestedPoints, cartTotal, transaction }) {
  const settings = await getLiveLoyaltySettings(transaction);
  if (!settings.loyalty_enabled) {
    throw new LoyaltyError('Loyalty points are not enabled', 400);
  }

  const points = parseInt(requestedPoints, 10);
  if (!Number.isInteger(points) || points <= 0) {
    throw new LoyaltyError('redeem_points must be a positive whole number', 400);
  }

  const redeemRate = parseFloat(settings.points_redeem_rate) || 0;
  let discountAmount = Math.round(points * redeemRate * 100) / 100;
  // ✅ ما منخصم أكتر من قيمة الطلب نفسها - نفس فحص resolveCoupon بالضبط
  discountAmount = Math.min(discountAmount, parseFloat(cartTotal));

  // ✅ الحسم الفعلي (بيرمي LoyaltyError لو الرصيد مش كافي - نفس فحص
  // newBalance < 0 بـ writeLedgerEntry، جوا نفس القفل)
  await writeLedgerEntry({
    userId,
    orderId: null, // ✅ order_id لسا مش موجود (الطلب لسا ما انخلق) - بنحدّثه بعد الإنشاء
    type: 'Redeemed',
    points: -points,
    description: 'استبدال نقاط بالـ checkout'
  }, transaction);

  return { pointsRedeemed: points, discountAmount };
}

// ✅ بعد إنشاء الطلب فعليًا (order_id صار معروف) - بس نربط order_id بحركة
// الاستبدال يلي انكتبت فوق (بدل ما تضل يتيمة order_id=null بالدفتر)
async function linkRedemptionToOrder(userId, orderId, transaction) {
  await LoyaltyTransaction.update(
    { order_id: orderId },
    {
      where: { user_id: userId, order_id: null, type: 'Redeemed' },
      order: [['transaction_id', 'DESC']],
      limit: 1,
      transaction
    }
  );
}

/**
 * يرجّع نقاط استبدال طلب انلغى (Idempotent عبر points_redemption_refunded).
 */
async function refundRedeemedPointsForOrder(order, transaction) {
  if (!order.points_redeemed || order.points_redeemed <= 0) return;
  if (order.points_redemption_refunded) return;

  await writeLedgerEntry({
    userId: order.customer_id,
    orderId: order.order_id,
    type: 'Refunded',
    points: order.points_redeemed,
    description: `إرجاع نقاط طلب #${order.order_number} الملغي`
  }, transaction);

  order.points_redemption_refunded = true;
  await order.save({ transaction });
}

/**
 * ملخص نقاط المستخدم الحالي - الرصيد + سجل الحركات (صفحات) لشاشة "نقاطي"
 */
async function getMyLoyaltySummary(userId, { page = 1, limit = 20 } = {}) {
  const user = await User.findByPk(userId, { attributes: ['loyalty_points'] });
  const { rows, count } = await LoyaltyTransaction.findAndCountAll({
    where: { user_id: userId },
    order: [['created_at', 'DESC']],
    limit: Math.min(50, Math.max(1, limit)),
    offset: (Math.max(1, page) - 1) * Math.min(50, Math.max(1, limit))
  });

  return {
    balance: user ? user.loyalty_points : 0,
    transactions: rows.map((tx) => ({
      id: tx.transaction_id.toString(),
      order_id: tx.order_id ? tx.order_id.toString() : null,
      type: tx.type,
      points: tx.points,
      balance_after: tx.balance_after,
      description: tx.description,
      created_at: tx.created_at
    })),
    total: count,
    page,
    limit
  };
}

/**
 * نقطة دخول واحدة لكل تأثيرات تغيّر حالة طلب على نظام النقاط - تُنادى من
 * orderController.updateOrderStatus لكل من الطلب الأساسي وأي "أعضاء شقيقين"
 * برحلة توصيل مجمّعة بيتسلّموا بنفس اللحظة (راجع سيناريو siblingsToDeliver).
 * كل تأثير بمعاملته الذرّية الخاصة - فشل مؤقت بواحد ما يوقف الباقي، وقفل
 * صف المستخدم (writeLedgerEntry) بيضمن عدم تضارب لو أكتر من طلب لنفس
 * الزبون بيتسلّم بنفس اللحظة بالضبط (رحلة مجمّعة).
 */
async function handleOrderStatusChange(order, previousStatus, newStatus, io = null) {
  if (newStatus === 'Delivered' && previousStatus !== 'Delivered') {
    const pointsAwarded = await sequelize.transaction((t) => awardPointsForOrder(order, t));
    // ✅ باج كان موجود: كسب نقاط ما كان يبلّغ الزبون بأي إشعار - كان النظام
    // كامل بدون أي إشعار Loyalty إطلاقًا. بس لو فعليًا انمنحت نقاط (مش 0،
    // زي حالة تعطيل النظام أو طلب سبق كُسب عليه)
    if (pointsAwarded > 0) {
      createNotification({
        userId: order.customer_id,
        title: 'نقاط جديدة! 🎉',
        body: `كسبت ${pointsAwarded} نقطة من طلبك #${order.order_number}`,
        type: 'LoyaltyEarned',
        relatedType: 'Order',
        relatedId: order.order_id,
        io
      }).catch((err) => console.error('❌ createNotification (LoyaltyEarned) error:', err));
    }
  } else if (previousStatus === 'Delivered' && newStatus !== 'Delivered') {
    await sequelize.transaction((t) => reverseEarnedPointsForOrder(order, t));
  }

  if (newStatus === 'Cancelled') {
    await sequelize.transaction((t) => refundRedeemedPointsForOrder(order, t));
  }
}

module.exports = {
  LoyaltyError,
  getLiveLoyaltySettings,
  computeEarnedPoints,
  awardPointsForOrder,
  reverseEarnedPointsForOrder,
  resolvePointsRedemption,
  linkRedemptionToOrder,
  refundRedeemedPointsForOrder,
  handleOrderStatusChange,
  getMyLoyaltySummary
};
