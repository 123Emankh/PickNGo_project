const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Restaurant = sequelize.define('Restaurant', {
  restaurant_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  user_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'users', key: 'user_id' }
  },
  name: {
    type: DataTypes.STRING(100),
    allowNull: false
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  cuisine_type: {
    type: DataTypes.STRING(50),
    allowNull: true
  },
  logo: {
    type: DataTypes.STRING(255),
    allowNull: true
  },
  cover_image: {
    type: DataTypes.STRING(255),
    allowNull: true
  },
  address: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  location_lat: {
    type: DataTypes.DECIMAL(10, 8),
    allowNull: false
  },
  location_lng: {
    type: DataTypes.DECIMAL(11, 8),
    allowNull: false
  },
  city: {
    type: DataTypes.STRING(50),
    allowNull: false
  },
  region: {
    type: DataTypes.STRING(50),
    allowNull: false
  },
  phone: {
    type: DataTypes.STRING(20),
    allowNull: false
  },
  email: {
    type: DataTypes.STRING(100),
    allowNull: true
  },
  opening_time: {
    type: DataTypes.TIME,
    allowNull: true
  },
  closing_time: {
    type: DataTypes.TIME,
    allowNull: true
  },
  delivery_fee: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.00
  },
  minimum_order: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.00
  },
  rating: {
    type: DataTypes.DECIMAL(3, 2),
    defaultValue: 0.00
  },
  review_count: {
    type: DataTypes.INTEGER,
    defaultValue: 0
  },
  is_open: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  approval_status: {
    type: DataTypes.ENUM('Pending', 'Approved', 'Rejected'),
    defaultValue: 'Pending'
  }
}, {
  tableName: 'restaurants',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = Restaurant;