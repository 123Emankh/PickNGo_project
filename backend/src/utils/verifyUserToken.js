// src/utils/verifyUserToken.js
// منطق التحقق من JWT + تحميل المستخدم، مشترك بين auth middleware (REST) و socket handshake auth.
const jwt = require('jsonwebtoken');
const { User } = require('../models');

const JWT_SECRET = process.env.JWT_SECRET;

class AuthError extends Error {
  constructor(message, code) {
    super(message);
    this.code = code; // 'NO_TOKEN' | 'INVALID_TOKEN' | 'EXPIRED_TOKEN' | 'USER_NOT_FOUND' | 'DEACTIVATED' | 'SUSPENDED'
  }
}

/**
 * يتحقق من JWT ويرجع بيانات المستخدم المصغّرة (نفس شكل req.user بالـ REST middleware).
 * يرمي AuthError لو في أي مشكلة (invalid/expired token, user not found, inactive, suspended).
 */
async function verifyUserToken(token) {
  if (!token) {
    throw new AuthError('No token provided. Please login.', 'NO_TOKEN');
  }

  let decoded;
  try {
    decoded = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw new AuthError('Token expired. Please login again.', 'EXPIRED_TOKEN');
    }
    throw new AuthError('Invalid token. Please login again.', 'INVALID_TOKEN');
  }

  const user = await User.findByPk(decoded.user_id, {
    attributes: { exclude: ['password'] }
  });

  if (!user) {
    throw new AuthError('User not found. Please login again.', 'USER_NOT_FOUND');
  }

  if (!user.is_active) {
    throw new AuthError('Your account has been deactivated.', 'DEACTIVATED');
  }

  if (user.status === 'Suspended') {
    throw new AuthError('Your account has been suspended.', 'SUSPENDED');
  }

  // ✅ heartbeat بسيط (fire-and-forget) - بيستخدمه لوحة الشركة لتحديد حالة
  // السائق (Available/Offline) بدون أي بنية تحتية إضافية (سوكيت دائم إلخ)
  User.update({ last_active_at: new Date() }, { where: { user_id: user.user_id } }).catch(() => {});

  return {
    user_id: user.user_id,
    email: user.email,
    role: user.role,
    status: user.status
  };
}

module.exports = { verifyUserToken, AuthError };
