// src/models/Favorite.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Favorite = sequelize.define('Favorite', {
  favorite_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  user_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'users', key: 'user_id' }
  },
  restaurant_id: {
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'restaurants', key: 'restaurant_id' }
  },
  product_id: {
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'products', key: 'product_id' }
  }
}, {
  tableName: 'favorites',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = Favorite;
