// src/config/devMode.js
// مصدر واحد لقرار "هل نحن بالتطوير؟" - كل ميزات التسريع (تخطي إرسال OTP
// بالإيميل، راوت الـ quick-signup، إلخ) بترجع لهاد المتغير الوحيد بدل ما
// يتكرر فحص NODE_ENV بكل ملف. أي قيمة غير 'production' (development, test,
// غير معرّفة) تعتبر تطوير - الإنتاج الوحيد يلي بيوقف هالميزات هو NODE_ENV=production صراحةً.
const isDevMode = process.env.NODE_ENV !== 'production';

module.exports = { isDevMode };
