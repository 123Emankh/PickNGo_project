// src/routes/loyaltyRoutes.js
const express = require('express');
const router = express.Router();
const { auth, authorize } = require('../middleware/auth');
const { getMyLoyalty, previewRedemption } = require('../controllers/loyaltyController');

router.get('/me', auth, authorize('Customer'), getMyLoyalty);
router.post('/preview-redemption', auth, authorize('Customer'), previewRedemption);

module.exports = router;
