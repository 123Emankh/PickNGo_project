// src/controllers/storeController.js
const { Op } = require('sequelize');
const { Category, Restaurant, Product, User, Review, Favorite, ProductVariant, ProductAddon, ProductExclusion, ProductOptionGroup, ProductOptionValue, Coupon, Order, sequelize } = require('../models');
const { formatReview } = require('./reviewController');
const { haversineKm, estimateDeliveryRange, isOpenNow } = require('../utils/geo');
const { validatePalestineBounds, validateNonNegativeNumber } = require('../utils/validators');
const { notifyRole } = require('../services/notificationService');
const { getIo } = require('../sockets');
const { computeStoreAnalytics } = require('../services/analytics/storeAnalyticsService');

// ✅ كل الحقول الرقمية (رسوم/حد أدنى/وقت تحضير) يلي لازم تكون رقم غير سالب
// لو انبعتت - تُستخدم بـ createStore وupdateMyStore سوا
const NON_NEGATIVE_NUMERIC_FIELDS = [
  'delivery_fee_inside_city', 'delivery_fee_outside_city', 'delivery_fee_occupied_areas',
  'minimum_order', 'prep_time_minutes'
];

function findInvalidNumericField(body) {
  return NON_NEGATIVE_NUMERIC_FIELDS.find((field) => body[field] !== undefined && !validateNonNegativeNumber(body[field]));
}

// ===========================
// 📌 GET /api/stores/categories
// ===========================
const getCategories = async (req, res) => {
  try {
    const categories = await Category.findAll({
      order: [['sort_order', 'ASC']]
    });

    // ✅ عدد المتاجر/المنتجات الفعلي لكل فئة (نفس منطق adminController.getCategories
    // بالضبط) - بس هون مقصورة على المتاجر النشطة/المعتمدة والمنتجات النشطة، لأنها
    // بتترجع للكستمر مباشرة (الأدمن بشوف كل شي بغض النظر عن الحالة).
    const [storeCounts, productCounts] = await Promise.all([
      Restaurant.findAll({
        where: { is_active: true, approval_status: 'Approved' },
        attributes: ['category_id', [sequelize.fn('COUNT', sequelize.col('restaurant_id')), 'count']],
        group: ['category_id'],
        raw: true
      }),
      Product.findAll({
        where: { is_active: true },
        attributes: [
          [sequelize.col('store.category_id'), 'category_id'],
          [sequelize.fn('COUNT', sequelize.col('Product.product_id')), 'count']
        ],
        include: [{ model: Restaurant, as: 'store', where: { is_active: true, approval_status: 'Approved' }, attributes: [] }],
        group: ['store.category_id'],
        raw: true
      })
    ]);
    const storeCountByCategory = new Map(storeCounts.map((r) => [r.category_id, parseInt(r.count, 10)]));
    const productCountByCategory = new Map(productCounts.map((r) => [r.category_id, parseInt(r.count, 10)]));

    res.status(200).json({
      success: true,
      categories: categories.map(c => ({
        id: c.category_id,
        name: c.name,
        icon: c.icon,
        sort_order: c.sort_order,
        store_count: storeCountByCategory.get(c.category_id) || 0,
        product_count: productCountByCategory.get(c.category_id) || 0
      }))
    });
  } catch (error) {
    console.error('❌ Get categories error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching categories' });
  }
};

// ===========================
// 📌 GET /api/stores
// query params (كلها اختيارية): category_id, search, min_rating, max_price,
// cuisine_type, open_now=true, featured_only=true, sort (rating|distance|popularity|newest|most_ordered),
// lat, lng, page, limit
// ===========================
const getStores = async (req, res) => {
  try {
    const {
      category_id, search, min_rating, max_price, cuisine_type,
      open_now, featured_only, free_delivery, has_discount, sort, lat, lng
    } = req.query;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;

    // ---- فلاتر على مستوى SQL (رخيصة/قابلة للفهرسة) ----
    const where = { is_active: true, approval_status: 'Approved' };
    if (category_id) where.category_id = category_id;
    if (search) where.name = { [Op.like]: `%${search}%` };
    if (min_rating) where.rating = { [Op.gte]: parseFloat(min_rating) };
    if (cuisine_type) where.cuisine_type = cuisine_type;
    if (featured_only === 'true') where.is_featured = true;
    if (free_delivery === 'true') where.delivery_fee_inside_city = 0;

    if (max_price) {
      // ما منعمل include مباشر على Product لأنه بيكرر صفوف المتجر لكل منتج مطابق -
      // بدل هيك منجيب أول restaurant_id يلي عندها منتج بسعر مناسب وبعدين نفلتر فيها
      const cheapProducts = await Product.findAll({
        where: { price: { [Op.lte]: parseFloat(max_price) }, is_active: true },
        attributes: ['restaurant_id'],
        group: ['restaurant_id']
      });
      const ids = cheapProducts.map((p) => p.restaurant_id);
      where.restaurant_id = { [Op.in]: ids.length ? ids : [-1] };
    }

    const stores = await Restaurant.findAll({ where });

    // ---- المفضلة (بس لو المستخدم مسجل دخول عبر optionalAuth) ----
    let favoriteIds = new Set();
    if (req.user) {
      const favs = await Favorite.findAll({
        where: { user_id: req.user.user_id },
        attributes: ['restaurant_id']
      });
      favoriteIds = new Set(favs.map((f) => f.restaurant_id));
    }

    const userLat = lat ? parseFloat(lat) : null;
    const userLng = lng ? parseFloat(lng) : null;

    // ---- شارة الخصم (أفضل كوبون فعّال لكل متجر بالقائمة) ----
    const discountLabels = await getDiscountLabels(stores.map((s) => s.restaurant_id));

    // ---- إثراء البيانات (المسافة، وقت التوصيل، مفتوح الآن، مفضلة، خصم) ----
    let enriched = stores.map((s) => {
      const distanceKm = (userLat !== null && userLng !== null)
        ? haversineKm(userLat, userLng, parseFloat(s.location_lat), parseFloat(s.location_lng))
        : null;
      return {
        raw: s,
        formatted: formatStore(s, {
          distanceKm,
          isFavorited: favoriteIds.has(s.restaurant_id),
          discountLabel: discountLabels.get(s.restaurant_id) || null
        })
      };
    });

    // ---- فلترة "مفتوح الآن" (ما فيها تنعمل بـ SQL بسبب منطق التفاف منتصف الليل) ----
    if (open_now === 'true') {
      enriched = enriched.filter((e) => e.formatted.is_open_now);
    }

    // ---- فلترة "عروض اليوم" (شارة الخصم محسوبة فوق أصلًا - نعيد استخدامها بدل استعلام جديد) ----
    if (has_discount === 'true') {
      enriched = enriched.filter((e) => !!e.formatted.discount_label);
    }

    // ---- ترتيب "الأكثر طلباً" (عدد طلبات Delivered فعلي لكل متجر - مختلف عن
    // popularity يلي مبني على عدد التقييمات) - نحسبه فقط لو مطلوب فعلاً، عشان
    // ما نضيف استعلام تجميع إضافي لكل طلب عادي ---
    let orderCountByStore = null;
    if (sort === 'most_ordered') {
      const orderCounts = await Order.findAll({
        where: { status: 'Delivered' },
        attributes: ['restaurant_id', [sequelize.fn('COUNT', sequelize.col('order_id')), 'count']],
        group: ['restaurant_id'],
        raw: true
      });
      orderCountByStore = new Map(orderCounts.map((r) => [r.restaurant_id, parseInt(r.count, 10)]));
    }

    // ---- الترتيب ----
    const sortKey = sort || 'rating';
    enriched.sort((a, b) => {
      if (sortKey === 'distance' && userLat !== null) {
        return (a.formatted.distance_km ?? Infinity) - (b.formatted.distance_km ?? Infinity);
      }
      if (sortKey === 'popularity') {
        return (b.raw.review_count || 0) - (a.raw.review_count || 0);
      }
      if (sortKey === 'newest') {
        return new Date(b.raw.created_at) - new Date(a.raw.created_at);
      }
      if (sortKey === 'most_ordered') {
        return (orderCountByStore.get(b.raw.restaurant_id) || 0) - (orderCountByStore.get(a.raw.restaurant_id) || 0);
      }
      return (b.raw.rating || 0) - (a.raw.rating || 0); // default: rating
    });

    // ---- الترقيم (Pagination) ----
    const total = enriched.length;
    const startIdx = (page - 1) * limit;
    const pageItems = enriched.slice(startIdx, startIdx + limit).map((e) => e.formatted);

    res.status(200).json({
      success: true,
      stores: pageItems,
      total,
      page,
      limit,
      has_more: startIdx + limit < total
    });
  } catch (error) {
    console.error('❌ Get stores error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching stores' });
  }
};

// ===========================
// 📌 GET /api/stores/popular-products  (منتجات "الأكثر رواجًا" عبر كل المتاجر)
// ⚠️ لازم تكون مسجلة قبل /:id بالراوتس (نفس فخ /my-store)
// ===========================
const getPopularProducts = async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 8;

    const products = await Product.findAll({
      where: { is_active: true, in_stock: true },
      include: [
        {
          model: Restaurant,
          as: 'store',
          where: { is_active: true, approval_status: 'Approved' },
          attributes: ['restaurant_id', 'name', 'rating', 'review_count']
        },
        { model: ProductVariant, as: 'variants' },
        { model: ProductAddon, as: 'addons' },
        { model: ProductExclusion, as: 'exclusions' },
        { model: ProductOptionGroup, as: 'optionGroups', include: [{ model: ProductOptionValue, as: 'values' }] }
      ],
      order: [
        ['total_reviews', 'DESC'],
        ['average_rating', 'DESC']
      ],
      limit
    });

    res.status(200).json({
      success: true,
      products: products.map((p) => ({
        ...formatProduct(p),
        store_name: p.store ? p.store.name : ''
      }))
    });
  } catch (error) {
    console.error('❌ Get popular products error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching popular products' });
  }
};

// ===========================
// 📌 GET /api/stores/new-arrivals  (منتجات "وصل حديثًا" عبر كل المتاجر - الأحدث أولًا)
// ⚠️ لازم تكون مسجلة قبل /:id بالراوتس (نفس فخ /popular-products)
// ===========================
const getNewArrivals = async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 8;

    const products = await Product.findAll({
      where: { is_active: true, in_stock: true },
      include: [
        {
          model: Restaurant,
          as: 'store',
          where: { is_active: true, approval_status: 'Approved' },
          attributes: ['restaurant_id', 'name', 'rating', 'review_count']
        },
        { model: ProductVariant, as: 'variants' },
        { model: ProductAddon, as: 'addons' },
        { model: ProductExclusion, as: 'exclusions' },
        { model: ProductOptionGroup, as: 'optionGroups', include: [{ model: ProductOptionValue, as: 'values' }] }
      ],
      order: [['created_at', 'DESC']],
      limit
    });

    res.status(200).json({
      success: true,
      products: products.map((p) => ({
        ...formatProduct(p),
        store_name: p.store ? p.store.name : ''
      }))
    });
  } catch (error) {
    console.error('❌ Get new arrivals error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching new arrivals' });
  }
};

// ===========================
// 📌 GET /api/stores/:id  (تفاصيل المتجر + منتجاته)
// ===========================
const getStoreDetail = async (req, res) => {
  try {
    const store = await Restaurant.findByPk(req.params.id, {
      include: [{
        model: Product,
        as: 'products',
        where: { is_active: true },
        required: false,
        include: [
          { model: ProductVariant, as: 'variants' },
          { model: ProductAddon, as: 'addons' },
          { model: ProductExclusion, as: 'exclusions' },
          { model: ProductOptionGroup, as: 'optionGroups', include: [{ model: ProductOptionValue, as: 'values' }] }
        ]
      }]
    });

    if (!store) {
      return res.status(404).json({ success: false, message: 'Store not found' });
    }

    let isFavorited = false;
    let favoritedProductIds = new Set();
    if (req.user) {
      const fav = await Favorite.findOne({
        where: { user_id: req.user.user_id, restaurant_id: store.restaurant_id }
      });
      isFavorited = !!fav;

      const productIds = (store.products || []).map((p) => p.product_id);
      if (productIds.length) {
        const productFavs = await Favorite.findAll({
          where: { user_id: req.user.user_id, product_id: productIds },
          attributes: ['product_id']
        });
        favoritedProductIds = new Set(productFavs.map((f) => f.product_id));
      }
    }

    const { lat, lng } = req.query;
    const distanceKm = (lat && lng)
      ? haversineKm(parseFloat(lat), parseFloat(lng), parseFloat(store.location_lat), parseFloat(store.location_lng))
      : null;

    const discountLabels = await getDiscountLabels([store.restaurant_id]);

    res.status(200).json({
      success: true,
      store: formatStore(store, {
        distanceKm,
        isFavorited,
        discountLabel: discountLabels.get(store.restaurant_id) || null
      }),
      products: (store.products || []).map((p) =>
        formatProduct(p, { isFavorited: favoritedProductIds.has(p.product_id) })
      )
    });
  } catch (error) {
    console.error('❌ Get store detail error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching store details' });
  }
};

// ===========================
// 📌 POST /api/stores  (صاحب متجر بينشئ متجره — Restaurant role فقط)
// ===========================
const createStore = async (req, res) => {
  try {
    const {
      name, description, cuisine_type, category_id, image_url,
      address, location_lat, location_lng, city, region, phone, email,
      opening_time, closing_time, minimum_order,
      delivery_fee_inside_city, delivery_fee_outside_city, delivery_fee_occupied_areas,
      prep_time_minutes, supports_delivery, supports_pickup
    } = req.body;

    if (!name || !address || !location_lat || !location_lng || !city || !region || !phone) {
      return res.status(400).json({ success: false, message: 'Missing required store fields' });
    }

    if (!validatePalestineBounds(location_lat, location_lng)) {
      return res.status(400).json({ success: false, message: 'Store location must be within Palestine' });
    }

    const invalidField = findInvalidNumericField(req.body);
    if (invalidField) {
      return res.status(400).json({ success: false, message: `${invalidField} must be a non-negative number` });
    }

    // ✅ delivery_fee (الرسم الفعلي المستخدم وقت إنشاء الطلب - checkout) دايمًا
    // نسخة عن رسم "داخل المدينة" - نفس منطق التزامن بـ updateMyStore تحت
    const deliveryFeeInside = delivery_fee_inside_city !== undefined ? delivery_fee_inside_city : 10.0;

    const store = await Restaurant.create({
      user_id: req.user.user_id,
      name, description, cuisine_type, category_id, image_url,
      address, location_lat, location_lng, city, region, phone, email,
      opening_time: opening_time || null,
      closing_time: closing_time || null,
      minimum_order: minimum_order !== undefined ? minimum_order : 0,
      delivery_fee: deliveryFeeInside,
      delivery_fee_inside_city: deliveryFeeInside,
      delivery_fee_outside_city: delivery_fee_outside_city !== undefined ? delivery_fee_outside_city : 20.0,
      delivery_fee_occupied_areas: delivery_fee_occupied_areas !== undefined ? delivery_fee_occupied_areas : 70.0,
      prep_time_minutes: prep_time_minutes !== undefined ? prep_time_minutes : 10,
      supports_delivery: supports_delivery !== undefined ? !!supports_delivery : true,
      supports_pickup: supports_pickup !== undefined ? !!supports_pickup : false
    });

    // ✅ Phase 4 - إشعار كل الأدمنز بمتجر جديد بانتظار الموافقة (كل متجر جديد
    // يبلّش Pending بشكل افتراضي - راجع Restaurant.js)
    notifyRole('Admin', {
      title: 'متجر جديد بانتظار الموافقة',
      body: `متجر "${store.name}" قدّم طلب انضمام وينتظر مراجعتك`,
      type: 'AdminApproval',
      relatedType: 'Store',
      relatedId: store.restaurant_id,
      io: getIo()
    }).catch((err) => console.error('❌ notifyRole (AdminApproval) error:', err));

    res.status(201).json({ success: true, message: 'Store created, pending approval', store: formatStore(store) });
  } catch (error) {
    console.error('❌ Create store error:', error);
    res.status(500).json({ success: false, message: 'Server error while creating store' });
  }
};

// ===========================
// 📌 GET /api/stores/my-store  (متجر صاحب الحساب الحالي - بغض النظر عن حالة الموافقة)
// ===========================
const getMyStore = async (req, res) => {
  try {
    const store = await Restaurant.findOne({ where: { user_id: req.user.user_id } });

    // ما في متجر لسا -> نرجع success مع store: null (مش 404) عشان الفرونت يميز
    // بين "لسا ما عمل متجر" و "صار خطأ فعلي"
    if (!store) {
      return res.status(200).json({ success: true, store: null });
    }

    res.status(200).json({ success: true, store: formatStore(store) });
  } catch (error) {
    console.error('❌ Get my store error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching your store' });
  }
};

// ===========================
// 📌 PUT /api/stores/my-store  (تعديل بيانات المتجر - يستخدمها صاحب المحل لإعادة التقديم بعد الرفض)
// ===========================
const updateMyStore = async (req, res) => {
  try {
    const store = await Restaurant.findOne({ where: { user_id: req.user.user_id } });
    if (!store) {
      return res.status(404).json({ success: false, message: 'You do not have a store yet' });
    }

    const {
      name, description, cuisine_type, category_id, image_url,
      address, location_lat, location_lng, city, region, phone, email,
      opening_time, closing_time, preferred_company_id, required_vehicle_type,
      minimum_order, delivery_fee_inside_city, delivery_fee_outside_city,
      delivery_fee_occupied_areas, prep_time_minutes, supports_delivery, supports_pickup
    } = req.body;

    if (
      location_lat !== undefined && location_lng !== undefined &&
      !validatePalestineBounds(location_lat, location_lng)
    ) {
      return res.status(400).json({ success: false, message: 'Store location must be within Palestine' });
    }

    const invalidField = findInvalidNumericField(req.body);
    if (invalidField) {
      return res.status(400).json({ success: false, message: `${invalidField} must be a non-negative number` });
    }

    // ✅ Phase 3 - Smart Assignment: شركة توصيل مفضّلة اختيارية - لازم تكون
    // فعلًا حساب شركة توصيل (business_type='Fleet / Company') وإلا العامل
    // بمحرك التسجيل ما إله معنى
    if (preferred_company_id !== undefined && preferred_company_id !== null) {
      const company = await User.findOne({
        where: { user_id: preferred_company_id, role: 'Driver', business_type: 'Fleet / Company' }
      });
      if (!company) {
        return res.status(400).json({ success: false, message: 'preferred_company_id must be a valid delivery company account' });
      }
    }

    // ✅ delivery_fee (المستخدم الفعلي وقت الطلب - checkout) بيبقى متزامن مع
    // رسم "داخل المدينة" - نفس منطق createStore. لو ما انبعت تعديل عليه هون،
    // بيضل متل ما هو.
    const deliveryFeeInside = delivery_fee_inside_city !== undefined ? delivery_fee_inside_city : store.delivery_fee_inside_city;

    await store.update({
      name: name ?? store.name,
      description: description ?? store.description,
      cuisine_type: cuisine_type ?? store.cuisine_type,
      category_id: category_id ?? store.category_id,
      image_url: image_url ?? store.image_url,
      address: address ?? store.address,
      location_lat: location_lat ?? store.location_lat,
      location_lng: location_lng ?? store.location_lng,
      city: city ?? store.city,
      region: region ?? store.region,
      phone: phone ?? store.phone,
      email: email ?? store.email,
      opening_time: opening_time ?? store.opening_time,
      closing_time: closing_time ?? store.closing_time,
      preferred_company_id: preferred_company_id !== undefined ? preferred_company_id : store.preferred_company_id,
      required_vehicle_type: required_vehicle_type !== undefined ? required_vehicle_type : store.required_vehicle_type,
      minimum_order: minimum_order !== undefined ? minimum_order : store.minimum_order,
      delivery_fee: deliveryFeeInside,
      delivery_fee_inside_city: deliveryFeeInside,
      delivery_fee_outside_city: delivery_fee_outside_city !== undefined ? delivery_fee_outside_city : store.delivery_fee_outside_city,
      delivery_fee_occupied_areas: delivery_fee_occupied_areas !== undefined ? delivery_fee_occupied_areas : store.delivery_fee_occupied_areas,
      prep_time_minutes: prep_time_minutes !== undefined ? prep_time_minutes : store.prep_time_minutes,
      supports_delivery: supports_delivery !== undefined ? !!supports_delivery : store.supports_delivery,
      supports_pickup: supports_pickup !== undefined ? !!supports_pickup : store.supports_pickup,
      // ✅ أي تعديل بعد الرفض بيرجع الطلب لـ Pending تلقائيًا عشان يتراجع من الأدمن
      approval_status: store.approval_status === 'Rejected' ? 'Pending' : store.approval_status,
      rejection_reason: store.approval_status === 'Rejected' ? null : store.rejection_reason
    });

    res.status(200).json({ success: true, message: 'Store updated', store: formatStore(store) });
  } catch (error) {
    console.error('❌ Update my store error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating your store' });
  }
};

// ===========================
// 📌 POST /api/stores/:id/products  (إضافة منتج/عنصر قائمة)
// ===========================
const createProduct = async (req, res) => {
  try {
    const store = await Restaurant.findByPk(req.params.id);
    if (!store) return res.status(404).json({ success: false, message: 'Store not found' });

    if (store.user_id !== req.user.user_id) {
      return res.status(403).json({ success: false, message: 'You do not own this store' });
    }

    const { name, description, image_url, images, price, variants, addons, exclusions, option_groups, is_featured } = req.body;
    if (!name || price === undefined) {
      return res.status(400).json({ success: false, message: 'name and price are required' });
    }

    const product = await Product.create({
      restaurant_id: store.restaurant_id,
      name, description, image_url, images: images || null, price,
      is_featured: !!is_featured
    });

    if (Array.isArray(variants) && variants.length) {
      await ProductVariant.bulkCreate(
        variants.map((v, i) => ({
          product_id: product.product_id,
          label: v.label,
          price: v.price,
          sort_order: i
        }))
      );
    }

    if (Array.isArray(addons) && addons.length) {
      await ProductAddon.bulkCreate(
        addons.map((a, i) => ({
          product_id: product.product_id,
          name: a.name,
          price: a.price,
          sort_order: i
        }))
      );
    }

    if (Array.isArray(exclusions) && exclusions.length) {
      await ProductExclusion.bulkCreate(
        exclusions.map((label, i) => ({
          product_id: product.product_id,
          label,
          sort_order: i
        }))
      );
    }

    if (Array.isArray(option_groups) && option_groups.length) {
      await createOptionGroups(product.product_id, option_groups);
    }

    const created = await Product.findByPk(product.product_id, {
      include: [
        { model: ProductVariant, as: 'variants' },
        { model: ProductAddon, as: 'addons' },
        { model: ProductExclusion, as: 'exclusions' },
        { model: ProductOptionGroup, as: 'optionGroups', include: [{ model: ProductOptionValue, as: 'values' }] }
      ]
    });

    res.status(201).json({ success: true, product: formatProduct(created) });
  } catch (error) {
    console.error('❌ Create product error:', error);
    res.status(500).json({ success: false, message: 'Server error while creating product' });
  }
};

// ===========================
// 📌 PUT /api/stores/:id/products/:productId  (تعديل منتج/عنصر قائمة)
// ===========================
const updateProduct = async (req, res) => {
  try {
    const store = await Restaurant.findByPk(req.params.id);
    if (!store) return res.status(404).json({ success: false, message: 'Store not found' });
    if (store.user_id !== req.user.user_id) {
      return res.status(403).json({ success: false, message: 'You do not own this store' });
    }

    const product = await Product.findOne({
      where: { product_id: req.params.productId, restaurant_id: store.restaurant_id }
    });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found' });
    }

    const { name, description, image_url, images, price, in_stock, variants, addons, exclusions, option_groups, is_featured } = req.body;

    await product.update({
      name: name ?? product.name,
      description: description ?? product.description,
      image_url: image_url ?? product.image_url,
      images: images ?? product.images,
      price: price ?? product.price,
      in_stock: in_stock ?? product.in_stock,
      is_featured: is_featured ?? product.is_featured
    });

    // ✅ لو انبعت variants/addons/exclusions، منستبدل القائمة كاملة (أبسط وأصح
    // من "diff" لكل عنصر) - نفس منطق تعديل المنتج الأصلي
    if (Array.isArray(variants)) {
      await ProductVariant.destroy({ where: { product_id: product.product_id } });
      if (variants.length) {
        await ProductVariant.bulkCreate(
          variants.map((v, i) => ({
            product_id: product.product_id,
            label: v.label,
            price: v.price,
            sort_order: i
          }))
        );
      }
    }

    if (Array.isArray(addons)) {
      await ProductAddon.destroy({ where: { product_id: product.product_id } });
      if (addons.length) {
        await ProductAddon.bulkCreate(
          addons.map((a, i) => ({
            product_id: product.product_id,
            name: a.name,
            price: a.price,
            sort_order: i
          }))
        );
      }
    }

    if (Array.isArray(exclusions)) {
      await ProductExclusion.destroy({ where: { product_id: product.product_id } });
      if (exclusions.length) {
        await ProductExclusion.bulkCreate(
          exclusions.map((label, i) => ({
            product_id: product.product_id,
            label,
            sort_order: i
          }))
        );
      }
    }

    if (Array.isArray(option_groups)) {
      // ✅ حذف المجموعات القديمة (بيكاسكيد على قيمها تلقائيًا عبر الـ DB constraint)
      await ProductOptionGroup.destroy({ where: { product_id: product.product_id } });
      if (option_groups.length) {
        await createOptionGroups(product.product_id, option_groups);
      }
    }

    const updated = await Product.findByPk(product.product_id, {
      include: [
        { model: ProductVariant, as: 'variants' },
        { model: ProductAddon, as: 'addons' },
        { model: ProductExclusion, as: 'exclusions' },
        { model: ProductOptionGroup, as: 'optionGroups', include: [{ model: ProductOptionValue, as: 'values' }] }
      ]
    });

    res.status(200).json({ success: true, message: 'Product updated', product: formatProduct(updated) });
  } catch (error) {
    console.error('❌ Update product error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating product' });
  }
};

// ===========================
// 📌 DELETE /api/stores/:id/products/:productId
// ===========================
const deleteProduct = async (req, res) => {
  try {
    const store = await Restaurant.findByPk(req.params.id);
    if (!store) return res.status(404).json({ success: false, message: 'Store not found' });
    if (store.user_id !== req.user.user_id) {
      return res.status(403).json({ success: false, message: 'You do not own this store' });
    }

    const product = await Product.findOne({
      where: { product_id: req.params.productId, restaurant_id: store.restaurant_id }
    });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found' });
    }

    await product.destroy();
    res.status(200).json({ success: true, message: 'Product deleted' });
  } catch (error) {
    console.error('❌ Delete product error:', error);
    res.status(500).json({ success: false, message: 'Server error while deleting product' });
  }
};

// ===========================
// 📌 Helper: أفضل كوبون فعّال حاليًا لكل متجر (لشارة الخصم على بطاقة المتجر)
// ===========================
async function getDiscountLabels(restaurantIds) {
  if (!restaurantIds.length) return new Map();
  const now = new Date();
  const coupons = await Coupon.findAll({
    where: {
      restaurant_id: { [Op.in]: restaurantIds },
      is_active: true,
      [Op.and]: [
        { [Op.or]: [{ valid_from: null }, { valid_from: { [Op.lte]: now } }] },
        { [Op.or]: [{ valid_until: null }, { valid_until: { [Op.gte]: now } }] }
      ]
    }
  });

  const labels = new Map();
  for (const c of coupons) {
    const label = c.discount_type === 'Percentage'
      ? `-${parseFloat(c.discount_value)}%`
      : `-${parseFloat(c.discount_value)}`;
    const existing = labels.get(c.restaurant_id);
    // نفضّل أعلى نسبة خصم مئوية لو في أكتر من كوبون فعّال على نفس المتجر
    if (!existing || (c.discount_type === 'Percentage' && parseFloat(c.discount_value) > existing.value)) {
      labels.set(c.restaurant_id, { label, value: c.discount_type === 'Percentage' ? parseFloat(c.discount_value) : 0 });
    }
  }
  return new Map([...labels].map(([id, v]) => [id, v.label]));
}

// ===========================
// 📌 Helpers: تحويل شكل الداتا لنفس الأسماء اللي الفرونت متوقعها
// ===========================
function formatStore(store, extra = {}) {
  const { distanceKm = null, isFavorited = false, discountLabel = null } = extra;
  return {
    id: store.restaurant_id.toString(),
    name: store.name,
    category_id: store.category_id ? store.category_id.toString() : '',
    image_url: store.image_url || store.cover_image || store.logo || '',
    average_rating: parseFloat(store.rating || 0),
    total_reviews: store.review_count || 0,
    is_active: store.is_active,
    is_approved: store.approval_status === 'Approved',
    approval_status: store.approval_status,
    rejection_reason: store.rejection_reason || null,
    address: store.address,
    city: store.city || '',
    region: store.region || '',
    phone: store.phone,
    email: store.email || '',
    description: store.description || '',
    cuisine_type: store.cuisine_type || '',
    opening_time: store.opening_time,
    closing_time: store.closing_time,
    delivery_fee: store.delivery_fee ? store.delivery_fee.toString() : '0',
    minimum_order: store.minimum_order ? store.minimum_order.toString() : '0',
    // ✅ الرسوم الثلاثة الحقيقية (داخل/خارج المدينة/مناطق محتلة) - delivery_fee
    // فوق يضل مطابق لـ delivery_fee_inside_city دايمًا (راجع create/updateMyStore)
    delivery_fee_inside_city: store.delivery_fee_inside_city ? store.delivery_fee_inside_city.toString() : '10',
    delivery_fee_outside_city: store.delivery_fee_outside_city ? store.delivery_fee_outside_city.toString() : '20',
    delivery_fee_occupied_areas: store.delivery_fee_occupied_areas ? store.delivery_fee_occupied_areas.toString() : '70',
    prep_time_minutes: store.prep_time_minutes || 10,
    supports_delivery: store.supports_delivery !== false,
    supports_pickup: !!store.supports_pickup,
    preferred_company_id: store.preferred_company_id ? store.preferred_company_id.toString() : null,
    required_vehicle_type: store.required_vehicle_type || null,
    is_featured: !!store.is_featured,
    is_favorited: isFavorited,
    discount_label: discountLabel,
    latitude: store.location_lat !== null && store.location_lat !== undefined ? parseFloat(store.location_lat) : null,
    longitude: store.location_lng !== null && store.location_lng !== undefined ? parseFloat(store.location_lng) : null,
    is_open_now: isOpenNow(store.opening_time, store.closing_time, store.is_open),
    distance_km: distanceKm !== null ? Math.round(distanceKm * 10) / 10 : null,
    delivery_time: estimateDeliveryRange(distanceKm, store.prep_time_minutes || undefined)
  };
}

function formatProduct(product, extra = {}) {
  const { isFavorited = false } = extra;
  return {
    id: product.product_id.toString(),
    name: product.name,
    description: product.description || '',
    store_id: product.restaurant_id.toString(),
    image_url: product.image_url || '',
    images: product.images || [],
    price: parseFloat(product.price),
    average_rating: parseFloat(product.average_rating || 0),
    total_reviews: product.total_reviews || 0,
    in_stock: product.in_stock,
    is_active: product.is_active,
    is_featured: !!product.is_featured,
    is_favorited: isFavorited,
    variants: (product.variants || [])
      .slice()
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((v) => ({
        id: v.variant_id.toString(),
        label: v.label,
        price: parseFloat(v.price)
      })),
    addons: (product.addons || [])
      .slice()
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((a) => ({
        id: a.addon_id.toString(),
        name: a.name,
        price: parseFloat(a.price)
      })),
    exclusions: (product.exclusions || [])
      .slice()
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((e) => ({
        id: e.exclusion_id.toString(),
        label: e.label
      })),
    option_groups: (product.optionGroups || [])
      .slice()
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((g) => ({
        id: g.group_id.toString(),
        name: g.name,
        selection_mode: g.selection_mode,
        is_required: !!g.is_required,
        values: (g.values || [])
          .slice()
          .sort((a, b) => a.sort_order - b.sort_order)
          .map((v) => ({
            id: v.value_id.toString(),
            label: v.label,
            price: parseFloat(v.price)
          }))
      }))
  };
}

// ✅ منشئ مجموعات المواصفات المخصصة + قيمها لمنتج معيّن - يستخدمه
// createProduct وupdateProduct سوا. بننشئ كل مجموعة لحالها (مش bulkCreate)
// عشان نضمن رجوع group_id الحقيقي قبل ما ننشئ قيمها.
async function createOptionGroups(productId, optionGroups) {
  for (let i = 0; i < optionGroups.length; i++) {
    const g = optionGroups[i];
    const values = Array.isArray(g.values) ? g.values : [];
    if (!g.name || !values.length) continue;

    const group = await ProductOptionGroup.create({
      product_id: productId,
      name: g.name,
      selection_mode: g.selection_mode === 'multiple' ? 'multiple' : 'single',
      is_required: !!g.is_required,
      sort_order: i
    });

    await ProductOptionValue.bulkCreate(
      values.map((v, j) => ({
        group_id: group.group_id,
        label: v.label,
        price: v.price || 0,
        sort_order: j
      }))
    );
  }
}

// ===========================
// 📌 GET /api/stores/:id/reviews  (عامة - قائمة تقييمات متجر، الأحدث أولًا)
// ===========================
const getStoreReviews = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    // ✅ ما كان في حد أعلى - عميل يقدر يطلب ?limit=999999 (بدون حماية سيرفر)
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));

    const { rows, count } = await Review.findAndCountAll({
      where: { restaurant_id: req.params.id },
      include: [{ model: User, as: 'customer', attributes: ['full_name'] }],
      order: [['created_at', 'DESC']],
      limit,
      offset: (page - 1) * limit
    });

    res.status(200).json({
      success: true,
      reviews: rows.map(formatReview),
      total: count,
      page,
      limit
    });
  } catch (error) {
    console.error('❌ Get store reviews error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching store reviews' });
  }
};

// ===========================
// 📌 GET /api/stores/my-store/analytics  (تحليلات متجري - أكثر المنتجات
// مبيعًا، ساعات الذروة، متوسط قيمة الطلب، نسبة الإلغاء، العملاء المتكررون)
// ===========================
const getMyStoreAnalytics = async (req, res) => {
  try {
    const store = await Restaurant.findOne({ where: { user_id: req.user.user_id } });
    if (!store) {
      return res.status(404).json({ success: false, message: 'You do not have a store yet' });
    }
    const analytics = await computeStoreAnalytics(store.restaurant_id);
    res.status(200).json({ success: true, analytics });
  } catch (error) {
    console.error('❌ Get store analytics error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching store analytics' });
  }
};

module.exports = {
  getCategories,
  getStores,
  getStoreDetail,
  createStore,
  getMyStore,
  updateMyStore,
  createProduct,
  updateProduct,
  deleteProduct,
  getStoreReviews,
  getPopularProducts,
  getNewArrivals,
  getMyStoreAnalytics,
  formatStore,
  formatProduct
};
