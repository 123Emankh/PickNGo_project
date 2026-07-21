// src/middleware/auth.js
const { verifyUserToken, AuthError } = require('../utils/verifyUserToken');
require('dotenv').config();

const AUTH_ERROR_STATUS = {
  NO_TOKEN: 401,
  INVALID_TOKEN: 401,
  EXPIRED_TOKEN: 401,
  USER_NOT_FOUND: 401,
  DEACTIVATED: 403,
  SUSPENDED: 403
};

const auth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'No token provided. Please login.'
      });
    }

    const token = authHeader.split(' ')[1];
    req.user = await verifyUserToken(token);
    next();

  } catch (error) {
    if (error instanceof AuthError) {
      return res.status(AUTH_ERROR_STATUS[error.code] || 401).json({
        success: false,
        message: error.message
      });
    }
    console.error('Auth middleware error:', error);
    return res.status(500).json({
      success: false,
      message: 'Authentication error'
    });
  }
};

/**
 * زي auth بس ما بترفض الطلب لو ما في توكن أو كان غير صالح - بترجع req.user = null
 * وتكمل (guest). مفيدة للراوتات العامة يلي بس بتحتاج تعرف مين المستخدم لو مسجل دخول
 * (مثلاً: تحديد is_favorited بقائمة المتاجر).
 */
const optionalAuth = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    req.user = null;
    return next();
  }

  try {
    const token = authHeader.split(' ')[1];
    req.user = await verifyUserToken(token);
  } catch (error) {
    req.user = null;
  }
  next();
};

/**
 * Role-based authorization middleware
 * @param {string|string[]} allowedRoles - Allowed role(s)
 */
const authorize = (allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required'
      });
    }

    const roles = Array.isArray(allowedRoles) ? allowedRoles : [allowedRoles];
    
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Access denied. Required role(s): ${roles.join(', ')}`
      });
    }

    next();
  };
};


const hasRole = (req, roles) => {
  if (!req.user) return false;
  const allowedRoles = Array.isArray(roles) ? roles : [roles];
  return allowedRoles.includes(req.user.role);
};

module.exports = {
  auth,
  optionalAuth,
  authorize,
  hasRole
};