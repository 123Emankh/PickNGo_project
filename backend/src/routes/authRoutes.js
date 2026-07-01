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
  updateProfile
} = require('../controllers/authController');
const { auth, authorize } = require('../middleware/auth');

router.post('/signup', signupInitial);
router.post('/verify-signup', verifySignup);
router.post('/resend-otp', resendOTP);
router.post('/login', login);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password', resetPassword);
router.post('/verify-otp', verifyOTPOnly);

router.post('/logout', auth, logout);
router.get('/profile', auth, getProfile);
router.put('/profile', auth, updateProfile);

router.get('/admin/users', auth, authorize('Admin'), async (req, res) => {
  try {
    const { User } = require('../models');
    const users = await User.findAll({
      attributes: { exclude: ['password'] },
      order: [['created_at', 'DESC']]
    });
    res.json({
      success: true,
      users
    });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

module.exports = router;