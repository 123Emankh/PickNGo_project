// src/controllers/loyaltyController.js
const { getMyLoyaltySummary, getLiveLoyaltySettings } = require('../services/loyaltyService');
const { User } = require('../models');

// ===========================
// 📌 GET /api/loyalty/me  (رصيدي وسجل حركاتي - Customer)
// ===========================
const getMyLoyalty = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const summary = await getMyLoyaltySummary(req.user.user_id, { page, limit });
    res.status(200).json({ success: true, ...summary });
  } catch (error) {
    console.error('❌ Get my loyalty error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching loyalty summary' });
  }
};

// ===========================
// 📌 POST /api/loyalty/preview-redemption  (معاينة خصم النقاط بدون حسم فعلي
// - يستخدمها الـ checkout لعرض قيمة الخصم قبل تأكيد الطلب)
// ===========================
const previewRedemption = async (req, res) => {
  try {
    const { points, cart_total } = req.body;
    if (!points || !cart_total) {
      return res.status(400).json({ success: false, message: 'points and cart_total are required' });
    }

    const settings = await getLiveLoyaltySettings();
    if (!settings.loyalty_enabled) {
      return res.status(400).json({ success: false, message: 'Loyalty points are not enabled' });
    }

    const requested = parseInt(points, 10);
    if (!Number.isInteger(requested) || requested <= 0) {
      return res.status(400).json({ success: false, message: 'points must be a positive whole number' });
    }

    const user = await User.findByPk(req.user.user_id, { attributes: ['loyalty_points'] });
    if (requested > user.loyalty_points) {
      return res.status(400).json({ success: false, message: 'Insufficient points balance', balance: user.loyalty_points });
    }

    const redeemRate = parseFloat(settings.points_redeem_rate) || 0;
    let discountAmount = Math.round(requested * redeemRate * 100) / 100;
    discountAmount = Math.min(discountAmount, parseFloat(cart_total));

    res.status(200).json({
      success: true,
      points_redeemed: requested,
      discount_amount: discountAmount,
      balance: user.loyalty_points
    });
  } catch (error) {
    console.error('❌ Preview points redemption error:', error);
    res.status(500).json({ success: false, message: 'Server error while previewing points redemption' });
  }
};

module.exports = {
  getMyLoyalty,
  previewRedemption
};
