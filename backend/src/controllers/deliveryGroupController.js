// src/controllers/deliveryGroupController.js
//
// Grouped Delivery: نقاط الوصول للسائق (وأي طرف تاني له علاقة) لرؤية/قبول
// رحلة توصيل مجمّعة ككل. المسار الفعلي المستخدم اليوم بتطبيق السائق هو
// acceptDeliveryGroup (القبول اليدوي من قائمة الطلبات المتاحة - نفس فلسفة
// "قبول الطلب" الفردي الموجود بـ orderController.updateOrderStatus).
const { getIo } = require('../sockets');
const { Restaurant } = require('../models');
const {
  acceptGroupManually,
  respondToGroupOffer,
  withGroupContext,
  validSortedItems
} = require('../services/groupAssignmentService');

function formatGroup(group) {
  // ✅ validSortedItems (مش sortedItems الخام) - عنصر بدون طلب محمّل
  // (بيانات ناقصة/قديمة) بيتجاهل بدل ما يفجّر .map تحت بـ i.order.*
  const items = validSortedItems(group);
  return {
    group_id: group.group_id.toString(),
    status: group.status,
    driver_id: group.driver_id ? group.driver_id.toString() : null,
    assigned_at: group.assigned_at || null,
    assignment_type: group.assignment_type || null,
    offered_driver_id: group.offered_driver_id ? group.offered_driver_id.toString() : null,
    offer_expires_at: group.offer_expires_at || null,
    delivery_address: items[0] && items[0].order ? items[0].order.delivery_address : null,
    // ✅ نفس أسماء الحقول بالضبط يلي buildGroupInfoMap بـ orderController.js
    // بيرجعها بمصفوفة group_stores - عشان GroupStoreModel بالفرونت يقدر
    // يقرأ الاثنين بدون أي تفرّع
    stores: items.map((i) => ({
      order_id: i.order.order_id.toString(),
      order_status: i.order.status,
      restaurant_id: i.order.store ? i.order.store.restaurant_id.toString() : null,
      name: i.order.store ? i.order.store.name : null,
      address: i.order.store ? i.order.store.address : null,
      pickup_sequence: i.pickup_sequence,
      delivery_fee: parseFloat(i.order.delivery_fee || 0)
    }))
  };
}

// ===========================
// 📌 GET /api/orders/groups/:id  (تفاصيل رحلة مجمّعة - لشاشة السائق)
// ===========================
const getGroupDetail = async (req, res) => {
  try {
    const group = await withGroupContext(req.params.id);
    if (!group) return res.status(404).json({ success: false, message: 'Delivery group not found' });

    const items = validSortedItems(group);
    const { role, user_id } = req.user;
    let allowed = role === 'Admin';
    if (role === 'Driver') allowed = group.driver_id === user_id || group.offered_driver_id === user_id;
    else if (role === 'Customer') allowed = items.some((i) => i.order.customer_id === user_id);
    else if (role === 'Restaurant') {
      const store = await Restaurant.findOne({ where: { user_id } });
      allowed = !!store && items.some((i) => i.order.restaurant_id === store.restaurant_id);
    }

    if (!allowed) {
      return res.status(403).json({ success: false, message: 'Not authorized to view this delivery group' });
    }

    res.status(200).json({ success: true, group: formatGroup(group) });
  } catch (error) {
    console.error('❌ Get delivery group detail error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching delivery group' });
  }
};

// ===========================
// 📌 POST /api/orders/groups/:id/accept  (قبول يدوي - نفس "قبول الطلب" الفردي بس لكل الرحلة)
// ===========================
const acceptDeliveryGroup = async (req, res) => {
  try {
    const result = await acceptGroupManually(req.params.id, req.user.user_id, getIo());

    if (!result.success) {
      const messages = {
        NOT_FOUND: 'Delivery group not found',
        ALREADY_ASSIGNED: 'This delivery group already has a driver',
        NOT_READY: 'Not all stores in this group are ready yet',
        OFFERED_TO_ANOTHER_DRIVER: 'This delivery group is currently offered to another driver',
        MAX_ACTIVE_ORDERS_REACHED: 'You already have too many active orders. Deliver one before accepting another.'
      };
      return res.status(409).json({ success: false, code: result.code, message: messages[result.code] || 'Unable to accept delivery group' });
    }

    res.status(200).json({ success: true, message: 'Delivery group accepted', group: formatGroup(result.group) });
  } catch (error) {
    console.error('❌ Accept delivery group error:', error);
    res.status(500).json({ success: false, message: 'Server error while accepting delivery group' });
  }
};

// ===========================
// 📌 POST /api/orders/groups/:id/offer/respond  (قبول/رفض عرض تعيين ذكي على مستوى المجموعة)
// ===========================
const respondToDeliveryGroupOffer = async (req, res) => {
  try {
    const { action } = req.body;
    if (!['accept', 'reject'].includes(action)) {
      return res.status(400).json({ success: false, message: "action must be 'accept' or 'reject'" });
    }

    const result = await respondToGroupOffer(req.params.id, req.user.user_id, action, getIo());

    if (!result.success) {
      const messages = {
        NOT_FOUND: 'Delivery group not found',
        NOT_OFFERED: 'This delivery group is not currently offered to you',
        EXPIRED: 'This offer has expired'
      };
      return res.status(409).json({ success: false, code: result.code, message: messages[result.code] || 'Unable to respond to offer' });
    }

    res.status(200).json({
      success: true,
      message: action === 'accept' ? 'Delivery group accepted' : 'Delivery group rejected',
      group: formatGroup(result.group)
    });
  } catch (error) {
    console.error('❌ Respond to delivery group offer error:', error);
    res.status(500).json({ success: false, message: 'Server error while responding to delivery group offer' });
  }
};

module.exports = { getGroupDetail, acceptDeliveryGroup, respondToDeliveryGroupOffer };
