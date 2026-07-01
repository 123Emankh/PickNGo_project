// src/models/index.js
const sequelize = require('../config/database');
const User = require('./User');
const Otp = require('./Otp');

// Export all models
module.exports = {
  sequelize,
  User,
  Otp
};