// src/routes/favoriteRoutes.js
const express = require('express');
const router = express.Router();
const { auth } = require('../middleware/auth');
const {
  getFavorites,
  addFavorite,
  removeFavorite,
  addFavoriteProduct,
  removeFavoriteProduct
} = require('../controllers/favoriteController');

// كل راوتات المفضلة محمية - لازم تسجيل دخول
router.use(auth);

router.get('/', getFavorites);

// ⚠️ لازم تكون قبل /:storeId وإلا Express رح يفهم "products" كـ storeId
router.post('/products/:productId', addFavoriteProduct);
router.delete('/products/:productId', removeFavoriteProduct);

router.post('/:storeId', addFavorite);
router.delete('/:storeId', removeFavorite);

module.exports = router;
