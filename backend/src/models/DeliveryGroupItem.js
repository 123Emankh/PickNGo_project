const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

// ✅ صف واحد لكل طلب داخل رحلة توصيل مجمّعة - pickup_sequence هو ترتيب زيارة
// المتجر (نقطة التوسّع لـ Route Optimization لاحقًا)
const DeliveryGroupItem = sequelize.define('DeliveryGroupItem', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  group_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'delivery_groups', key: 'group_id' }
  },
  order_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    unique: true,
    references: { model: 'orders', key: 'order_id' }
  },
  pickup_sequence: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  // ✅ سبب التجميع (Grouping Reason) - ليش هاد الطلب انضم للمجموعة، مش ليش
  // انتخب سائق معيّن (هاد جوا DeliveryGroup.assignment_reason). null لأول
  // عضو بالمجموعة (anchor) - هو ما "انضم" لشي، هو بداية المجموعة.
  matched_with_order_id: {
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'orders', key: 'order_id' }
  },
  store_distance_km: {
    type: DataTypes.DECIMAL(6, 3),
    allowNull: true
  },
  delivery_distance_km: {
    type: DataTypes.DECIMAL(6, 3),
    allowNull: true
  },
  time_difference_minutes: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  rules_satisfied: {
    type: DataTypes.JSON,
    allowNull: true
  }
}, {
  tableName: 'delivery_group_items',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: false
});

module.exports = DeliveryGroupItem;
