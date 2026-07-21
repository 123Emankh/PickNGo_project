// src/models/LoyaltyTransaction.js
//
// دفتر أستاذ (ledger) نظام النقاط - سجل تدقيق لا يُعدَّل أبدًا بعد إنشائه،
// مصدر الحقيقة الوحيد لرصيد كل مستخدم (User.loyalty_points مجرّد نسخة
// مخزّنة/مكافئة لآخر balance_after، نفس فلسفة Restaurant.rating مع جدول
// reviews - راجع loyaltyService.js).
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const LoyaltyTransaction = sequelize.define('LoyaltyTransaction', {
  transaction_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  user_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'users', key: 'user_id' }
  },
  order_id: {
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'orders', key: 'order_id' }
  },
  type: {
    // Earned: طلب Delivered | Redeemed: استبدال بالـ checkout |
    // Reversed: سحب نقاط مكسوبة (الطلب رجع عن Delivered) |
    // Refunded: إرجاع نقاط مستبدلة (الطلب اللي استُبدلت عليه انلغى)
    type: DataTypes.ENUM('Earned', 'Redeemed', 'Reversed', 'Refunded'),
    allowNull: false
  },
  points: {
    // موجب لـ Earned/Refunded، سالب لـ Redeemed/Reversed
    type: DataTypes.INTEGER,
    allowNull: false
  },
  balance_after: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  description: {
    type: DataTypes.STRING(255),
    allowNull: true
  }
}, {
  tableName: 'loyalty_transactions',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: false
});

module.exports = LoyaltyTransaction;
