// src/controllers/couponController.js
const { Op } = require('sequelize');
const { Coupon, Restaurant } = require('../models');
const { resolveCoupon, CouponError } = require('../services/couponService');

function formatCoupon(coupon) {
  return {
    id: coupon.coupon_id.toString(),
    restaurant_id: coupon.restaurant_id ? coupon.restaurant_id.toString() : null,
    code: coupon.code,
    discount_type: coupon.discount_type,
    discount_value: parseFloat(coupon.discount_value),
    min_order_amount: parseFloat(coupon.min_order_amount || 0),
    max_discount_amount: coupon.max_discount_amount !== null ? parseFloat(coupon.max_discount_amount) : null,
    valid_from: coupon.valid_from,
    valid_until: coupon.valid_until,
    usage_limit: coupon.usage_limit,
    usage_limit_per_customer: coupon.usage_limit_per_customer,
    used_count: coupon.used_count,
    is_active: coupon.is_active
  };
}

// ===========================
// 📌 POST /api/coupons/validate  (معاينة كود خصم قبل تقديم الطلب - Customer)
// ===========================
const validateCoupon = async (req, res) => {
  try {
    const { code, restaurant_id, cart_total } = req.body;
    if (!code || !restaurant_id || cart_total === undefined) {
      return res.status(400).json({ success: false, message: 'code, restaurant_id and cart_total are required' });
    }

    const { discountAmount } = await resolveCoupon({
      code,
      restaurantId: parseInt(restaurant_id),
      customerId: req.user.user_id,
      cartTotal: cart_total
    });

    res.status(200).json({ success: true, discount_amount: discountAmount });
  } catch (error) {
    if (error instanceof CouponError) {
      return res.status(error.status).json({ success: false, message: error.message });
    }
    console.error('❌ Validate coupon error:', error);
    res.status(500).json({ success: false, message: 'Server error while validating coupon' });
  }
};

// ===========================
// 📌 POST /api/coupons  (إنشاء كوبون - صاحب متجر لمتجره فقط، أو أدمن لأي متجر/عام)
// ===========================
const createCoupon = async (req, res) => {
  try {
    const {
      code, discount_type, discount_value, min_order_amount, max_discount_amount,
      valid_from, valid_until, usage_limit, usage_limit_per_customer
    } = req.body;

    if (!code || !discount_type || discount_value === undefined) {
      return res.status(400).json({ success: false, message: 'code, discount_type and discount_value are required' });
    }
    if (!['Percentage', 'Fixed'].includes(discount_type)) {
      return res.status(400).json({ success: false, message: 'discount_type must be Percentage or Fixed' });
    }
    if (discount_value <= 0 || (discount_type === 'Percentage' && discount_value > 100)) {
      return res.status(400).json({ success: false, message: 'Invalid discount_value' });
    }

    let restaurantId;
    if (req.user.role === 'Restaurant') {
      // ✅ صاحب المتجر ما بقدر يحدد restaurant_id بنفسه - لازم يكون متجره هو بس
      const store = await Restaurant.findOne({ where: { user_id: req.user.user_id } });
      if (!store) {
        return res.status(404).json({ success: false, message: 'You do not have a store yet' });
      }
      restaurantId = store.restaurant_id;
    } else {
      // Admin: بيقدر يحدد restaurant_id (كوبون لمتجر معيّن) أو يسيبه فاضي (كوبون عام)
      restaurantId = req.body.restaurant_id ? parseInt(req.body.restaurant_id) : null;
    }

    const coupon = await Coupon.create({
      restaurant_id: restaurantId,
      created_by: req.user.user_id,
      code: code.toUpperCase(),
      discount_type,
      discount_value,
      min_order_amount: min_order_amount || 0,
      max_discount_amount: max_discount_amount ?? null,
      valid_from: valid_from || null,
      valid_until: valid_until || null,
      usage_limit: usage_limit ?? null,
      usage_limit_per_customer: usage_limit_per_customer || 1
    });

    res.status(201).json({ success: true, message: 'Coupon created', coupon: formatCoupon(coupon) });
  } catch (error) {
    if (error.name === 'SequelizeUniqueConstraintError') {
      return res.status(409).json({ success: false, message: 'This coupon code already exists' });
    }
    console.error('❌ Create coupon error:', error);
    res.status(500).json({ success: false, message: 'Server error while creating coupon' });
  }
};

// ===========================
// 📌 GET /api/coupons/active  (كوبونات فعّالة حاليًا للعرض بشاشة "كوبونات خصم" - Customer/عام)
// query params (اختيارية): restaurant_id (لو محدد، بس كوبونات هاد المتجر)
// نفس منطق نافذة الصلاحية (valid_from/valid_until) الموجود بـ getDiscountLabels بالضبط
// ===========================
const getActiveCoupons = async (req, res) => {
  try {
    const { restaurant_id } = req.query;
    const now = new Date();

    const where = {
      is_active: true,
      [Op.and]: [
        { [Op.or]: [{ valid_from: null }, { valid_from: { [Op.lte]: now } }] },
        { [Op.or]: [{ valid_until: null }, { valid_until: { [Op.gte]: now } }] }
      ]
    };
    if (restaurant_id) where.restaurant_id = parseInt(restaurant_id);

    const coupons = await Coupon.findAll({
      where,
      include: [{ model: Restaurant, as: 'store', attributes: ['restaurant_id', 'name'] }],
      order: [['created_at', 'DESC']]
    });

    res.status(200).json({
      success: true,
      coupons: coupons.map((c) => ({
        ...formatCoupon(c),
        store_name: c.store ? c.store.name : null
      }))
    });
  } catch (error) {
    console.error('❌ Get active coupons error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching active coupons' });
  }
};

// ===========================
// 📌 GET /api/coupons/my  (كوبونات متجري أنا - Restaurant فقط)
// ===========================
const getMyCoupons = async (req, res) => {
  try {
    const store = await Restaurant.findOne({ where: { user_id: req.user.user_id } });
    if (!store) {
      return res.status(200).json({ success: true, coupons: [] });
    }
    const coupons = await Coupon.findAll({
      where: { restaurant_id: store.restaurant_id },
      order: [['created_at', 'DESC']]
    });
    res.status(200).json({ success: true, coupons: coupons.map(formatCoupon) });
  } catch (error) {
    console.error('❌ Get my coupons error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching coupons' });
  }
};

// ===========================
// 📌 PUT /api/coupons/:id  (تعديل كوبون - صاحب المتجر أو الأدمن)
// ===========================
const updateCoupon = async (req, res) => {
  try {
    const coupon = await Coupon.findByPk(req.params.id);
    if (!coupon) {
      return res.status(404).json({ success: false, message: 'Coupon not found' });
    }

    if (req.user.role !== 'Admin') {
      const store = await Restaurant.findOne({ where: { user_id: req.user.user_id } });
      if (!store || coupon.restaurant_id !== store.restaurant_id) {
        return res.status(403).json({ success: false, message: 'This coupon does not belong to your store' });
      }
    }

    const allowedFields = [
      'discount_type', 'discount_value', 'min_order_amount', 'max_discount_amount',
      'valid_from', 'valid_until', 'usage_limit', 'usage_limit_per_customer', 'is_active'
    ];
    const updates = {};
    for (const field of allowedFields) {
      if (req.body[field] !== undefined) updates[field] = req.body[field];
    }

    await coupon.update(updates);
    res.status(200).json({ success: true, message: 'Coupon updated', coupon: formatCoupon(coupon) });
  } catch (error) {
    console.error('❌ Update coupon error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating coupon' });
  }
};

module.exports = { validateCoupon, createCoupon, getActiveCoupons, getMyCoupons, updateCoupon, formatCoupon };
