// src/models/ProductOptionGroup.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const ProductOptionGroup = sequelize.define('ProductOptionGroup', {
  group_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  product_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'products', key: 'product_id' }
  },
  name: {
    // مثلاً: نوع الخبز، اللون
    type: DataTypes.STRING(100),
    allowNull: false
  },
  selection_mode: {
    type: DataTypes.ENUM('single', 'multiple'),
    allowNull: false,
    defaultValue: 'single'
  },
  is_required: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: false
  },
  sort_order: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  }
}, {
  tableName: 'product_option_groups',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = ProductOptionGroup;
