// src/controllers/favoriteController.js
const { Favorite, Restaurant, Product } = require('../models');
const { formatStore } = require('./storeController');

// ===========================
// 📌 GET /api/favorites  (قائمة المتاجر المفضلة لدى المستخدم الحالي)
// ===========================
const getFavorites = async (req, res) => {
  try {
    const favorites = await Favorite.findAll({
      where: { user_id: req.user.user_id },
      include: [{ model: Restaurant, as: 'store' }],
      order: [['created_at', 'DESC']]
    });

    res.status(200).json({
      success: true,
      stores: favorites
        .filter((f) => f.store)
        .map((f) => formatStore(f.store, { isFavorited: true }))
    });
  } catch (error) {
    console.error('❌ Get favorites error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching favorites' });
  }
};

// ===========================
// 📌 POST /api/favorites/:storeId  (إضافة متجر للمفضلة - idempotent)
// ===========================
const addFavorite = async (req, res) => {
  try {
    const store = await Restaurant.findByPk(req.params.storeId);
    if (!store) {
      return res.status(404).json({ success: false, message: 'Store not found' });
    }

    const [favorite] = await Favorite.findOrCreate({
      where: { user_id: req.user.user_id, restaurant_id: req.params.storeId },
      defaults: { user_id: req.user.user_id, restaurant_id: req.params.storeId }
    });

    res.status(200).json({
      success: true,
      message: 'Store added to favorites',
      favorite_id: favorite.favorite_id
    });
  } catch (error) {
    console.error('❌ Add favorite error:', error);
    res.status(500).json({ success: false, message: 'Server error while adding favorite' });
  }
};

// ===========================
// 📌 DELETE /api/favorites/:storeId
// ===========================
const removeFavorite = async (req, res) => {
  try {
    await Favorite.destroy({
      where: { user_id: req.user.user_id, restaurant_id: req.params.storeId }
    });

    res.status(200).json({ success: true, message: 'Store removed from favorites' });
  } catch (error) {
    console.error('❌ Remove favorite error:', error);
    res.status(500).json({ success: false, message: 'Server error while removing favorite' });
  }
};

// ===========================
// 📌 POST /api/favorites/products/:productId  (إضافة منتج للمفضلة - idempotent)
// ===========================
const addFavoriteProduct = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.productId);
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found' });
    }

    const [favorite] = await Favorite.findOrCreate({
      where: { user_id: req.user.user_id, product_id: req.params.productId },
      defaults: { user_id: req.user.user_id, product_id: req.params.productId }
    });

    res.status(200).json({
      success: true,
      message: 'Product added to favorites',
      favorite_id: favorite.favorite_id
    });
  } catch (error) {
    console.error('❌ Add favorite product error:', error);
    res.status(500).json({ success: false, message: 'Server error while adding favorite' });
  }
};

// ===========================
// 📌 DELETE /api/favorites/products/:productId
// ===========================
const removeFavoriteProduct = async (req, res) => {
  try {
    await Favorite.destroy({
      where: { user_id: req.user.user_id, product_id: req.params.productId }
    });

    res.status(200).json({ success: true, message: 'Product removed from favorites' });
  } catch (error) {
    console.error('❌ Remove favorite product error:', error);
    res.status(500).json({ success: false, message: 'Server error while removing favorite' });
  }
};

module.exports = {
  getFavorites,
  addFavorite,
  removeFavorite,
  addFavoriteProduct,
  removeFavoriteProduct
};
