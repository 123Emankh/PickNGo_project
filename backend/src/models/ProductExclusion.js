// src/models/ProductExclusion.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const ProductExclusion = sequelize.define('ProductExclusion', {
  exclusion_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  product_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'products', key: 'product_id' }
  },
  label: {
    // مثلاً: No Onions
    type: DataTypes.STRING(50),
    allowNull: false
  },
  sort_order: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  }
}, {
  tableName: 'product_exclusions',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = ProductExclusion;
