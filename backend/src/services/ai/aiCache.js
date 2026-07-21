// src/services/ai/aiCache.js
//
// المساعد الذكي: كاش بسيط بالذاكرة (Map + TTL) بدون Redis - نفس فلسفة
// المشروع بعدم إضافة infrastructure جديدة لغير داعٍ (راجع SystemSettings/
// groupingService لنفس النمط بمكان تاني). محدود على مثيل سيرفر واحد فقط،
// وبيروح لو انعمل restart - مقبول هون لأنه تحسين أداء/تكلفة، مش مصدر حقيقة.
//
// ⚠️ قرار مهم: الكاش هون بيُستخدم فقط لطلبات "توليد محتوى" لصاحب المتجر
// (وصف/عنوان/نص تسويقي منتج) لأنها الوحيدة يلي جوابها معقول يتكرر لنفس
// المدخل تقريبًا وما بيعتمد على بيانات حية متغيرة. أي سؤال عن حالة طلب،
// إحصائيات أدمن، أو بحث متاجر لازم يفضل يوصل فعليًا لقاعدة البيانات كل
// مرة - تخزينه بالكاش ممكن يرجّع جواب قديم/غلط عن قصد.
const crypto = require('crypto');

const TTL_MS = 10 * 60 * 1000; // 10 دقايق
const store = new Map();

function cacheKey(userId, message) {
  const normalized = String(message).trim().toLowerCase();
  return crypto.createHash('sha256').update(`${userId}:${normalized}`).digest('hex');
}

function get(userId, message) {
  const key = cacheKey(userId, message);
  const entry = store.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) {
    store.delete(key);
    return null;
  }
  return entry.value;
}

function set(userId, message, value) {
  const key = cacheKey(userId, message);
  store.set(key, { value, expiresAt: Date.now() + TTL_MS });
}

// ✅ الأدوار/الحالات يلي بيستحق الكاش تطبيقه عليها - راجع التحذير فوق
function isCacheableRole(role) {
  return role === 'Restaurant';
}

module.exports = { get, set, isCacheableRole };
