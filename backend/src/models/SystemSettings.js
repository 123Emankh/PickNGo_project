// src/models/SystemSettings.js
//
// صف وحيد (singleton, id=1) بيتحكم بقواعد Grouped Delivery من لوحة الأدمن
// بدل ما تكون ثابتة بالكود (راجع services/grouping/config.js للقيم
// الافتراضية القديمة - محفوظة هلق بس كـ defaults لأول seed).
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const SystemSettings = sequelize.define('SystemSettings', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  grouped_delivery_enabled: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: true
  },
  max_store_distance: {
    // كم - أبعد مسافة بين متجرين لسا يعتبروا "بنفس المنطقة"
    type: DataTypes.DECIMAL(6, 2),
    allowNull: false,
    defaultValue: 0.1
  },
  max_delivery_distance: {
    // كم - أبعد مسافة بين نقطتي توصيل لسا تعتبروا "نفس الوجهة"
    type: DataTypes.DECIMAL(6, 2),
    allowNull: false,
    defaultValue: 0.1
  },
  max_time_between_orders: {
    // دقايق
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 10
  },
  max_orders_per_group: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 4
  },
  max_stores_per_trip: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 4
  },
  minimum_driver_rating: {
    // محجوز للمستقبل - ما في نظام تقييم سائقين حاليًا، الحقل غير مفعّل بمنطق التعيين
    type: DataTypes.DECIMAL(2, 1),
    allowNull: false,
    defaultValue: 0
  },
  auto_assign_driver: {
    // بيتحكم بس بالتعيين التلقائي لرحلات التوصيل المجمّعة (DeliveryGroup) -
    // التعيين التلقائي للطلبات الفردية غير متأثر
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: true
  },
  loyalty_enabled: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: true
  },
  points_earn_rate: {
    // نقاط لكل وحدة عملة من قيمة الطلب النهائية (final_amount) وقت التسليم
    type: DataTypes.DECIMAL(6, 2),
    allowNull: false,
    defaultValue: 1
  },
  points_redeem_rate: {
    // قيمة النقطة الوحدة بالعملة وقت الاستبدال بالـ checkout
    type: DataTypes.DECIMAL(8, 4),
    allowNull: false,
    defaultValue: 0.01
  }
}, {
  tableName: 'system_settings',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = SystemSettings;
