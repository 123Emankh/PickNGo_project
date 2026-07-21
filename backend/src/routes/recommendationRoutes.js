// src/routes/recommendationRoutes.js
const express = require('express');
const router = express.Router();
const { auth } = require('../middleware/auth');
const { getStoresRecommendation, getProductsRecommendation } = require('../controllers/recommendationController');

// أي مستخدم مسجّل دخول (عادةً Customer) - التوصية مبنية على طلباته/مفضّلته الشخصية
router.use(auth);

router.get('/stores', getStoresRecommendation);
router.get('/products', getProductsRecommendation);

module.exports = router;
