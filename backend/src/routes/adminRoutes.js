// src/routes/adminRoutes.js
const express = require('express');
const router = express.Router();
const { auth, authorize } = require('../middleware/auth');
const {
  getDashboardStats,
  getStores,
  approveStore,
  rejectStore,
  toggleFeaturedStore,
  deleteStore,
  getDeliveryCompanies,
  approveCompany,
  rejectCompany,
  getAllCoupons,
  getOrders,
  getOrderDetail,
  getUsers,
  updateUserStatus,
  getDrivers,
  getCategories,
  getDeliveryGroups,
  getSystemSettings,
  updateSystemSettings,
  getLiveMapData,
  simulateGrouping,
  getDriverPerformance,
  getStoreAnalytics,
  getAnalyticsDashboard
} = require('../controllers/adminController');

// كل راوتات الأدمن محمية: لازم تسجيل دخول + role === 'Admin'
router.use(auth, authorize('Admin'));

router.get('/dashboard', getDashboardStats);

router.get('/stores', getStores);
router.put('/stores/:id/approve', approveStore);
router.put('/stores/:id/reject', rejectStore);
router.patch('/stores/:id/featured', toggleFeaturedStore);
router.delete('/stores/:id', deleteStore);

router.get('/companies', getDeliveryCompanies);
router.put('/companies/:id/approve', approveCompany);
router.put('/companies/:id/reject', rejectCompany);

router.get('/coupons', getAllCoupons);

router.get('/orders', getOrders);
router.get('/orders/:id', getOrderDetail);

router.get('/users', getUsers);
router.patch('/users/:id/status', updateUserStatus);
router.get('/drivers', getDrivers);
router.get('/drivers/:id/performance', getDriverPerformance);

router.get('/categories', getCategories);

router.get('/stores/:id/analytics', getStoreAnalytics);
router.get('/analytics', getAnalyticsDashboard);

router.get('/delivery-groups', getDeliveryGroups);

router.get('/settings', getSystemSettings);
router.put('/settings', updateSystemSettings);

router.get('/live-map', getLiveMapData);
router.post('/simulate-grouping', simulateGrouping);

module.exports = router;
