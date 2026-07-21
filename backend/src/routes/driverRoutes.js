// src/routes/driverRoutes.js
const express = require('express');
const router = express.Router();
const { auth, authorize } = require('../middleware/auth');
const { setMyStatus, pingLocation, getMyPerformance } = require('../controllers/driverController');

router.use(auth, authorize('Driver'));

router.patch('/status', setMyStatus);
router.post('/location', pingLocation);
router.get('/performance', getMyPerformance);

module.exports = router;
