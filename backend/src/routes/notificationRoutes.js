// src/routes/notificationRoutes.js
const express = require('express');
const router = express.Router();
const { auth } = require('../middleware/auth');
const { getMyNotifications, markAsRead, markAllAsRead } = require('../controllers/notificationController');

// كل المسارات لأي مستخدم مسجّل دخول (بغض النظر عن الدور) - كل واحد يشوف إشعاراته بس
router.use(auth);

router.get('/', getMyNotifications);
router.patch('/read-all', markAllAsRead);
router.patch('/:id/read', markAsRead);

module.exports = router;
