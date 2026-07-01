// src/utils/validators.js

/**
 * Validate email format
 * @param {string} email - Email to validate
 * @returns {boolean} True if valid
 */
const validateEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

/**
 * Validate password strength
 * @param {string} password - Password to validate
 * @returns {boolean} True if valid
 */
const validatePassword = (password) => {
  return password && password.length >= 6;
};

/**
 * Validate phone number
 * @param {string} phone - Phone number to validate
 * @returns {boolean} True if valid
 */
const validatePhone = (phone) => {
  if (!phone) return true; 
  const phoneRegex = /^[0-9+\-\s()]{10,15}$/;
  return phoneRegex.test(phone);
};

/**
 * Validate required fields
 * @param {Object} data - Data object
 * @param {string[]} fields - Required field names
 * @returns {Object} { valid: boolean, missing: string[] }
 */
const validateRequired = (data, fields) => {
  const missing = [];
  fields.forEach(field => {
    if (!data[field] || data[field].trim() === '') {
      missing.push(field);
    }
  });
  return {
    valid: missing.length === 0,
    missing
  };
};

/**
 * Sanitize input string (trim and remove excessive spaces)
 * @param {string} str - String to sanitize
 * @returns {string} Sanitized string
 */
const sanitizeString = (str) => {
  if (!str || typeof str !== 'string') return '';
  return str.trim().replace(/\s+/g, ' ');
};

/**
 * Validate latitude
 * @param {number} lat - Latitude
 * @returns {boolean} True if valid
 */
const validateLatitude = (lat) => {
  if (lat === null || lat === undefined) return true;
  return typeof lat === 'number' && lat >= -90 && lat <= 90;
};

/**
 * Validate longitude
 * @param {number} lng - Longitude
 * @returns {boolean} True if valid
 */
const validateLongitude = (lng) => {
  if (lng === null || lng === undefined) return true;
  return typeof lng === 'number' && lng >= -180 && lng <= 180;
};

module.exports = {
  validateEmail,
  validatePassword,
  validatePhone,
  validateRequired,
  sanitizeString,
  validateLatitude,
  validateLongitude
};