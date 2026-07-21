// src/services/notificationService.js
//
// Phase 4 - نظام الإشعارات: نقطة الإنشاء الوحيدة لأي إشعار بالمشروع. كل
// مكان بالكود بده يبلّغ مستخدم بشي (طلب جديد، تغيّر حالة، عرض تعيين ذكي...)
// بينادي createNotification بدل ما يكتب بالجدول مباشرة - نفس فلسفة
// driverStatusService (نقطة وصول وحيدة لتغيير حالة السائق).
const { Notification, User } = require('../models');

function formatNotification(n) {
  return {
    id: n.notification_id.toString(),
    title: n.title,
    body: n.body,
    type: n.type,
    related_type: n.related_type,
    related_id: n.related_id !== null && n.related_id !== undefined ? n.related_id.toString() : null,
    is_read: n.is_read,
    created_at: n.created_at
  };
}

/**
 * ينشئ إشعار ويخزّنه، وبيبثّه لحظيًا لغرفة notifications:{userId} لو io موجود
 * (fire-and-forget من ناحية الاستدعاء - فشل هون ما لازم يفشّل العملية الأصلية
 * زي إنشاء الطلب أو تغيير الحالة، فكل نقاط الاستدعاء بتلفّه بـ try/catch أو .catch)
 */
async function createNotification({ userId, title, body, type, relatedType = null, relatedId = null, io = null }) {
  const notification = await Notification.create({
    user_id: userId,
    title,
    body,
    type,
    related_type: relatedType,
    related_id: relatedId
  });

  if (io) {
    io.to(`notifications:${userId}`).emit('notification:new', formatNotification(notification));
  }

  return notification;
}

/**
 * نفس createNotification بس لعدة مستلمين سوا (مثلاً كل الأدمنز) - يستخدمها
 * AdminApproval. ما بيفشل الكل لو مستخدم واحد فشل.
 */
async function notifyRole(role, { title, body, type, relatedType = null, relatedId = null, io = null }) {
  const recipients = await User.findAll({ where: { role }, attributes: ['user_id'] });
  await Promise.all(
    recipients.map((u) =>
      createNotification({ userId: u.user_id, title, body, type, relatedType, relatedId, io }).catch((err) =>
        console.error('❌ notifyRole createNotification error:', err)
      )
    )
  );
}

async function getUnreadCount(userId) {
  return Notification.count({ where: { user_id: userId, is_read: false } });
}

module.exports = { createNotification, notifyRole, formatNotification, getUnreadCount };
