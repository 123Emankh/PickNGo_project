// src/models/ProductOptionValue.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const ProductOptionValue = sequelize.define('ProductOptionValue', {
  value_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  group_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'product_option_groups', key: 'group_id' }
  },
  label: {
    // مثلاً: أحمر، خبز أسمر
    type: DataTypes.STRING(100),
    allowNull: false
  },
  price: {
    // سعر إضافي اختياري (ممكن يكون 0) - نفس منطق الإضافات
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    defaultValue: 0
  },
  sort_order: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  }
}, {
  tableName: 'product_option_values',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = ProductOptionValue;
