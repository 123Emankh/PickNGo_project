// src/services/ai/aiTools.js
//
// المساعد الذكي: تعريف "الأدوات" (Function Calling) يلي الموديل يقدر يطلب
// تنفيذها لجلب بيانات حية من قاعدة البيانات. كل دالة هون مجرد استعلام
// Sequelize عادي بنفس أسلوب باقي services/ بالمشروع (دوال عادية، بدون
// classes) - الفرق الوحيد إنها مربوطة بتعريف "schema" يفهمه Gemini.
//
// ⚠️ قاعدة أمان أساسية بكل دالة هون: أبدًا ما منثق بأي معرّف هوية (user_id،
// customer_id...) يجي من الموديل/args - الهوية دايمًا من `user` المُتحقّق
// منه بالـ JWT (نفس user يلي جاي من middleware/auth.js)، ومنعيد فحص
// الملكية بالاستعلام نفسه (WHERE customer_id = user.user_id مثلًا). وكل
// استعلام بيستخدم attributes allowlist صريحة - أبدًا findAll/findOne بلا
// تحديد، لتجنب تسريب password أو أي عمود حساس بالغلط لسياق الموديل.
const { Op } = require('sequelize');
const { User, Order, OrderItem, Restaurant, Product, Coupon, SystemSettings } = require('../../models');
const { haversineKm } = require('../../utils/geo');
const { getRecommendedStores } = require('../analytics/recommendationService');
const { getEffectiveStatus } = require('../driverStatusService');

const ACTIVE_ORDER_STATUSES = ['Pending', 'Confirmed', 'Preparing', 'Ready', 'PickedUp'];

function round2(n) {
  return n === null || n === undefined ? null : Math.round(n * 100) / 100;
}

async function resolveRestaurant(nameOrId, extraWhere = {}) {
  if (!nameOrId) return null;
  const asId = Number(nameOrId);
  if (Number.isInteger(asId) && String(asId) === String(nameOrId).trim()) {
    return Restaurant.findOne({ where: { restaurant_id: asId, ...extraWhere } });
  }
  return Restaurant.findOne({
    where: { name: { [Op.like]: `%${String(nameOrId).trim()}%` }, ...extraWhere },
    order: [['review_count', 'DESC']]
  });
}

function formatOrderForChat(order) {
  return {
    order_number: order.order_number,
    status: order.status,
    restaurant_name: order.store ? order.store.name : null,
    driver_name: order.driver ? order.driver.full_name : null,
    final_amount: order.final_amount,
    order_time: order.order_time,
    estimated_delivery_time_minutes: order.estimated_delivery_time
  };
}

// ===========================
// 📌 Customer tools (متوفرة أيضًا للسائق - سياق "زبون عام" بس، بدون أدوات خاصة بالسائق)
// ===========================

async function get_my_orders(args, user) {
  const limit = Math.min(Number(args.limit) || 5, 20);
  const where = { customer_id: user.user_id };
  if (args.status) where.status = args.status;

  const orders = await Order.findAll({
    where,
    include: [
      { model: Restaurant, as: 'store', attributes: ['name'] },
      { model: User, as: 'driver', attributes: ['full_name'] }
    ],
    attributes: ['order_number', 'status', 'final_amount', 'order_time', 'estimated_delivery_time'],
    order: [['order_time', 'DESC']],
    limit
  });

  return { orders: orders.map(formatOrderForChat) };
}

async function get_order_status(args, user) {
  const where = { customer_id: user.user_id };
  if (args.order_number) {
    where.order_number = String(args.order_number).trim();
  }

  const order = await Order.findOne({
    where,
    include: [
      { model: Restaurant, as: 'store', attributes: ['name'] },
      { model: User, as: 'driver', attributes: ['full_name'] }
    ],
    attributes: ['order_number', 'status', 'final_amount', 'order_time', 'estimated_delivery_time', 'delivery_time'],
    order: args.order_number ? undefined : [['order_time', 'DESC']]
  });

  if (!order) return { found: false, message: 'No matching order found for this customer.' };
  return { found: true, order: formatOrderForChat(order) };
}

const RESTAURANT_LIST_ATTRS = ['restaurant_id', 'name', 'cuisine_type', 'rating', 'review_count', 'is_open', 'city', 'delivery_fee_inside_city', 'minimum_order', 'location_lat', 'location_lng'];

function formatRestaurantList(stores, args) {
  const hasLocation = typeof args.lat === 'number' && typeof args.lng === 'number';
  return stores.map((s) => ({
    restaurant_id: s.restaurant_id,
    name: s.name,
    cuisine_type: s.cuisine_type,
    rating: s.rating,
    is_open: s.is_open,
    city: s.city,
    delivery_fee: s.delivery_fee_inside_city,
    minimum_order: s.minimum_order,
    distance_km: hasLocation ? round2(haversineKm(args.lat, args.lng, s.location_lat, s.location_lng)) : null
  }));
}

async function search_restaurants(args) {
  const baseWhere = { is_active: true, approval_status: 'Approved' };
  const where = { ...baseWhere };
  if (args.query) where.name = { [Op.like]: `%${String(args.query).trim()}%` };
  if (args.category) where.cuisine_type = { [Op.like]: `%${String(args.category).trim()}%` };

  const stores = await Restaurant.findAll({
    where,
    attributes: RESTAURANT_LIST_ATTRS,
    order: [['rating', 'DESC']],
    limit: 8
  });

  if (stores.length > 0) {
    return { restaurants: formatRestaurantList(stores, args) };
  }

  // ✅ ما في تطابق تام (خصوصًا لما category ما بتطابق أي cuisine_type
  // موجود فعليًا) - منرجع بدائل عامة بنفس النداء، بدل ما نرجع قائمة فاضية
  // ونضغط على الموديل يعيد المحاولة بأشكال مختلفة لنفس السؤال (كان هاد
  // بالضبط سبب استنزاف كل جولات tool calling على سؤال "برجر" - راجع
  // systemPrompts.js لقاعدة "لا تعيد نفس الاستدعاء" المرافقة لهاد الحل).
  if (args.query || args.category) {
    const fallbackStores = await Restaurant.findAll({
      where: baseWhere,
      attributes: RESTAURANT_LIST_ATTRS,
      order: [['rating', 'DESC']],
      limit: 8
    });
    return {
      restaurants: [],
      note: 'No restaurant matched that exact search. Here are other available restaurants instead.',
      other_available_restaurants: formatRestaurantList(fallbackStores, args)
    };
  }

  return { restaurants: [] };
}

async function get_restaurant_details(args) {
  const store = await resolveRestaurant(args.restaurant_name_or_id, { is_active: true, approval_status: 'Approved' });
  if (!store) return { found: false };
  return {
    found: true,
    restaurant: {
      restaurant_id: store.restaurant_id,
      name: store.name,
      description: store.description,
      cuisine_type: store.cuisine_type,
      rating: store.rating,
      review_count: store.review_count,
      is_open: store.is_open,
      opening_time: store.opening_time,
      closing_time: store.closing_time,
      address: store.address,
      city: store.city,
      delivery_fee: store.delivery_fee_inside_city,
      minimum_order: store.minimum_order,
      supports_delivery: store.supports_delivery,
      supports_pickup: store.supports_pickup
    }
  };
}

async function search_products(args) {
  const where = { is_active: true };
  if (args.query) where.name = { [Op.like]: `%${String(args.query).trim()}%` };

  const storeWhere = { is_active: true, approval_status: 'Approved' };
  if (args.restaurant_name_or_id) {
    const store = await resolveRestaurant(args.restaurant_name_or_id, storeWhere);
    if (!store) return { products: [] };
    where.restaurant_id = store.restaurant_id;
  }

  const products = await Product.findAll({
    where,
    include: [{ model: Restaurant, as: 'store', where: storeWhere, attributes: ['name'] }],
    attributes: ['product_id', 'name', 'description', 'price', 'in_stock', 'average_rating'],
    order: [['average_rating', 'DESC']],
    limit: 10
  });

  return {
    products: products.map((p) => ({
      product_id: p.product_id,
      name: p.name,
      description: p.description,
      price: p.price,
      in_stock: p.in_stock,
      rating: p.average_rating,
      restaurant_name: p.store.name
    }))
  };
}

async function get_nearby_stores(args) {
  if (typeof args.lat !== 'number' || typeof args.lng !== 'number') {
    return { error: 'lat/lng are required to find nearby stores.' };
  }
  const radiusKm = Math.min(Number(args.radius_km) || 5, 20);

  const stores = await Restaurant.findAll({
    where: { is_active: true, approval_status: 'Approved' },
    attributes: ['restaurant_id', 'name', 'cuisine_type', 'rating', 'is_open', 'location_lat', 'location_lng'],
    limit: 100
  });

  const nearby = stores
    .map((s) => ({ store: s, distanceKm: haversineKm(args.lat, args.lng, s.location_lat, s.location_lng) }))
    .filter((x) => x.distanceKm !== null && x.distanceKm <= radiusKm)
    .sort((a, b) => a.distanceKm - b.distanceKm)
    .slice(0, 10);

  return {
    stores: nearby.map(({ store, distanceKm }) => ({
      restaurant_id: store.restaurant_id,
      name: store.name,
      cuisine_type: store.cuisine_type,
      rating: store.rating,
      is_open: store.is_open,
      distance_km: round2(distanceKm)
    }))
  };
}

async function explain_delivery_fee(args) {
  if (!args.restaurant_name_or_id) {
    return {
      general_explanation:
        'Delivery fee depends on the store: it differs for inside-city, outside-city, and specific occupied-area deliveries. Ask about a specific restaurant for exact numbers.'
    };
  }
  const store = await resolveRestaurant(args.restaurant_name_or_id, { is_active: true });
  if (!store) return { found: false };
  return {
    found: true,
    restaurant_name: store.name,
    delivery_fee_inside_city: store.delivery_fee_inside_city,
    delivery_fee_outside_city: store.delivery_fee_outside_city,
    delivery_fee_occupied_areas: store.delivery_fee_occupied_areas,
    minimum_order: store.minimum_order
  };
}

async function get_loyalty_balance(args, user) {
  // ✅ req.user (جاي من middleware/auth.js) نسخة مصغّرة {user_id, email,
  // role, status} بس - ما فيها loyalty_points أبدًا، فـ user.loyalty_points
  // هون كانت دايمًا undefined (0 دايمًا) بغض النظر عن الرصيد الفعلي. لازم
  // نجيبه fresh من الداتابيز، نفس نمط loyaltyController.js getMyLoyalty.
  const [settings, freshUser] = await Promise.all([
    SystemSettings.findOne({ attributes: ['loyalty_enabled', 'points_earn_rate', 'points_redeem_rate'] }),
    User.findByPk(user.user_id, { attributes: ['loyalty_points'] })
  ]);
  return {
    loyalty_enabled: settings ? settings.loyalty_enabled : true,
    points_balance: freshUser ? freshUser.loyalty_points : 0,
    points_earn_rate: settings ? settings.points_earn_rate : null,
    points_redeem_rate: settings ? settings.points_redeem_rate : null,
    currency: 'ILS'
  };
}

async function get_active_coupons(args) {
  const where = {
    is_active: true,
    [Op.or]: [{ valid_until: null }, { valid_until: { [Op.gte]: new Date() } }]
  };
  if (args.restaurant_name_or_id) {
    const store = await resolveRestaurant(args.restaurant_name_or_id);
    where.restaurant_id = store ? store.restaurant_id : null;
  } else {
    where.restaurant_id = null; // كوبونات عامة على المنصة بدون تحديد متجر
  }

  const coupons = await Coupon.findAll({
    where,
    attributes: ['code', 'discount_type', 'discount_value', 'min_order_amount', 'max_discount_amount', 'valid_until'],
    limit: 10
  });

  return {
    coupons: coupons.map((c) => ({
      code: c.code,
      discount_type: c.discount_type,
      discount_value: c.discount_value,
      min_order_amount: c.min_order_amount,
      max_discount_amount: c.max_discount_amount,
      valid_until: c.valid_until
    }))
  };
}

async function recommend_for_me(args, user) {
  const lat = typeof args.lat === 'number' ? args.lat : undefined;
  const lng = typeof args.lng === 'number' ? args.lng : undefined;
  const stores = await getRecommendedStores(user.user_id, { lat, lng }, 5);
  return {
    recommendations: stores.map((s) => ({
      name: s.name,
      cuisine_type: s.cuisine_type,
      rating: s.rating,
      reason: s.recommendation_reason
    }))
  };
}

const customerToolDefs = [
  {
    declaration: {
      name: 'get_my_orders',
      description: "List the authenticated customer's recent orders.",
      parameters: { type: 'OBJECT', properties: { status: { type: 'STRING', description: 'Filter by order status (optional)' }, limit: { type: 'NUMBER' } } }
    },
    handler: get_my_orders
  },
  {
    declaration: {
      name: 'get_order_status',
      description: "Get the status/ETA of a specific order (by order_number) or the customer's most recent order if no order_number is given.",
      parameters: { type: 'OBJECT', properties: { order_number: { type: 'STRING' } } }
    },
    handler: get_order_status
  },
  {
    declaration: {
      name: 'search_restaurants',
      description: 'Search approved, active restaurants/stores by name or category.',
      parameters: { type: 'OBJECT', properties: { query: { type: 'STRING' }, category: { type: 'STRING' }, lat: { type: 'NUMBER' }, lng: { type: 'NUMBER' } } }
    },
    handler: search_restaurants
  },
  {
    declaration: {
      name: 'get_restaurant_details',
      description: 'Get details (hours, rating, fees, address) of one restaurant by name or id.',
      parameters: { type: 'OBJECT', properties: { restaurant_name_or_id: { type: 'STRING' } }, required: ['restaurant_name_or_id'] }
    },
    handler: get_restaurant_details
  },
  {
    declaration: {
      name: 'search_products',
      description: 'Search products/menu items by name, optionally scoped to one restaurant.',
      parameters: { type: 'OBJECT', properties: { query: { type: 'STRING' }, restaurant_name_or_id: { type: 'STRING' } } }
    },
    handler: search_products
  },
  {
    declaration: {
      name: 'get_nearby_stores',
      description: 'List open, approved stores near a given latitude/longitude.',
      parameters: { type: 'OBJECT', properties: { lat: { type: 'NUMBER' }, lng: { type: 'NUMBER' }, radius_km: { type: 'NUMBER' } }, required: ['lat', 'lng'] }
    },
    handler: get_nearby_stores
  },
  {
    declaration: {
      name: 'explain_delivery_fee',
      description: 'Explain how delivery fees work, optionally for a specific restaurant.',
      parameters: { type: 'OBJECT', properties: { restaurant_name_or_id: { type: 'STRING' } } }
    },
    handler: explain_delivery_fee
  },
  {
    declaration: {
      name: 'get_loyalty_balance',
      description: "Get the authenticated customer's loyalty points balance and how points are earned/redeemed.",
      parameters: { type: 'OBJECT', properties: {} }
    },
    handler: get_loyalty_balance
  },
  {
    declaration: {
      name: 'get_active_coupons',
      description: 'List currently active/valid coupons, platform-wide or for one restaurant.',
      parameters: { type: 'OBJECT', properties: { restaurant_name_or_id: { type: 'STRING' } } }
    },
    handler: get_active_coupons
  },
  {
    declaration: {
      name: 'recommend_for_me',
      description: "Get personalized restaurant recommendations for the authenticated customer based on their order/favorite history.",
      parameters: { type: 'OBJECT', properties: { lat: { type: 'NUMBER' }, lng: { type: 'NUMBER' } } }
    },
    handler: recommend_for_me
  }
];

// ===========================
// 📌 Business/Restaurant owner tools - قراءة/سياق فقط (الكتابة الفعلية للنص
// توليد بحت من الموديل، ما بتحتاج tool - بس بدها سياق دقيق عن متجر/منتجات المستخدم)
// ===========================

async function get_my_store_context(args, user) {
  const store = await Restaurant.findOne({
    where: { user_id: user.user_id },
    attributes: ['restaurant_id', 'name', 'description', 'cuisine_type', 'city']
  });
  if (!store) return { has_store: false };
  return {
    has_store: true,
    store: { name: store.name, description: store.description, cuisine_type: store.cuisine_type, city: store.city }
  };
}

async function get_my_products(args, user) {
  const store = await Restaurant.findOne({ where: { user_id: user.user_id }, attributes: ['restaurant_id'] });
  if (!store) return { products: [] };

  const where = { restaurant_id: store.restaurant_id };
  if (args.query) where.name = { [Op.like]: `%${String(args.query).trim()}%` };

  const products = await Product.findAll({
    where,
    attributes: ['product_id', 'name', 'description', 'price', 'is_active'],
    limit: 15
  });

  return { products: products.map((p) => ({ product_id: p.product_id, name: p.name, description: p.description, price: p.price, is_active: p.is_active })) };
}

const businessToolDefs = [
  {
    declaration: {
      name: 'get_my_store_context',
      description: "Get the authenticated store owner's own restaurant profile (name, cuisine, description) to help write accurate content about it.",
      parameters: { type: 'OBJECT', properties: {} }
    },
    handler: get_my_store_context
  },
  {
    declaration: {
      name: 'get_my_products',
      description: "List the authenticated store owner's own products, optionally filtered by name, to ground description/title generation in real product data.",
      parameters: { type: 'OBJECT', properties: { query: { type: 'STRING' } } }
    },
    handler: get_my_products
  }
];

// ===========================
// 📌 Admin tools
// ===========================

function startOfPeriod(period) {
  const now = new Date();
  if (period === 'week') {
    const d = new Date(now);
    d.setDate(d.getDate() - 7);
    return d;
  }
  if (period === 'month') {
    const d = new Date(now);
    d.setMonth(d.getMonth() - 1);
    return d;
  }
  return new Date(now.getFullYear(), now.getMonth(), now.getDate()); // 'today' (افتراضي)
}

async function get_today_order_stats() {
  const start = startOfPeriod('today');
  const orders = await Order.findAll({
    where: { order_time: { [Op.gte]: start } },
    attributes: ['status', 'final_amount']
  });

  const byStatus = {};
  let deliveredRevenue = 0;
  for (const o of orders) {
    byStatus[o.status] = (byStatus[o.status] || 0) + 1;
    if (o.status === 'Delivered') deliveredRevenue += parseFloat(o.final_amount) || 0;
  }

  return { date: start.toISOString().slice(0, 10), total_orders: orders.length, by_status: byStatus, delivered_revenue: round2(deliveredRevenue) };
}

async function get_top_selling_restaurant(args) {
  const start = startOfPeriod(args.period || 'today');
  const orders = await Order.findAll({
    where: { status: 'Delivered', order_time: { [Op.gte]: start } },
    include: [{ model: Restaurant, as: 'store', attributes: ['name'] }],
    attributes: ['restaurant_id', 'final_amount']
  });

  const totals = new Map();
  for (const o of orders) {
    const key = o.restaurant_id;
    const prev = totals.get(key) || { name: o.store ? o.store.name : `#${key}`, revenue: 0, orders: 0 };
    prev.revenue += parseFloat(o.final_amount) || 0;
    prev.orders += 1;
    totals.set(key, prev);
  }

  const ranked = [...totals.values()].sort((a, b) => b.revenue - a.revenue).slice(0, 5);
  return { period: args.period || 'today', top_restaurants: ranked.map((r) => ({ name: r.name, revenue: round2(r.revenue), orders: r.orders })) };
}

async function get_online_drivers() {
  const drivers = await User.findAll({
    where: { role: 'Driver' },
    attributes: ['user_id', 'full_name', 'driver_status', 'is_active', 'status', 'location_updated_at']
  });

  const online = drivers.filter((d) => getEffectiveStatus(d) !== 'Offline');
  return {
    online_count: online.length,
    drivers: online.map((d) => ({ name: d.full_name, status: getEffectiveStatus(d) }))
  };
}

async function get_pending_store_approvals() {
  const stores = await Restaurant.findAll({
    where: { approval_status: 'Pending' },
    attributes: ['restaurant_id', 'name', 'city', 'region', 'created_at'],
    order: [['created_at', 'ASC']],
    limit: 20
  });

  return {
    pending_count: stores.length,
    stores: stores.map((s) => ({ name: s.name, city: s.city, region: s.region, submitted_at: s.created_at }))
  };
}

const adminToolDefs = [
  {
    declaration: { name: 'get_today_order_stats', description: "Get today's order counts broken down by status, plus delivered revenue.", parameters: { type: 'OBJECT', properties: {} } },
    handler: get_today_order_stats
  },
  {
    declaration: {
      name: 'get_top_selling_restaurant',
      description: 'Get the top restaurants by revenue for a period.',
      parameters: { type: 'OBJECT', properties: { period: { type: 'STRING', description: "'today', 'week', or 'month'" } } }
    },
    handler: get_top_selling_restaurant
  },
  {
    declaration: { name: 'get_online_drivers', description: 'List drivers who are currently online (Available or Busy).', parameters: { type: 'OBJECT', properties: {} } },
    handler: get_online_drivers
  },
  {
    declaration: { name: 'get_pending_store_approvals', description: 'List stores/restaurants waiting for admin approval.', parameters: { type: 'OBJECT', properties: {} } },
    handler: get_pending_store_approvals
  }
];

/**
 * بيرجع تعريفات + معالجات الأدوات المسموحة لدور معين، معبّاة (bound) على
 * المستخدم المُتحقّق منه الحالي. Driver بيرجع مصفوفة فاضية عن قصد (دعم FAQ
 * عام فقط بهاي النسخة - بدون أدوات خاصة بالسائق زي الأرباح).
 */
function getToolsForRole(role, user) {
  let defs = [];
  if (role === 'Customer') defs = customerToolDefs;
  else if (role === 'Restaurant') defs = businessToolDefs;
  else if (role === 'Admin') defs = adminToolDefs;
  else defs = []; // Driver وأي دور آخر

  const declarations = defs.map((d) => d.declaration);
  const handlers = {};
  for (const d of defs) {
    handlers[d.declaration.name] = (args) => d.handler(args || {}, user);
  }
  return { declarations, handlers };
}

module.exports = { getToolsForRole };
