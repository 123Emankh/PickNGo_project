const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

// ✅ Phase 4 - نظام الإشعارات: أول تخزين حقيقي للإشعارات بالمشروع (كانت
// بس أحداث Socket.io لحظية عابرة قبل هيك - راجع notificationService.js)
const Notification = sequelize.define('Notification', {
  notification_id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  user_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'users', key: 'user_id' }
  },
  title: {
    type: DataTypes.STRING(150),
    allowNull: false
  },
  body: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  type: {
    type: DataTypes.ENUM('OrderStatus', 'NewOrder', 'SmartAssignmentOffer', 'UserStatus', 'AdminApproval', 'NewReview', 'LoyaltyEarned'),
    allowNull: false
  },
  related_type: {
    type: DataTypes.STRING(30),
    allowNull: true
  },
  related_id: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  is_read: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  }
}, {
  tableName: 'notifications',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = Notification;
