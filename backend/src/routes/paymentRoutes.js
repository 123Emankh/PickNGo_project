// src/routes/paymentRoutes.js
const express = require('express');
const router = express.Router();
const { auth, authorize } = require('../middleware/auth');
const {
  createCheckoutSession,
  renderWidgetPage,
  handleReturn,
  verifyAndGetStatus
} = require('../controllers/paymentController');

// محمية: فقط الزبون صاحب الطلب يقدر ينشئ جلسة دفع أو يتحقق من نتيجتها
router.post('/checkout', auth, authorize('Customer'), createCheckoutSession);
router.get('/status/:orderId', auth, authorize('Customer'), verifyAndGetStatus);

// عامة عن قصد: بتفتح جوا WebView بدون أي Authorization header ممكن (راجع الملاحظات بالكونترولر)
router.get('/widget/:checkoutId', renderWidgetPage);
router.get('/return', handleReturn);

module.exports = router;
