// src/routes/orderRoutes.js
const express = require('express');
const router = express.Router();
const { auth, authorize } = require('../middleware/auth');
const {
  createOrder,
  getMyOrders,
  getAvailableOrders,
  updateOrderStatus,
  getOrderTracking,
  getMyPendingOffer,
  respondToOrderOffer
} = require('../controllers/orderController');
const {
  getGroupDetail,
  acceptDeliveryGroup,
  respondToDeliveryGroupOffer
} = require('../controllers/deliveryGroupController');

// كل مسارات الطلبات محتاجة تسجيل دخول
router.post('/', auth, authorize('Customer'), createOrder);
router.get('/my', auth, getMyOrders);
router.get('/available', auth, authorize('Driver'), getAvailableOrders);
// ✅ Phase 3 - Smart Assignment: عرض تعيين ذكي معلّق على السائق الحالي
router.get('/offers/mine', auth, authorize('Driver'), getMyPendingOffer);
router.put('/:id/status', auth, updateOrderStatus);
router.post('/:id/offer/respond', auth, authorize('Driver'), respondToOrderOffer);
router.get('/:id/tracking', auth, getOrderTracking);

// ✅ Grouped Delivery (Smart Order Clustering): رحلة توصيل مجمّعة (أكتر من
// طلب لنفس الزبون من متاجر قريبة) - راجع groupingService.js/groupAssignmentService.js
router.get('/groups/:id', auth, getGroupDetail);
router.post('/groups/:id/accept', auth, authorize('Driver'), acceptDeliveryGroup);
router.post('/groups/:id/offer/respond', auth, authorize('Driver'), respondToDeliveryGroupOffer);

module.exports = router;
