// src/middleware/rateLimit.js
//
// حماية Production Readiness: تحديد معدل الطلبات (rate limiting) - لم يكن
// موجودًا إطلاقًا سابقًا، ما يعني أي راوت (خصوصًا تسجيل الدخول وطلب/تحقق
// OTP) كان قابلاً للقصف بلا حدود. حدّان بس، بنفس فلسفة باقي المشروع
// (بسيط ومباشر، بدون تعقيد زائد):
//   - generalLimiter: سقف عام سخي لكل /api - يمنع إغراق السيرفر بلا ما يزعج
//     استخدام طبيعي (تطبيق موبايل بيعمل عدة نداءات متتالية عاديًا).
//   - authLimiter: سقف أشد بكثير، على راوتات الهوية الحساسة بس (تسجيل
//     دخول/تسجيل حساب/OTP/استرجاع كلمة سر) - هون فعليًا بيصير الفرق بين
//     قابل للقصف بالقوة الغاشمة (brute force) وغير قابل.
const rateLimit = require('express-rate-limit');

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 دقيقة
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many requests, please try again later.' }
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 دقيقة
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many attempts, please try again later.' }
});

// ✅ المساعد الذكي (Gemini): كل رسالة بتكلّف فعليًا (استدعاء API خارجي مدفوع)،
// فسقف أشد من generalLimiter العام وبالمفتاح الصحيح لمستخدم مسجّل دخول (مش IP
// فقط - عدة مستخدمين ممكن يشاركوا IP وحدة بشبكة موبايل/NAT). aiRoutes.js
// بيطبّقه بعد auth middleware مباشرة فـ req.user دايمًا موجود هون.
const aiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 دقيقة
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => String(req.user.user_id),
  message: { success: false, message: 'Too many AI requests, please try again in a few minutes.' }
});

module.exports = { generalLimiter, authLimiter, aiLimiter };
