// src/routes/authRoutes.js
const express = require('express');
const router = express.Router();
const {
  signupInitial,
  verifySignup,
  resendOTP,
  login,
  forgotPassword,
  resetPassword,
  verifyOTPOnly,
  logout,
  getProfile,
  updateProfile,
  changePassword,
  uploadAvatar,
  devQuickSignup
} = require('../controllers/authController');
const { auth } = require('../middleware/auth');
const { avatarUpload } = require('../middleware/upload');
const { authLimiter } = require('../middleware/rateLimit');
const { devOnly } = require('../middleware/devOnly');

// ✅ سقف أشد بكثير من العام (20 محاولة/15 دقيقة) على راوتات الهوية الحساسة -
// كانت بلا أي حد إطلاقًا (يعني قابلة للقصف بالقوة الغاشمة على تسجيل الدخول
// أو استنزاف OTP على إيميلات عشوائية)
router.post('/signup', authLimiter, signupInitial);
router.post('/verify-signup', authLimiter, verifySignup);
router.post('/resend-otp', authLimiter, resendOTP);
router.post('/login', authLimiter, login);
router.post('/forgot-password', authLimiter, forgotPassword);
router.post('/reset-password', authLimiter, resetPassword);
router.post('/verify-otp', authLimiter, verifyOTPOnly);

// ✅ Dev Mode فقط - بيرجع 404 تلقائيًا لما NODE_ENV=production (راجع devOnly.js)
router.post('/dev/quick-signup', devOnly, authLimiter, devQuickSignup);

router.post('/logout', auth, logout);
router.get('/profile', auth, getProfile);
router.put('/profile', auth, updateProfile);
router.put('/profile/change-password', auth, changePassword);
router.post('/profile/avatar', auth, avatarUpload.single('avatar'), uploadAvatar);

module.exports = router;