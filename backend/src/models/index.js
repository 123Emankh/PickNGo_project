// src/models/index.js
const sequelize = require('../config/database');
const User = require('./User');
const Otp = require('./Otp');
const Category = require('./Category');
const Restaurant = require('./Restaurant');
const Product = require('./Product');
const Order = require('./Order');
const OrderItem = require('./OrderItem');
const Review = require('./Review');
const ProductReview = require('./ProductReview');
const Coupon = require('./Coupon');
const CouponRedemption = require('./CouponRedemption');
const Favorite = require('./Favorite');
const ProductVariant = require('./ProductVariant');
const ProductAddon = require('./ProductAddon');
const ProductExclusion = require('./ProductExclusion');
const ProductOptionGroup = require('./ProductOptionGroup');
const ProductOptionValue = require('./ProductOptionValue');
const DeliveryGroup = require('./DeliveryGroup');
const DeliveryGroupItem = require('./DeliveryGroupItem');
const Notification = require('./Notification');
const SystemSettings = require('./SystemSettings');
const LoyaltyTransaction = require('./LoyaltyTransaction');
const AiChatMessage = require('./AiChatMessage');

// ===========================
// 📌 العلاقات بين الجداول (Associations)
// ===========================

// مستخدم (صاحب متجر) ↔ متجر واحد أو أكتر
User.hasMany(Restaurant, { foreignKey: 'user_id', as: 'stores' });
Restaurant.belongsTo(User, { foreignKey: 'user_id', as: 'owner' });

// شركة توصيل (User بـ business_type='Fleet / Company') ↔ سائقين تابعين إلها
User.belongsTo(User, { foreignKey: 'company_id', as: 'company' });
User.hasMany(User, { foreignKey: 'company_id', as: 'companyDrivers' });

// فئة ↔ متاجر
Category.hasMany(Restaurant, { foreignKey: 'category_id', as: 'stores' });
Restaurant.belongsTo(Category, { foreignKey: 'category_id', as: 'category' });

// متجر ↔ منتجات
Restaurant.hasMany(Product, { foreignKey: 'restaurant_id', as: 'products' });
Product.belongsTo(Restaurant, { foreignKey: 'restaurant_id', as: 'store' });

// طلب ↔ زبون / متجر / سائق
User.hasMany(Order, { foreignKey: 'customer_id', as: 'customerOrders' });
Order.belongsTo(User, { foreignKey: 'customer_id', as: 'customer' });

Restaurant.hasMany(Order, { foreignKey: 'restaurant_id', as: 'orders' });
Order.belongsTo(Restaurant, { foreignKey: 'restaurant_id', as: 'store' });

User.hasMany(Order, { foreignKey: 'driver_id', as: 'driverOrders' });
Order.belongsTo(User, { foreignKey: 'driver_id', as: 'driver' });

// طلب ↔ سائق معروض عليه حاليًا (بانتظار رد - Phase 3 Smart Assignment)
Order.belongsTo(User, { foreignKey: 'offered_driver_id', as: 'offeredDriver' });

// متجر / طلب ↔ شركة توصيل مفضّلة (اختياري)
Restaurant.belongsTo(User, { foreignKey: 'preferred_company_id', as: 'preferredCompany' });
Order.belongsTo(User, { foreignKey: 'preferred_company_id', as: 'preferredCompany' });

// طلب ↔ عناصر الطلب ↔ منتجات
Order.hasMany(OrderItem, { foreignKey: 'order_id', as: 'items' });
OrderItem.belongsTo(Order, { foreignKey: 'order_id' });

Product.hasMany(OrderItem, { foreignKey: 'product_id' });
OrderItem.belongsTo(Product, { foreignKey: 'product_id', as: 'product' });

// طلب ↔ تقييم واحد (بعد التسليم) ↔ زبون / متجر
Order.hasOne(Review, { foreignKey: 'order_id', as: 'review' });
Review.belongsTo(Order, { foreignKey: 'order_id' });

Review.belongsTo(User, { foreignKey: 'customer_id', as: 'customer' });
Review.belongsTo(Restaurant, { foreignKey: 'restaurant_id', as: 'store' });
Restaurant.hasMany(Review, { foreignKey: 'restaurant_id', as: 'reviews' });

// طلب ↔ تقييمات منتجات (تقييم واحد لكل منتج بالطلب - راجع reviewController
// syncProductReviews) ↔ زبون / منتج - تقييم المتجر فوق يضل مستقل تمامًا عنها
Order.hasMany(ProductReview, { foreignKey: 'order_id', as: 'productReviews' });
ProductReview.belongsTo(Order, { foreignKey: 'order_id' });

ProductReview.belongsTo(User, { foreignKey: 'customer_id', as: 'customer' });
ProductReview.belongsTo(Product, { foreignKey: 'product_id', as: 'product' });
Product.hasMany(ProductReview, { foreignKey: 'product_id', as: 'reviews' });

// كوبونات: متجر (أو عام لو null) ↔ كوبونات ↔ استخدامات لكل طلب
Restaurant.hasMany(Coupon, { foreignKey: 'restaurant_id', as: 'coupons' });
Coupon.belongsTo(Restaurant, { foreignKey: 'restaurant_id', as: 'store' });
Coupon.belongsTo(User, { foreignKey: 'created_by', as: 'creator' });

Coupon.hasMany(CouponRedemption, { foreignKey: 'coupon_id', as: 'redemptions' });
CouponRedemption.belongsTo(Coupon, { foreignKey: 'coupon_id' });
CouponRedemption.belongsTo(User, { foreignKey: 'customer_id', as: 'customer' });

Order.hasOne(CouponRedemption, { foreignKey: 'order_id', as: 'couponRedemption' });
CouponRedemption.belongsTo(Order, { foreignKey: 'order_id' });

// مفضلة: زبون ↔ متاجر (many-to-many عبر جدول favorites)
User.hasMany(Favorite, { foreignKey: 'user_id', as: 'favorites' });
Favorite.belongsTo(User, { foreignKey: 'user_id', as: 'customer' });

Restaurant.hasMany(Favorite, { foreignKey: 'restaurant_id', as: 'favoritedBy' });
Favorite.belongsTo(Restaurant, { foreignKey: 'restaurant_id', as: 'store' });

// مفضلة: زبون ↔ منتجات (نفس جدول favorites - عمود product_id بدل restaurant_id)
Product.hasMany(Favorite, { foreignKey: 'product_id', as: 'favoritedBy' });
Favorite.belongsTo(Product, { foreignKey: 'product_id', as: 'product' });

// منتج ↔ أحجام/خيارات (سمول/ميديم/لارج...) بأسعار مختلفة
Product.hasMany(ProductVariant, { foreignKey: 'product_id', as: 'variants' });
ProductVariant.belongsTo(Product, { foreignKey: 'product_id' });

// منتج ↔ إضافات اختيارية بسعر (Extra Cheese, Turkey Bacon...)
Product.hasMany(ProductAddon, { foreignKey: 'product_id', as: 'addons' });
ProductAddon.belongsTo(Product, { foreignKey: 'product_id' });

// منتج ↔ طلبات خاصة/استثناءات محددة سلفًا (No Onions, No Pickles...)
Product.hasMany(ProductExclusion, { foreignKey: 'product_id', as: 'exclusions' });
ProductExclusion.belongsTo(Product, { foreignKey: 'product_id' });

// منتج ↔ مجموعات مواصفات مخصصة (بيحددها صاحب المحل، مثلاً "نوع الخبز"/"اللون")
// ↔ قيم كل مجموعة (بسعر إضافي اختياري لكل قيمة)
Product.hasMany(ProductOptionGroup, { foreignKey: 'product_id', as: 'optionGroups' });
ProductOptionGroup.belongsTo(Product, { foreignKey: 'product_id' });

ProductOptionGroup.hasMany(ProductOptionValue, { foreignKey: 'group_id', as: 'values' });
ProductOptionValue.belongsTo(ProductOptionGroup, { foreignKey: 'group_id', as: 'group' });

OrderItem.belongsTo(ProductVariant, { foreignKey: 'variant_id', as: 'variant' });

// رحلة توصيل مجمّعة (Grouped Delivery / Phase 4 - Smart Order Clustering):
// زبون/سائق مسند/سائق معروض عليه حاليًا ↔ مجموعة، ومجموعة ↔ طلباتها الأعضاء
DeliveryGroup.belongsTo(User, { foreignKey: 'customer_id', as: 'customer' });
DeliveryGroup.belongsTo(User, { foreignKey: 'driver_id', as: 'driver' });
DeliveryGroup.belongsTo(User, { foreignKey: 'offered_driver_id', as: 'offeredDriver' });

DeliveryGroup.hasMany(DeliveryGroupItem, { foreignKey: 'group_id', as: 'items' });
DeliveryGroupItem.belongsTo(DeliveryGroup, { foreignKey: 'group_id' });
DeliveryGroupItem.belongsTo(Order, { foreignKey: 'order_id', as: 'order' });

Order.belongsTo(DeliveryGroup, { foreignKey: 'delivery_group_id', as: 'deliveryGroup' });
DeliveryGroup.hasMany(Order, { foreignKey: 'delivery_group_id', as: 'orders' });

// إشعارات (Phase 4): مستخدم ↔ إشعاراته
User.hasMany(Notification, { foreignKey: 'user_id', as: 'notifications' });
Notification.belongsTo(User, { foreignKey: 'user_id' });

// نظام النقاط (Loyalty): مستخدم ↔ دفتر حركاته، طلب ↔ حركاته (عادة وحدة، بس
// نظريًا ممكن أكتر من حركة لنفس الطلب - Earned ثم Reversed مثلًا)
User.hasMany(LoyaltyTransaction, { foreignKey: 'user_id', as: 'loyaltyTransactions' });
LoyaltyTransaction.belongsTo(User, { foreignKey: 'user_id' });
Order.hasMany(LoyaltyTransaction, { foreignKey: 'order_id', as: 'loyaltyTransactions' });
LoyaltyTransaction.belongsTo(Order, { foreignKey: 'order_id' });

// المساعد الذكي (Gemini): مستخدم ↔ سجل رسائل محادثته
User.hasMany(AiChatMessage, { foreignKey: 'user_id', as: 'aiChatMessages' });
AiChatMessage.belongsTo(User, { foreignKey: 'user_id' });

// Export all models
module.exports = {
  sequelize,
  User,
  Otp,
  Category,
  Restaurant,
  Product,
  Order,
  OrderItem,
  Review,
  ProductReview,
  Coupon,
  CouponRedemption,
  Favorite,
  ProductVariant,
  ProductAddon,
  ProductExclusion,
  ProductOptionGroup,
  ProductOptionValue,
  DeliveryGroup,
  DeliveryGroupItem,
  Notification,
  SystemSettings,
  LoyaltyTransaction,
  AiChatMessage
};