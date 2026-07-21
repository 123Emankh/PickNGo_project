// src/controllers/recommendationController.js
const { getRecommendedStores, getRecommendedProducts } = require('../services/analytics/recommendationService');

// ===========================
// 📌 GET /api/recommendations/stores?lat=&lng=&limit=  (Recommended Stores)
// ===========================
const getStoresRecommendation = async (req, res) => {
  try {
    const lat = req.query.lat !== undefined ? parseFloat(req.query.lat) : undefined;
    const lng = req.query.lng !== undefined ? parseFloat(req.query.lng) : undefined;
    const limit = req.query.limit ? parseInt(req.query.limit, 10) : 10;

    const stores = await getRecommendedStores(
      req.user.user_id,
      { lat: Number.isFinite(lat) ? lat : undefined, lng: Number.isFinite(lng) ? lng : undefined },
      limit
    );

    res.status(200).json({ success: true, stores });
  } catch (error) {
    console.error('❌ Get recommended stores error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching recommended stores' });
  }
};

// ===========================
// 📌 GET /api/recommendations/products?limit=  (Recommended Products)
// ===========================
const getProductsRecommendation = async (req, res) => {
  try {
    const limit = req.query.limit ? parseInt(req.query.limit, 10) : 10;
    const products = await getRecommendedProducts(req.user.user_id, limit);
    res.status(200).json({ success: true, products });
  } catch (error) {
    console.error('❌ Get recommended products error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching recommended products' });
  }
};

module.exports = { getStoresRecommendation, getProductsRecommendation };
