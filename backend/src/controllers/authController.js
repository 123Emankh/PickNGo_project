// src/controllers/authController.js
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { Op } = require('sequelize');
const { User, Otp } = require('../models');
const { sendOTPEmail, sendWelcomeEmail } = require('../services/emailService');
const { 
  generateOTP, 
  generateTempToken, 
  storeOTP, 
  verifyOTP, 
  deleteOTP,
  canRequestOTP 
} = require('../services/otpService');
const { validateEmail, validatePassword } = require('../utils/validators');
require('dotenv').config();

const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';


const signupInitial = async (req, res) => {
  const { 
    full_name, 
    email, 
    password, 
    phone, 
    role = 'Customer',
    businessType, // ✅ جديد
    location_lat,
    location_lng,
    city,
    region,
    location_address
  } = req.body;

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📥 [SIGNUP INITIAL] Received signup request');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('👤 User Data:');
  console.log(`   ├─ full_name: ${full_name}`);
  console.log(`   ├─ email: ${email}`);
  console.log(`   ├─ role: ${role}`);
  console.log(`   └─ phone: ${phone || 'Not provided'}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    if (!full_name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Full name, email, and password are required'
      });
    }

    if (!validateEmail(email)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid email format'
      });
    }

    if (!validatePassword(password)) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters long'
      });
    }

    const allowedRoles = ['Customer', 'Restaurant', 'Driver'];
    if (!allowedRoles.includes(role)) {
      return res.status(400).json({
        success: false,
        message: `Invalid role. Allowed roles: ${allowedRoles.join(', ')}`
      });
    }

    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email already registered. Please login or use a different email.'
      });
    }

    const canRequest = await canRequestOTP(email, 'Verification', 1);
    if (!canRequest.allowed) {
      return res.status(429).json({
        success: false,
        message: canRequest.message
      });
    }

    const otp = generateOTP();
    console.log(`🔑 Generated OTP for ${email}: ${otp}`);

    const tempData = {
      full_name,
      email,
      password,
      phone: phone || null,
      role,
      business_type: businessType || null, // ✅ جديد
      location_lat: location_lat || null,
      location_lng: location_lng || null,
      city: city || null,
      region: region || null,
      location_address: location_address || null
    };

    const tempToken = generateTempToken(tempData, JWT_SECRET);

    await storeOTP(
      email,
      otp,
      'Verification',
      tempToken,
      {
        ip: req.ip || req.connection.remoteAddress,
        userAgent: req.headers['user-agent']
      }
    );

    await sendOTPEmail(email, otp, 'Verification');

    console.log(`✅ OTP sent successfully to ${email}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    res.status(200).json({
      success: true,
      message: 'OTP sent successfully to your email. Please verify to complete registration.',
      tempToken,
      expiresIn: `${process.env.OTP_EXPIRY_MINUTES || 15} minutes`
    });

  } catch (error) {
    console.error('❌ Signup initial error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during signup. Please try again.'
    });
  }
};


const verifySignup = async (req, res) => {
  const { email, otp } = req.body;
  const tempToken = req.headers.authorization?.split(' ')[1];

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📥 [VERIFY SIGNUP] Verifying OTP');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`   ├─ email: ${email}`);
  console.log(`   └─ otp: ${otp}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Email and OTP are required'
      });
    }

    if (!tempToken) {
      return res.status(400).json({
        success: false,
        message: 'Temporary token is required'
      });
    }

    const verification = await verifyOTP(email, otp, 'Verification', true);
    if (!verification.valid) {
      return res.status(400).json({
        success: false,
        message: verification.message
      });
    }

    let tempData;
    try {
      tempData = jwt.verify(tempToken, JWT_SECRET);
    } catch (error) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired temporary token. Please start signup again.'
      });
    }

    if (tempData.email !== email) {
      return res.status(400).json({
        success: false,
        message: 'Email mismatch. Please start signup again.'
      });
    }

    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email already registered. Please login.'
      });
    }

    const hashedPassword = await bcrypt.hash(tempData.password, 10);

    let status = 'Approved';
    if (tempData.role === 'Restaurant') {
      status = 'Pending'; 
    }

    const user = await User.create({
      full_name: tempData.full_name,
      email: tempData.email,
      password: hashedPassword,
      phone: tempData.phone,
      role: tempData.role,
      business_type: tempData.business_type, // ✅ جديد
      status: status,
      is_verified: true,
      location_lat: tempData.location_lat,
      location_lng: tempData.location_lng,
      city: tempData.city,
      region: tempData.region,
      location_address: tempData.location_address
    });

    await deleteOTP(email, 'Verification');

    await sendWelcomeEmail(user.email, user.full_name, user.role);

    const token = jwt.sign(
      { 
        user_id: user.user_id, 
        email: user.email,
        role: user.role,
        status: user.status
      },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    const responseData = {
      success: true,
      message: status === 'Approved' 
        ? 'Account created successfully' 
        : 'Account created successfully. Waiting for admin approval.',
      token,
      user: {
        user_id: user.user_id,
        full_name: user.full_name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        business_type: user.business_type, // ✅ جديد
        status: user.status,
        is_verified: user.is_verified,
        location_address: user.location_address,
        city: user.city,
        region: user.region
      }
    };

    console.log(`✅ User created successfully: ${user.email} (${user.role})`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    res.status(201).json(responseData);

  } catch (error) {
    console.error('❌ Verify signup error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during verification. Please try again.'
    });
  }
};


const resendOTP = async (req, res) => {
  const { email } = req.body;
  const tempToken = req.headers.authorization?.split(' ')[1];

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📥 [RESEND OTP] Resending OTP');
  console.log(`   ├─ email: ${email}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email is required'
      });
    }

    if (!tempToken) {
      return res.status(400).json({
        success: false,
        message: 'Temporary token is required'
      });
    }

    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email already registered. Please login.'
      });
    }

    let tempData;
    try {
      tempData = jwt.verify(tempToken, JWT_SECRET);
    } catch (error) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired temporary token. Please start signup again.'
      });
    }

    if (tempData.email !== email) {
      return res.status(400).json({
        success: false,
        message: 'Email mismatch. Please start signup again.'
      });
    }

    const canRequest = await canRequestOTP(email, 'Verification', 1);
    if (!canRequest.allowed) {
      return res.status(429).json({
        success: false,
        message: canRequest.message
      });
    }

    await deleteOTP(email, 'Verification');

    const otp = generateOTP();
    console.log(`🔑 New OTP for ${email}: ${otp}`);

    await storeOTP(
      email,
      otp,
      'Verification',
      tempToken,
      {
        ip: req.ip || req.connection.remoteAddress,
        userAgent: req.headers['user-agent']
      }
    );

    await sendOTPEmail(email, otp, 'Verification');

    console.log(`✅ OTP resent successfully to ${email}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    res.status(200).json({
      success: true,
      message: 'New OTP sent successfully to your email',
      expiresIn: `${process.env.OTP_EXPIRY_MINUTES || 15} minutes`
    });

  } catch (error) {
    console.error('❌ Resend OTP error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error. Please try again.'
    });
  }
};


const login = async (req, res) => {
  const { email, password } = req.body;

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📥 [LOGIN] Login attempt');
  console.log(`   ├─ email: ${email}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required'
      });
    }

    const user = await User.findOne({ 
      where: { email },
      attributes: { exclude: ['reset_password_token', 'reset_password_expires'] }
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password'
      });
    }

    if (!user.is_active) {
      return res.status(403).json({
        success: false,
        message: 'Your account has been deactivated. Please contact support.'
      });
    }

    if (user.status === 'Suspended') {
      return res.status(403).json({
        success: false,
        message: 'Your account has been suspended. Please contact support.'
      });
    }

    if (user.status === 'Rejected') {
      return res.status(403).json({
        success: false,
        message: 'Your account registration has been rejected. Please contact support.'
      });
    }

    if (user.status === 'Pending') {
      return res.status(403).json({
        success: false,
        message: 'Your account is pending approval. Please wait for admin approval.'
      });
    }

    if (!user.is_verified) {
      const otp = generateOTP();
      const tempData = { email: user.email, user_id: user.user_id };
      const tempToken = generateTempToken(tempData, JWT_SECRET, 15);

      await storeOTP(
        user.email,
        otp,
        'Verification',
        tempToken,
        {
          ip: req.ip || req.connection.remoteAddress,
          userAgent: req.headers['user-agent']
        }
      );

      await sendOTPEmail(user.email, otp, 'Verification');

      return res.status(200).json({
        success: false,
        requireVerification: true,
        message: 'Account not verified. OTP sent to your email.',
        tempToken,
        expiresIn: '15 minutes'
      });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password'
      });
    }

    await user.update({ last_login: new Date() });

    const token = jwt.sign(
      { 
        user_id: user.user_id, 
        email: user.email,
        role: user.role,
        status: user.status
      },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    console.log(`✅ User logged in: ${user.email}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    res.status(200).json({
      success: true,
      message: 'Login successful',
      token,
      user: {
        user_id: user.user_id,
        full_name: user.full_name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        status: user.status,
        is_verified: user.is_verified,
        profile_picture: user.profile_picture,
        location_address: user.location_address,
        city: user.city,
        region: user.region
      }
    });

  } catch (error) {
    console.error('❌ Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during login. Please try again.'
    });
  }
};


const forgotPassword = async (req, res) => {
  const { email } = req.body;

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📥 [FORGOT PASSWORD] Request received');
  console.log(`   ├─ email: ${email}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email is required'
      });
    }

    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(200).json({
        success: true,
        message: 'If your email is registered, you will receive a password reset OTP.'
      });
    }

    const canRequest = await canRequestOTP(email, 'ResetPassword', 1);
    if (!canRequest.allowed) {
      return res.status(429).json({
        success: false,
        message: canRequest.message
      });
    }

    await deleteOTP(email, 'ResetPassword');

    const otp = generateOTP();
    console.log(`🔑 Password reset OTP for ${email}: ${otp}`);

    await storeOTP(
      email,
      otp,
      'ResetPassword',
      null,
      {
        ip: req.ip || req.connection.remoteAddress,
        userAgent: req.headers['user-agent']
      }
    );

    await sendOTPEmail(email, otp, 'ResetPassword');

    console.log(`✅ Password reset OTP sent to ${email}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    res.status(200).json({
      success: true,
      message: 'Password reset OTP sent to your email',
      expiresIn: `${process.env.OTP_EXPIRY_MINUTES || 15} minutes`
    });

  } catch (error) {
    console.error('❌ Forgot password error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error. Please try again.'
    });
  }
};


const resetPassword = async (req, res) => {
  const { email, otp, new_password } = req.body;

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📥 [RESET PASSWORD] Request received');
  console.log(`   ├─ email: ${email}`);
  console.log(`   └─ otp: ${otp}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    if (!email || !otp || !new_password) {
      return res.status(400).json({
        success: false,
        message: 'Email, OTP, and new password are required'
      });
    }

    if (!validatePassword(new_password)) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters long'
      });
    }

    const verification = await verifyOTP(email, otp, 'ResetPassword', true);
    if (!verification.valid) {
      return res.status(400).json({
        success: false,
        message: verification.message
      });
    }

    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    const hashedPassword = await bcrypt.hash(new_password, 10);

    await user.update({ 
      password: hashedPassword,
      reset_password_token: null,
      reset_password_expires: null
    });

    await deleteOTP(email, 'ResetPassword');

    console.log(`✅ Password reset successful for ${email}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    res.status(200).json({
      success: true,
      message: 'Password reset successful. You can now login with your new password.'
    });

  } catch (error) {
    console.error('❌ Reset password error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error. Please try again.'
    });
  }
};


const verifyOTPOnly = async (req, res) => {
  const { email, otp, type = 'Verification' } = req.body;

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📥 [VERIFY OTP] Verifying OTP');
  console.log(`   ├─ email: ${email}`);
  console.log(`   └─ type: ${type}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Email and OTP are required'
      });
    }

    const verification = await verifyOTP(email, otp, type, true);
    if (!verification.valid) {
      return res.status(400).json({
        success: false,
        message: verification.message
      });
    }

    if (type === 'Verification') {
      const user = await User.findOne({ where: { email } });
      if (user) {
        await user.update({ is_verified: true });
        console.log(`✅ User verified: ${email}`);
      }
    }

    console.log(`✅ OTP verified successfully for ${email}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    res.status(200).json({
      success: true,
      message: 'OTP verified successfully'
    });

  } catch (error) {
    console.error('❌ Verify OTP error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error. Please try again.'
    });
  }
};


const logout = async (req, res) => {
  res.status(200).json({
    success: true,
    message: 'Logged out successfully'
  });
};


const getProfile = async (req, res) => {
  try {
    const user = await User.findByPk(req.user.user_id, {
      attributes: { exclude: ['password', 'reset_password_token', 'reset_password_expires'] }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.status(200).json({
      success: true,
      user
    });

  } catch (error) {
    console.error('❌ Get profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};


const updateProfile = async (req, res) => {
  const { full_name, phone, location_address, city, region } = req.body;

  try {
    const user = await User.findByPk(req.user.user_id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    await user.update({
      full_name: full_name || user.full_name,
      phone: phone || user.phone,
      location_address: location_address || user.location_address,
      city: city || user.city,
      region: region || user.region
    });

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      user: {
        user_id: user.user_id,
        full_name: user.full_name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        location_address: user.location_address,
        city: user.city,
        region: user.region
      }
    });

  } catch (error) {
    console.error('❌ Update profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
};

module.exports = {
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
};