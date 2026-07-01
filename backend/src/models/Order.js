const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Order = sequelize.define('Order', {
  order_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  customer_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'users', key: 'user_id' }
  },
  restaurant_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'restaurants', key: 'restaurant_id' }
  },
  driver_id: {
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'users', key: 'user_id' }
  },
  order_number: {
    type: DataTypes.STRING(20),
    allowNull: false,
    unique: true
  },
  status: {
    type: DataTypes.ENUM(
      'Pending',
      'Confirmed',
      'Preparing',
      'Ready',
      'PickedUp',
      'Delivered',
      'Cancelled',
      'Refunded'
    ),
    defaultValue: 'Pending'
  },
  total_amount: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  delivery_fee: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.00
  },
  tax: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.00
  },
  discount: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.00
  },
  final_amount: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false
  },
  delivery_address: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  delivery_lat: {
    type: DataTypes.DECIMAL(10, 8),
    allowNull: true
  },
  delivery_lng: {
    type: DataTypes.DECIMAL(11, 8),
    allowNull: true
  },
  special_instructions: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  estimated_delivery_time: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  actual_delivery_time: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  payment_method: {
    type: DataTypes.ENUM('Cash', 'CreditCard', 'DebitCard', 'Wallet'),
    allowNull: false
  },
  payment_status: {
    type: DataTypes.ENUM('Pending', 'Paid', 'Failed', 'Refunded'),
    defaultValue: 'Pending'
  },
  payment_id: {
    type: DataTypes.STRING(100),
    allowNull: true
  },
  order_time: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  delivery_time: {
    type: DataTypes.DATE,
    allowNull: true
  },
  completed_time: {
    type: DataTypes.DATE,
    allowNull: true
  }
}, {
  tableName: 'orders',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = Order;