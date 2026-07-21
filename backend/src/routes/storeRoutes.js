// src/routes/storeRoutes.js
const express = require('express');
const router = express.Router();
const { auth, optionalAuth, authorize } = require('../middleware/auth');
const {
  getCategories,
  getStores,
  getStoreDetail,
  createStore,
  getMyStore,
  updateMyStore,
  createProduct,
  updateProduct,
  deleteProduct,
  getStoreReviews,
  getPopularProducts,
  getNewArrivals,
  getMyStoreAnalytics
} = require('../controllers/storeController');

// عامة (متاحة بدون تسجيل دخول — تصفح المتاجر)
router.get('/categories', getCategories);
router.get('/:id/reviews', getStoreReviews);

// ⚠️ لازم /my-store تكون قبل /:id وإلا Express رح يفهمها كـ id="my-store"
router.get('/my-store', auth, authorize('Restaurant'), getMyStore);
router.put('/my-store', auth, authorize('Restaurant'), updateMyStore);
router.get('/my-store/analytics', auth, authorize('Restaurant'), getMyStoreAnalytics);

// ⚠️ لازم تكون قبل /:id لنفس سبب /my-store (Express بيفهمها كـ id="popular-products")
router.get('/popular-products', getPopularProducts);
router.get('/new-arrivals', getNewArrivals);

// optionalAuth: تصفح عام، بس لو في توكن صالح منحدد is_favorited لكل متجر
router.get('/', optionalAuth, getStores);
router.get('/:id', optionalAuth, getStoreDetail);

// محتاجة تسجيل دخول + دور "Restaurant" (صاحب متجر)
router.post('/', auth, authorize('Restaurant'), createStore);
router.post('/:id/products', auth, authorize('Restaurant'), createProduct);
router.put('/:id/products/:productId', auth, authorize('Restaurant'), updateProduct);
router.delete('/:id/products/:productId', auth, authorize('Restaurant'), deleteProduct);

module.exports = router;
