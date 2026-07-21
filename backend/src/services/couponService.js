// src/services/couponService.js
// المكان الوحيد يلي فيه منطق التحقق من صلاحية كوبون - يستخدمه كل من نقطة
// المعاينة (validate) و createOrder، حتى ما ينحرفوا عن بعض بمرور الوقت.
const { Coupon, CouponRedemption } = require('../models');

class CouponError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

/**
 * يتحقق من صلاحية كود كوبون لطلب معيّن ويحسب مبلغ الخصم الفعلي.
 * بيرمي CouponError (مع .status) لو الكوبون مش صالح لأي سبب.
 * @returns {Promise<{coupon: Coupon, discountAmount: number}>}
 */
async function resolveCoupon({ code, restaurantId, customerId, cartTotal, transaction }) {
  // ✅ لو جوا ترانزاكشن (createOrder)، منقفل الصف عشان نمنع سباق بين طلبين
  // بيستخدموا نفس الكوبون بنفس اللحظة وكلاهما يعدّي فحص usage_limit
  const coupon = await Coupon.findOne({
    where: { code: code.toUpperCase(), is_active: true },
    transaction,
    ...(transaction ? { lock: transaction.LOCK.UPDATE } : {})
  });

  if (!coupon) {
    throw new CouponError('Invalid coupon code', 404);
  }

  if (coupon.restaurant_id !== null && coupon.restaurant_id !== restaurantId) {
    throw new CouponError('This coupon is not valid for this store', 400);
  }

  const now = new Date();
  if (coupon.valid_from && now < new Date(coupon.valid_from)) {
    throw new CouponError('This coupon is not active yet', 400);
  }
  if (coupon.valid_until && now > new Date(coupon.valid_until)) {
    throw new CouponError('This coupon has expired', 400);
  }

  if (parseFloat(cartTotal) < parseFloat(coupon.min_order_amount || 0)) {
    throw new CouponError(`Minimum order amount for this coupon is ${coupon.min_order_amount}`, 400);
  }

  if (coupon.usage_limit !== null && coupon.used_count >= coupon.usage_limit) {
    throw new CouponError('This coupon has reached its usage limit', 400);
  }

  const customerUsageCount = await CouponRedemption.count({
    where: { coupon_id: coupon.coupon_id, customer_id: customerId },
    transaction
  });
  if (coupon.usage_limit_per_customer !== null && customerUsageCount >= coupon.usage_limit_per_customer) {
    throw new CouponError('You have already used this coupon', 400);
  }

  let discountAmount;
  if (coupon.discount_type === 'Percentage') {
    discountAmount = parseFloat(cartTotal) * (parseFloat(coupon.discount_value) / 100);
    if (coupon.max_discount_amount !== null) {
      discountAmount = Math.min(discountAmount, parseFloat(coupon.max_discount_amount));
    }
  } else {
    discountAmount = parseFloat(coupon.discount_value);
  }
  // ما بنخصم أكتر من قيمة الطلب نفسها
  discountAmount = Math.min(discountAmount, parseFloat(cartTotal));

  return { coupon, discountAmount: Math.round(discountAmount * 100) / 100 };
}

module.exports = { resolveCoupon, CouponError };
