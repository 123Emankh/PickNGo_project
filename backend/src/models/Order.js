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
  delivery_city: {
    // ✅ مدينة توصيل الزبون (من قائمة palestineAreas الثابتة بالفرونت) -
    // أساس حساب رسم التوصيل الصحيح، مش تخمين من الإحداثيات
    type: DataTypes.STRING(50),
    allowNull: true
  },
  delivery_region: {
    // ✅ 'West Bank' | 'Gaza Strip' | 'Israel' - مشتقة من delivery_city بالفرونت
    type: DataTypes.STRING(50),
    allowNull: true
  },
  delivery_lat: {
    type: DataTypes.DECIMAL(10, 8),
    allowNull: true
  },
  delivery_lng: {
    type: DataTypes.DECIMAL(11, 8),
    allowNull: true
  },
  driver_current_lat: {
    // ✅ آخر موقع لحظي وصل من السائق أثناء التوصيل (يتحدث كل ما يبعث driver:location)
    type: DataTypes.DECIMAL(10, 8),
    allowNull: true
  },
  driver_current_lng: {
    type: DataTypes.DECIMAL(11, 8),
    allowNull: true
  },
  driver_location_updated_at: {
    type: DataTypes.DATE,
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
  payment_checkout_id: {
    // ✅ checkoutId من HyperPay (بيتحدد قبل ما نعرف نتيجة الدفع - راجع verifyAndGetStatus)
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
  },
  status_history: {
    // ✅ [{status, at}, ...] - سجل زمني حقيقي لكل تغيير حالة (أساس شاشة التتبع)
    type: DataTypes.JSON,
    allowNull: true
  },
  preferred_company_id: {
    // ✅ نسخة عن Restaurant.preferred_company_id وقت إنشاء الطلب (نفس منطق
    // delivery_fee) - يستخدمها محرك التعيين الذكي لإعطاء أولوية لسائقي الشركة
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'users', key: 'user_id' }
  },
  required_vehicle_type: {
    // ✅ نسخة عن Restaurant.required_vehicle_type وقت إنشاء الطلب
    type: DataTypes.STRING(30),
    allowNull: true
  },
  offered_driver_id: {
    // ✅ سائق معروض عليه الطلب حاليًا وبانتظار رده - مختلف عن driver_id يلي
    // ما يتحدد إلا بعد قبول فعلي (Auto) أو انتقاء يدوي من القائمة المفتوحة
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'users', key: 'user_id' }
  },
  offer_expires_at: {
    type: DataTypes.DATE,
    allowNull: true
  },
  assigned_at: {
    // ✅ وقت تحديد driver_id فعليًا (قبول عرض تلقائي أو انتقاء يدوي)
    type: DataTypes.DATE,
    allowNull: true
  },
  assignment_type: {
    type: DataTypes.ENUM('Auto', 'Manual'),
    allowNull: true
  },
  assignment_reason: {
    // ✅ تفصيل نقاط العوامل يلي أدت لاختيار السائق النهائي - لتتبع القرار لاحقًا
    type: DataTypes.JSON,
    allowNull: true
  },
  offer_history: {
    // ✅ [{driver_id, status, at, reason}, ...] كل محاولات العرض على هاد
    // الطلب (Offered/Accepted/Rejected/Expired/NoCandidate)
    type: DataTypes.JSON,
    allowNull: true
  },
  delivery_group_id: {
    // ✅ Grouped Delivery: لو هاد الطلب جزء من رحلة توصيل مجمّعة مع طلبات
    // تانية لنفس الزبون من متاجر قريبة - راجع groupingService.js. null
    // بالحالة الطبيعية (الأغلبية) - يعني الطلب بمشي بمساره الفردي القديم كليًا.
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'delivery_groups', key: 'group_id' }
  },
  points_earned: {
    // ✅ لقطة على كم نقطة كُسبت بالضبط وقت Delivered - تُستخدم لعكس العملية
    // بدقة لو الطلب رجع عن Delivered لاحقًا (إلغاء/إعادة فتح إدارية)، بدل
    // إعادة حساب قد ياخد رقم مختلف لو تغيّرت إعدادات النظام بين الوقتين
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0
  },
  points_earned_at: {
    type: DataTypes.DATE,
    allowNull: true
  },
  points_redeemed: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0
  },
  points_redeemed_value: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    defaultValue: 0
  },
  points_redemption_refunded: {
    // ✅ حارس منع استرجاع مزدوج لنفس النقاط المستبدلة
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: false
  }
}, {
  tableName: 'orders',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = Order;