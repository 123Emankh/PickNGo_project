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
  category_id: {
    // ✅ جديد: يربط المتجر بفئة (مطاعم/صيدليات/أثاث...) عشان الفرونت يقدر يفلتر
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'categories', key: 'category_id' }
  },
  image_url: {
    // ✅ جديد: صورة المتجر الرئيسية اللي الفرونت يتوقعها بـ StoreModel
    // TEXT مش STRING(255) - روابط CDN حقيقية (مثلاً Facebook الموقّعة)
    // ممكن تتجاوز 255 حرف بسهولة
    type: DataTypes.TEXT,
    allowNull: true
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
  },
  rejection_reason: {
    // ✅ جديد: سبب الرفض يعرضه الفرونت لصاحب المحل بشاشة Pending Approval
    type: DataTypes.TEXT,
    allowNull: true
  },
  is_featured: {
    // ✅ جديد: علم يدوي من الأدمن لعرض المتجر بقسم "مميز" بالصفحة الرئيسية
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  preferred_company_id: {
    // ✅ شركة توصيل مفضّلة لهاد المتجر (اختياري) - يستخدمها محرك التعيين
    // الذكي (Phase 3) لإعطاء أولوية لسائقي هاي الشركة. null = بدون تفضيل.
    type: DataTypes.INTEGER,
    allowNull: true,
    references: { model: 'users', key: 'user_id' }
  },
  required_vehicle_type: {
    // ✅ نوع مركبة مطلوب لطلبات هاد المتجر (اختياري، مثلاً متجر أثاث بده
    // Cab) - null = أي نوع مركبة مقبول
    type: DataTypes.STRING(30),
    allowNull: true
  },
  delivery_fee_inside_city: {
    // ✅ رسم التوصيل داخل نفس مدينة المتجر - هاد هو المصدر الحقيقي لـ
    // delivery_fee (يُنسخ عليه تلقائيًا بكل تحديث - راجع storeController.js)
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 10.0
  },
  delivery_fee_outside_city: {
    // ✅ رسم التوصيل لمدينة تانية غير مدينة المتجر - عرض/تسعير معلوماتي حاليًا
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 20.0
  },
  delivery_fee_occupied_areas: {
    // ✅ رسم التوصيل للمناطق المصنّفة "محتلة" - عرض/تسعير معلوماتي حاليًا
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 70.0
  },
  prep_time_minutes: {
    // ✅ وقت تحضير تقديري خاص بهاد المتجر (دقايق) - يستبدل الثابت العام
    // PREP_TIME_MIN بـ utils/geo.js لما يكون محدد
    type: DataTypes.INTEGER,
    defaultValue: 10
  },
  supports_delivery: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },
  supports_pickup: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  }
}, {
  tableName: 'restaurants',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = Restaurant;