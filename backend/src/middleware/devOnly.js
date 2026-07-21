// src/middleware/devOnly.js
const { isDevMode } = require('../config/devMode');

// ✅ أي راوت يستخدم هاد الميدلوير بيختفي كليًا بالإنتاج (404 قبل ما يوصل حتى
// للـ Controller) - مش مجرد تعطيل منطقي ممكن ينسى حد يشيله أو يلتف حوله.
const devOnly = (req, res, next) => {
  if (!isDevMode) {
    return res.status(404).json({
      success: false,
      message: `Route ${req.originalUrl} not found`
    });
  }
  next();
};

module.exports = { devOnly };
