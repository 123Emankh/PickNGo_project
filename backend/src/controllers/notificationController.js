// src/controllers/notificationController.js
const { Notification } = require('../models');
const { formatNotification, getUnreadCount } = require('../services/notificationService');

// ===========================
// 📌 GET /api/notifications  (إشعاراتي - الأحدث فالأقدم + عدد غير المقروء)
// ===========================
const getMyNotifications = async (req, res) => {
  try {
    // ✅ باج كان موجود: findAll بدون أي حد - سجل إشعارات مستخدم قديم/نشيط
    // كان ممكن يرجّع آلاف الصفوف بنداء واحد. limit ثابت معقول (مش pagination
    // كاملة - الشاشة أصلاً بتعرض كل شي بقائمة واحدة، بس سقف أمان).
    const notifications = await Notification.findAll({
      where: { user_id: req.user.user_id },
      order: [['created_at', 'DESC']],
      limit: 100
    });

    // ✅ unread_count لازم يعكس كل غير المقروء الفعلي، مش بس الـ100 المرجّعة
    const unreadCount = await getUnreadCount(req.user.user_id);

    res.status(200).json({
      success: true,
      notifications: notifications.map(formatNotification),
      unread_count: unreadCount
    });
  } catch (error) {
    console.error('❌ Get my notifications error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching notifications' });
  }
};

// ===========================
// 📌 PATCH /api/notifications/:id/read
// ===========================
const markAsRead = async (req, res) => {
  try {
    const notification = await Notification.findByPk(req.params.id);
    if (!notification || notification.user_id !== req.user.user_id) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }

    if (!notification.is_read) {
      await notification.update({ is_read: true });
    }

    res.status(200).json({ success: true, notification: formatNotification(notification) });
  } catch (error) {
    console.error('❌ Mark notification as read error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating notification' });
  }
};

// ===========================
// 📌 PATCH /api/notifications/read-all
// ===========================
const markAllAsRead = async (req, res) => {
  try {
    await Notification.update(
      { is_read: true },
      { where: { user_id: req.user.user_id, is_read: false } }
    );
    res.status(200).json({ success: true, message: 'All notifications marked as read' });
  } catch (error) {
    console.error('❌ Mark all notifications as read error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating notifications' });
  }
};

module.exports = { getMyNotifications, markAsRead, markAllAsRead };
