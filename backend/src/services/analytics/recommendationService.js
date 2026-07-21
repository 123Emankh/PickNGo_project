// src/services/analytics/recommendationService.js
//
// محرك توصية بسيط قائم على قواعد/إحصاءات (لا Machine Learning) - يعتمد كليًا
// على بيانات موجودة أصلًا (الطلبات السابقة، المفضلة، الفئات، الموقع). ما في
// أي جدول جديد بقاعدة البيانات - كل شي محسوب لحظة الطلب من الجداول الحالية.
const { Op } = require('sequelize');
const { Order, OrderItem, Restaurant, Product, Favorite } = require('../../models');
const { haversineKm } = require('../../utils/geo');
const { formatStore, formatProduct } = require('../../controllers/storeController');

const NEARBY_RADIUS_KM = 15; // أبعد مسافة لسا "قريبة" - نفس نصف قطر التعيين الذكي بمحرك السائقين
const MAX_CANDIDATE_STORES = 200; // سقف أمان لعدد المتاجر المرشّحة قبل التسجيل (المشروع بحجم صغير/متوسط)

// ✅ عدد التقييمات يلي المتجر/المنتج لازم يوصلها قبل ما نمنح تطابق فئته ثقة
// كاملة بالمعادلة - وإلا متجر تجريبي/جديد بصفر تقييمات بيتصدّر النتائج لمجرد
// إنه بنفس فئة أكتر فئة طلب منها الزبون، حتى لو متجر تاني من فئة تانية
// تقييمه ممتاز (راجع MIN_REVIEWS_FOR_FULL_CONFIDENCE بالتقرير - Bug حقيقي
// لوحظ فعليًا: "Pay Test Store" بصفر تقييم كان يتصدّر فوق متجر 4.6⭐)
const MIN_REVIEWS_FOR_FULL_CONFIDENCE = 3;

// ✅ عدد التقييمات يلي "نثق" فيها بالتقييم الخام نفسه (Bayesian smoothing بسيط)
// - تقييم 5.0 من مراجعة وحدة ما لازم يوازي تقييم 4.8 من 31 مراجعة. كل ما زاد
// عدد التقييمات، كل ما اقترب الرقم المستخدم بالمعادلة من التقييم الخام الحقيقي.
const RATING_CONFIDENCE_REVIEWS = 5;

function round2(n) {
  return Math.round(n * 100) / 100;
}

// ✅ تقييم "بايزي" بسيط: يسحب أي تقييم مبني على عدد قليل من المراجعات نحو
// المتوسط العام (globalAvgRating) بدل ما ياخد بكلمته حرفيًا - كل ما زادت
// المراجعات كل ما اقترب من التقييم الخام الفعلي. priorAvg = متوسط تقييمات كل
// المرشّحين الفعليين (مش رقم ثابت مفبرك) - محسوب مرة وحدة لكل طلب توصية.
function bayesianRating(rawRating, reviewCount, priorAvg) {
  return (RATING_CONFIDENCE_REVIEWS * priorAvg + reviewCount * rawRating) / (RATING_CONFIDENCE_REVIEWS + reviewCount);
}

// ✅ متوسط تقييم المرشّحين يلي عندهم تقييم حقيقي (استبعاد الأصفار الوهمية
// لمتاجر/منتجات بدون أي تقييم بعد - وإلا بتسحب المتوسط لتحت بدون داعٍ)
function computeGlobalAvgRating(items, ratingOf, reviewCountOf) {
  const rated = items.filter((i) => reviewCountOf(i) > 0);
  if (!rated.length) return 4.0; // لا يوجد أي تقييم حقيقي بعد بكل المرشّحين - قيمة محايدة معقولة
  return rated.reduce((sum, i) => sum + ratingOf(i), 0) / rated.length;
}

// ===========================
// 📌 تفضيلات الفئات لمستخدم معيّن - إشارة مشتركة بين توصية المتاجر والمنتجات
// مبنية من مصدرين موجودين أصلًا:
//   - الفئات الأكثر تكرارًا بطلباته السابقة (وزن 1 لكل طلب)
//   - فئات المتاجر/المنتجات يلي فضّلها (وزن 2 - المفضّلة إشارة أقوى من الطلب العابر)
// النتيجة: Map<category_id, weight 0..1> بعد التطبيع على أعلى قيمة، + هل توفرت
// أي إشارة إطلاقًا (لمستخدم جديد بدون طلبات/مفضّلة - cold start)
// ===========================
async function getUserCategoryPreferences(userId) {
  const [pastOrders, favoriteStores, favoriteProducts] = await Promise.all([
    Order.findAll({
      where: { customer_id: userId },
      include: [{ model: Restaurant, as: 'store', attributes: ['category_id'] }],
      attributes: ['order_id', 'restaurant_id']
    }),
    Favorite.findAll({
      where: { user_id: userId, restaurant_id: { [Op.ne]: null } },
      include: [{ model: Restaurant, as: 'store', attributes: ['category_id'] }]
    }),
    Favorite.findAll({
      where: { user_id: userId, product_id: { [Op.ne]: null } },
      include: [{ model: Product, as: 'product', attributes: ['restaurant_id'], include: [{ model: Restaurant, as: 'store', attributes: ['category_id'] }] }]
    })
  ]);

  const rawWeight = new Map();
  const bump = (categoryId, amount) => {
    if (!categoryId) return;
    rawWeight.set(categoryId, (rawWeight.get(categoryId) || 0) + amount);
  };

  const orderedRestaurantIds = new Set();
  for (const order of pastOrders) {
    if (order.store) bump(order.store.category_id, 1);
    if (order.restaurant_id) orderedRestaurantIds.add(order.restaurant_id);
  }
  for (const fav of favoriteStores) {
    if (fav.store) bump(fav.store.category_id, 2);
  }
  for (const fav of favoriteProducts) {
    if (fav.product && fav.product.store) bump(fav.product.store.category_id, 2);
  }

  const hasSignals = rawWeight.size > 0;
  const maxWeight = hasSignals ? Math.max(...rawWeight.values()) : 1;
  const normalized = new Map([...rawWeight.entries()].map(([id, w]) => [id, w / maxWeight]));

  // ✅ الفئة الأعلى وزنًا - تُستخدم بجملة "التوصية" المعروضة للمستخدم ("لأنك تطلب كثيرًا من فئة كذا")
  let topCategoryId = null;
  let topWeight = -1;
  for (const [id, w] of normalized.entries()) {
    if (w > topWeight) { topWeight = w; topCategoryId = id; }
  }

  return { weights: normalized, hasSignals, topCategoryId, orderedRestaurantIds };
}

// ===========================
// 📌 GET /api/recommendations/stores  (Recommended Stores)
// ===========================
async function getRecommendedStores(userId, { lat, lng } = {}, limit = 10) {
  const [preferences, favoriteStoreRows] = await Promise.all([
    getUserCategoryPreferences(userId),
    Favorite.findAll({ where: { user_id: userId, restaurant_id: { [Op.ne]: null } }, attributes: ['restaurant_id'] })
  ]);

  // ✅ المتاجر يلي أصلًا بالمفضّلة أو طلب منها قبل ما منرجّحها هون - المستخدم
  // يعرفها أصلًا (وعند المفضّلة شاشتها الخاصة)؛ التوصية هون لاكتشاف شي جديد
  // يشبه ذوقه. باج كان موجود: بس المفضّلة كانت مستثناة - متجر يطلب منه الزبون
  // يوميًا كان يقدر يتصدّر "موصى لك" بالضبط لأنه الطلب المتكرر هو اللي بيرفع
  // categoryScore أصلًا - عكس قصد "اكتشف شي جديد" تمامًا.
  const excludeIds = new Set([
    ...favoriteStoreRows.map((f) => f.restaurant_id),
    ...preferences.orderedRestaurantIds
  ]);

  const stores = await Restaurant.findAll({
    where: { is_active: true, approval_status: 'Approved' },
    limit: MAX_CANDIDATE_STORES,
    order: [['review_count', 'DESC']]
  });

  const hasLocation = typeof lat === 'number' && typeof lng === 'number';
  const maxReviewCount = Math.max(1, ...stores.map((s) => s.review_count || 0));
  const globalAvgRating = computeGlobalAvgRating(stores, (s) => parseFloat(s.rating) || 0, (s) => s.review_count || 0);

  const scored = stores
    .filter((s) => !excludeIds.has(s.restaurant_id))
    .map((store) => {
      const rawCategoryScore = preferences.weights.get(store.category_id) || 0;
      // ✅ ثقة تطابق الفئة تتناسب مع عدد تقييمات المتجر - متجر بدون أي تقييم
      // ما ياخد تطابق الفئة كاملًا (راجع MIN_REVIEWS_FOR_FULL_CONFIDENCE فوق)
      const reviewConfidence = Math.min(1, (store.review_count || 0) / MIN_REVIEWS_FOR_FULL_CONFIDENCE);
      const categoryScore = rawCategoryScore * reviewConfidence;
      const ratingScore = bayesianRating(parseFloat(store.rating) || 0, store.review_count || 0, globalAvgRating) / 5;
      const popularityScore = Math.log10((store.review_count || 0) + 1) / Math.log10(maxReviewCount + 1);
      const distanceKm = hasLocation
        ? haversineKm(lat, lng, parseFloat(store.location_lat), parseFloat(store.location_lng))
        : null;
      const proximityScore = distanceKm !== null ? Math.max(0, 1 - distanceKm / NEARBY_RADIUS_KM) : null;

      // ✅ لو ما في موقع مبعوت، منعيد توزيع وزن القرب على الفئة/التقييم بدل ما نهمله بصفر
      const weights = proximityScore !== null
        ? { category: 0.35, rating: 0.2, popularity: 0.15, proximity: 0.3 }
        : { category: 0.5, rating: 0.3, popularity: 0.2, proximity: 0 };

      const score =
        weights.category * categoryScore +
        weights.rating * ratingScore +
        weights.popularity * popularityScore +
        weights.proximity * (proximityScore || 0);

      // ✅ باج كان موجود: السبب المعروض كان بيوقف عند أول شرط ينطبق (ترتيب
      // ثابت بالكود)، مش بالضرورة العامل يلي فعليًا رجّح النتيجة أكتر من غيره
      // - متجر ممكن يكون قريب جدًا وتقييمه عالي بس categoryScore بالكاد فوق
      // 0.5 فيوصلها سبب "فئة تفضّلها" وهو مش السبب الحقيقي وراء ترتيبه العالي.
      // هلق منقارن المساهمة الموزونة الفعلية لكل عامل ومنختار الأكبر.
      const contributions = {
        category: weights.category * categoryScore,
        rating: weights.rating * ratingScore,
        popularity: weights.popularity * popularityScore,
        proximity: weights.proximity * (proximityScore || 0)
      };
      const dominant = Object.keys(contributions).reduce((best, key) =>
        contributions[key] > contributions[best] ? key : best, 'rating');

      let reason = 'مختارة لك بناءً على تقييمها وشعبيتها';
      // ✅ مستخدم جديد بدون أي إشارة تفضيل (hasSignals) - كان محسوب وما
      // بيتستخدم إطلاقًا (dead code)؛ هلق أول أولوية له سبب صريح وصادق بدل
      // ما يقع بالصدفة بأحد الأسباب العامة تحت
      if (!preferences.hasSignals && popularityScore > 0.6) reason = 'من الأكثر طلبًا حاليًا';
      else if (dominant === 'category' && categoryScore > 0.3) reason = 'من فئة تطلب/تفضّل منها كثيرًا';
      else if (dominant === 'proximity' && proximityScore !== null && proximityScore > 0.3) reason = 'قريبة جدًا من موقعك الحالي';
      else if (dominant === 'rating' && ratingScore >= 0.7) reason = 'من أعلى المتاجر تقييمًا';

      return { store, distanceKm, score: round2(score), reason };
    })
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);

  return scored.map(({ store, distanceKm, score, reason }) => ({
    ...formatStore(store, { distanceKm, isFavorited: false }),
    recommendation_score: score,
    recommendation_reason: reason
  }));
}

// ===========================
// 📌 GET /api/recommendations/products  (Recommended Products)
// ===========================
async function getRecommendedProducts(userId, limit = 10) {
  const [preferences, orderedProductRows, favoriteProductRows] = await Promise.all([
    getUserCategoryPreferences(userId),
    OrderItem.findAll({
      include: [{ model: Order, attributes: [], where: { customer_id: userId } }],
      attributes: ['product_id']
    }),
    Favorite.findAll({ where: { user_id: userId, product_id: { [Op.ne]: null } }, attributes: ['product_id'] })
  ]);

  const orderedProductIds = new Set(orderedProductRows.map((r) => r.product_id));
  const favoriteProductIds = new Set(favoriteProductRows.map((r) => r.product_id));

  const products = await Product.findAll({
    where: { is_active: true, in_stock: true },
    include: [{
      model: Restaurant,
      as: 'store',
      where: { is_active: true, approval_status: 'Approved' },
      attributes: ['restaurant_id', 'name', 'category_id']
    }],
    order: [['total_reviews', 'DESC']],
    limit: MAX_CANDIDATE_STORES
  });

  const maxReviews = Math.max(1, ...products.map((p) => p.total_reviews || 0));
  const globalAvgRating = computeGlobalAvgRating(products, (p) => parseFloat(p.average_rating) || 0, (p) => p.total_reviews || 0);

  const scored = products.map((product) => {
    const rawCategoryScore = preferences.weights.get(product.store.category_id) || 0;
    // ✅ نفس منطق ثقة تطابق الفئة المطبّق على المتاجر - منتج بدون أي تقييم
    // ما ياخد تطابق الفئة كاملًا (حاليًا لا يوجد نظام تقييم منتجات فعليًا
    // بالتطبيق - كل المنتجات total_reviews=0 - فهاد الحارس جاهز لليوم يلي يُبنى)
    const reviewConfidence = Math.min(1, (product.total_reviews || 0) / MIN_REVIEWS_FOR_FULL_CONFIDENCE);
    const categoryScore = rawCategoryScore * reviewConfidence;
    const ratingScore = bayesianRating(parseFloat(product.average_rating) || 0, product.total_reviews || 0, globalAvgRating) / 5;
    const popularityScore = Math.log10((product.total_reviews || 0) + 1) / Math.log10(maxReviews + 1);
    const alreadyFavorited = favoriteProductIds.has(product.product_id);
    const orderedBefore = orderedProductIds.has(product.product_id);

    // ✅ طلبه قبل = إشارة "بيحب يعيد طلبه" (بوست خفيف)، مفضّل = بوست أقوى شوي
    const affinityBoost = (orderedBefore ? 0.1 : 0) + (alreadyFavorited ? 0.15 : 0);

    const score =
      0.4 * categoryScore +
      0.25 * ratingScore +
      0.2 * popularityScore +
      affinityBoost;

    let reason = 'من المنتجات الأعلى تقييمًا';
    if (orderedBefore) reason = 'طلبته من قبل - جرّبه مرة تانية';
    else if (categoryScore > 0.5) reason = 'من فئة تفضّلها';
    else if (alreadyFavorited) reason = 'من مفضّلتك';

    return { product, score: round2(Math.min(1, score)), reason };
  })
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);

  return scored.map(({ product, score, reason }) => ({
    ...formatProduct(product, { isFavorited: favoriteProductIds.has(product.product_id) }),
    store_name: product.store.name,
    recommendation_score: score,
    recommendation_reason: reason
  }));
}

module.exports = { getUserCategoryPreferences, getRecommendedStores, getRecommendedProducts };
