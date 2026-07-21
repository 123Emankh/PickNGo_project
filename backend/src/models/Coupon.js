// src/models/Coupon.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Coupon = sequelize.define('Coupon', {
  coupon_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  restaurant_id: {
    // ✅ null = كوبون عام على كل المنصة (الأدمن بس يقدر ينشئه هيك)
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'restaurants', key: 'restaurant_id' }
  },
  created_by: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'users', key: 'user_id' }
  },
  code: {
    type: DataTypes.STRING(30),
    allowNull: false,
    unique: true
  },
  discount_type: {
    type: DataTypes.ENUM('Percentage', 'Fixed'),
    allowNull: false
  },
  discount_value: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  min_order_amount: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0
  },
  max_discount_amount: {
    // ✅ يحدد سقف الخصم لما discount_type='Percentage' - متجاهل لما يكون 'Fixed'
    type: DataTypes.DECIMAL(10, 2),
    allowNull: true
  },
  valid_from: {
    type: DataTypes.DATE,
    allowNull: true
  },
  valid_until: {
    type: DataTypes.DATE,
    allowNull: true
  },
  usage_limit: {
    // ✅ null = بدون حد أقصى لعدد مرات الاستخدام الكلي
    type: DataTypes.INTEGER,
    allowNull: true
  },
  usage_limit_per_customer: {
    type: DataTypes.INTEGER,
    defaultValue: 1
  },
  used_count: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  }
}, {
  tableName: 'coupons',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = Coupon;
