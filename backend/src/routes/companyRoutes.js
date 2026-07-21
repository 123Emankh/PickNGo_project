// src/routes/companyRoutes.js
const express = require('express');
const router = express.Router();
const { auth, authorize } = require('../middleware/auth');
const {
  listApprovedCompanies,
  getMyRoster,
  getJoinRequests,
  approveJoinRequest,
  rejectJoinRequest,
  removeDriver,
  setDriverActive
} = require('../controllers/companyController');

// عامة عن قصد: بتستخدم وقت تسجيل سائق جديد (قبل ما يكون عنده أي token)
router.get('/list', listApprovedCompanies);

// كل الراوتات الجاية محمية: لصاحب حساب الشركة بس (يتحقق منه الكونترولر نفسه)
router.use(auth, authorize('Driver'));

router.get('/roster', getMyRoster);
router.get('/join-requests', getJoinRequests);
router.post('/join-requests/:driverId/approve', approveJoinRequest);
router.post('/join-requests/:driverId/reject', rejectJoinRequest);
router.delete('/roster/:driverId', removeDriver);
router.patch('/roster/:driverId/active', setDriverActive);

module.exports = router;
