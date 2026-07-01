// src/models/Otp.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Otp = sequelize.define('Otp', {
  otp_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  email: {
    type: DataTypes.STRING(100),
    allowNull: false,
    validate: {
      isEmail: { msg: 'Invalid email format' }
    }
  },
  otp_code: {
    type: DataTypes.STRING(6),
    allowNull: false,
    validate: {
      len: {
        args: [6, 6],
        msg: 'OTP must be exactly 6 characters'
      }
    }
  },
  type: {
    type: DataTypes.ENUM('Verification', 'ResetPassword', 'Login'),
    defaultValue: 'Verification'
  },
  temp_token: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  expires_at: {
    type: DataTypes.DATE,
    allowNull: false
  },
  is_used: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  attempts: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  },
  ip_address: {
    type: DataTypes.STRING(45),
    allowNull: true
  },
  user_agent: {
    type: DataTypes.TEXT,
    allowNull: true
  }
}, {
  tableName: 'otps',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at',
  
  indexes: [
    {
      name: 'idx_otps_email',
      fields: ['email']
    },
    {
      name: 'idx_otps_otp_code',
      fields: ['otp_code']
    },
    {
      name: 'idx_otps_expires_at',
      fields: ['expires_at']
    }
  ]
});

module.exports = Otp;