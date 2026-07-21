// src/routes/aiRoutes.js
const express = require('express');
const router = express.Router();
const { auth } = require('../middleware/auth');
const { aiLimiter } = require('../middleware/rateLimit');
const { sendMessage, getHistory, deleteHistory } = require('../controllers/aiController');

// أي مستخدم مسجّل دخول (بكل الأدوار) - نطاق الأدوات المسموحة يتحدد داخل
// aiTools.getToolsForRole حسب req.user.role، مش هون
router.use(auth);

router.post('/message', aiLimiter, sendMessage);
router.get('/history', getHistory);
router.delete('/history', deleteHistory);

module.exports = router;
