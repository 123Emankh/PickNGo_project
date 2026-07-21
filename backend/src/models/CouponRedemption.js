// src/models/CouponRedemption.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const CouponRedemption = sequelize.define('CouponRedemption', {
  redemption_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  coupon_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'coupons', key: 'coupon_id' }
  },
  customer_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'users', key: 'user_id' }
  },
  order_id: {
    // ✅ تقييد واحد لكل طلب - نفس فكرة Review.order_id
    type: DataTypes.INTEGER,
    allowNull: false,
    unique: true,
    references: { model: 'orders', key: 'order_id' }
  },
  discount_amount: {
    // ✅ لقطة (snapshot) للمبلغ الفعلي المخصوم وقت الاستخدام - حتى لو تغيّرت شروط الكوبون لاحقًا
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  }
}, {
  tableName: 'coupon_redemptions',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: false
});

module.exports = CouponRedemption;
