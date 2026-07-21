// src/routes/couponRoutes.js
const express = require('express');
const router = express.Router();
const { auth, authorize } = require('../middleware/auth');
const {
  validateCoupon,
  createCoupon,
  getActiveCoupons,
  getMyCoupons,
  updateCoupon
} = require('../controllers/couponController');

router.get('/active', getActiveCoupons);
router.post('/validate', auth, authorize('Customer'), validateCoupon);
router.post('/', auth, authorize(['Restaurant', 'Admin']), createCoupon);
router.get('/my', auth, authorize('Restaurant'), getMyCoupons);
router.put('/:id', auth, authorize(['Restaurant', 'Admin']), updateCoupon);

module.exports = router;
