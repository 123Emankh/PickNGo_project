// src/models/OrderItem.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const OrderItem = sequelize.define('OrderItem', {
  order_item_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  order_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'orders', key: 'order_id' }
  },
  product_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'products', key: 'product_id' }
  },
  quantity: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 1
  },
  unit_price: {
    // ✅ سعر المنتج (أو سعر الحجم المختار) وقت الطلب (بنسخه هون عشان لو تغير
    // السعر لاحقاً ما يأثر على طلبات قديمة)
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  variant_id: {
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'product_variants', key: 'variant_id' }
  },
  variant_label: {
    // ✅ سناب شوت لاسم الحجم وقت الطلب (نفس منطق unit_price)
    type: DataTypes.STRING(50),
    allowNull: true
  },
  subtotal: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  addons: {
    // ✅ سناب شوت للإضافات المختارة وقت الطلب: [{id, name, price}]
    type: DataTypes.JSON,
    allowNull: true
  },
  special_requests: {
    // ✅ سناب شوت للطلبات الخاصة المختارة وقت الطلب: ["No Onions", ...]
    type: DataTypes.JSON,
    allowNull: true
  },
  selected_options: {
    // ✅ سناب شوت لمجموعات المواصفات المخصصة المختارة وقت الطلب:
    // [{group_id, group_name, value_id, label, price}, ...]
    type: DataTypes.JSON,
    allowNull: true
  }
}, {
  tableName: 'order_items',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: false
});

module.exports = OrderItem;
