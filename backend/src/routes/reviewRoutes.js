// src/routes/reviewRoutes.js
const express = require('express');
const router = express.Router();
const { auth, authorize } = require('../middleware/auth');
const {
  createReview,
  updateReview,
  deleteReview,
  getReviewForOrder,
  getMyReviewsForOrders,
  getProductReviews
} = require('../controllers/reviewController');

router.post('/', auth, authorize('Customer'), createReview);
router.put('/:id', auth, authorize('Customer'), updateReview);
// ✅ تقييد على مستوى الراوت لنفس الأدوار المسموحة فعليًا (Customer صاحب
// التقييم أو Admin) - كان مفتوح لأي دور مصادق عليه بالراوت (Restaurant/Driver
// كانوا يوصلوا للكونترولر ويترفضوا هناك بس، دفاع بطبقة متأخرة). الكونترولر
// لسا بيتحقق من الملكية الفعلية (تقييمي أنا أو أدمن).
router.delete('/:id', auth, authorize(['Customer', 'Admin']), deleteReview);
router.get('/order/:orderId', auth, getReviewForOrder);
router.get('/mine', auth, getMyReviewsForOrders);
// ✅ عامة زي /api/stores/:id/reviews - تقييمات منتج معيّن (تغذّي صفحة تفاصيل المنتج)
router.get('/product/:productId', getProductReviews);

module.exports = router;
