const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

// ✅ رحلة توصيل واحدة تجمع أكتر من طلب لنفس الزبون من متاجر قريبة من بعض
// (Grouped Delivery / Smart Order Clustering). حقول العرض/التعيين هون نفس
// شكل حقول Phase 3 على Order بالضبط - راجع groupAssignmentService.js
const DeliveryGroup = sequelize.define('DeliveryGroup', {
  group_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  customer_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'users', key: 'user_id' }
  },
  status: {
    type: DataTypes.ENUM('Forming', 'Assigned', 'Completed', 'Cancelled'),
    defaultValue: 'Forming'
  },
  driver_id: {
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'users', key: 'user_id' }
  },
  offered_driver_id: {
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'users', key: 'user_id' }
  },
  offer_expires_at: {
    type: DataTypes.DATE,
    allowNull: true
  },
  assigned_at: {
    type: DataTypes.DATE,
    allowNull: true
  },
  assignment_type: {
    type: DataTypes.ENUM('Auto', 'Manual'),
    allowNull: true
  },
  assignment_reason: {
    type: DataTypes.JSON,
    allowNull: true
  },
  offer_history: {
    type: DataTypes.JSON,
    allowNull: true
  }
}, {
  tableName: 'delivery_groups',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = DeliveryGroup;
