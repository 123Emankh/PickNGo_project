// src/controllers/reviewController.js
const { Op } = require('sequelize');
const { Order, OrderItem, Product, Review, ProductReview, Restaurant, User, sequelize } = require('../models');
const { createNotification } = require('../services/notificationService');
const { getIo } = require('../sockets');

// ✅ باج كان موجود: `rating < 1 || rating > 5` بيفوّت NaN (كل مقارنة عدد
// بـ NaN بترجّع false)، فقيمة زي "abc" كانت توصل حتى الـ Sequelize model
// validator وتطلع كخطأ 500 عام بدل رسالة 400 واضحة. هلق فحص صريح لعدد صحيح
// حقيقي بين 1 و5 قبل أي إشي.
function isValidRating(rating) {
  return Number.isInteger(rating) && rating >= 1 && rating <= 5;
}

function formatReview(review) {
  return {
    id: review.review_id.toString(),
    order_id: review.order_id.toString(),
    rating: review.rating,
    comment: review.comment,
    customer_name: review.customer ? review.customer.full_name : null,
    created_at: review.created_at
  };
}

function formatProductReview(review) {
  return {
    id: review.product_review_id.toString(),
    order_id: review.order_id.toString(),
    product_id: review.product_id.toString(),
    rating: review.rating,
    comment: review.comment,
    customer_name: review.customer ? review.customer.full_name : null,
    created_at: review.created_at
  };
}

/**
 * يعيد حساب متوسط تقييم المتجر وعدد التقييمات من الصفر (بدل حساب تراكمي)
 * حتى ما يصير انحراف (drift) بين رقم rating المخزّن وواقع جدول reviews.
 */
async function recalculateStoreRating(restaurantId, transaction) {
  const result = await Review.findOne({
    where: { restaurant_id: restaurantId },
    attributes: [
      [sequelize.fn('AVG', sequelize.col('rating')), 'avg'],
      [sequelize.fn('COUNT', sequelize.col('review_id')), 'count']
    ],
    raw: true,
    transaction
  });

  await Restaurant.update(
    { rating: result.avg || 0, review_count: result.count || 0 },
    { where: { restaurant_id: restaurantId }, transaction }
  );
}

/**
 * نفس منطق recalculateStoreRating، بس على مستوى منتج واحد بدل المتجر كامل -
 * يحسب AVG/COUNT من product_reviews من الصفر ويكتبهم بـ Product.average_rating/total_reviews.
 */
async function recalculateProductRating(productId, transaction) {
  const result = await ProductReview.findOne({
    where: { product_id: productId },
    attributes: [
      [sequelize.fn('AVG', sequelize.col('rating')), 'avg'],
      [sequelize.fn('COUNT', sequelize.col('product_review_id')), 'count']
    ],
    raw: true,
    transaction
  });

  await Product.update(
    { average_rating: result.avg || 0, total_reviews: result.count || 0 },
    { where: { product_id: productId }, transaction }
  );
}

/**
 * تقييم الطلب (نجوم + تعليق واحد) بينطبق على كل منتج مختلف اشتراه الزبون
 * بهاد الطلب - مش على المتجر بس. بيعمل upsert بمفتاح (order_id, product_id)
 * حتى تعديل تقييم موجود يحدّث نفس الصفوف بدل ما يكرّرها، وبعدين يعيد حساب
 * متوسط كل منتج اتلمس. تقييم المتجر (recalculateStoreRating) يضل مستقل تمامًا.
 */
async function syncProductReviews(order, { rating, comment, customerId }, transaction) {
  const items = await OrderItem.findAll({
    where: { order_id: order.order_id },
    attributes: ['product_id'],
    transaction
  });

  const productIds = [...new Set(items.map((i) => i.product_id))];

  for (const productId of productIds) {
    const [productReview] = await ProductReview.findOrCreate({
      where: { order_id: order.order_id, product_id: productId },
      defaults: { customer_id: customerId, rating, comment: comment || null },
      transaction
    });
    await productReview.update({ rating, comment: comment || null }, { transaction });
    await recalculateProductRating(productId, transaction);
  }

  return productIds;
}

// ===========================
// 📌 POST /api/reviews  (تقييم طلب تم توصيله)
// ===========================
const createReview = async (req, res) => {
  try {
    const { order_id, rating, comment } = req.body;

    if (!order_id || !rating) {
      return res.status(400).json({ success: false, message: 'order_id and rating are required' });
    }
    if (!isValidRating(rating)) {
      return res.status(400).json({ success: false, message: 'Rating must be a whole number between 1 and 5' });
    }

    const order = await Order.findByPk(order_id);
    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }
    if (order.customer_id !== req.user.user_id) {
      return res.status(403).json({ success: false, message: 'This order does not belong to you' });
    }
    if (order.status !== 'Delivered') {
      return res.status(400).json({ success: false, message: 'You can only review a delivered order' });
    }

    // ✅ إنشاء التقييم + إعادة حساب متوسط المتجر جوا معاملة ذرّية وحدة - يسكّر
    // نافذة سباق كان موجود (قراءة AVG/COUNT ممكن تصير بين إنشاء تقييمين
    // متزامنين لنفس المتجر وتفوّت أحدهما من المتوسط اللحظي). الفحص المزدوج
    // لمنع تقييم مكرر (قبل + unique constraint بالجدول) يضل زي ما هو.
    const review = await sequelize.transaction(async (t) => {
      const existing = await Review.findOne({ where: { order_id }, transaction: t });
      if (existing) {
        const err = new Error('This order already has a review. Use update instead.');
        err.status = 409;
        throw err;
      }

      const created = await Review.create({
        order_id,
        customer_id: req.user.user_id,
        restaurant_id: order.restaurant_id,
        rating,
        comment: comment || null
      }, { transaction: t });

      await recalculateStoreRating(order.restaurant_id, t);
      // ✅ التقييم الحقيقي بينطبق على كل منتج اشتراه الزبون بهاد الطلب -
      // راجع syncProductReviews فوق
      await syncProductReviews(order, { rating, comment, customerId: req.user.user_id }, t);
      return created;
    });

    // ✅ باج كان موجود: تقييم جديد ما كان يبلّغ صاحب المتجر بأي إشعار -
    // بيعرف بس لو فتح شاشة تقييماته بنفسه بالصدفة. بعد الـ commit عن قصد
    // (فشل الإشعار ما لازم يرجّع التقييم نفسه - نفس فلسفة إشعار طلب جديد
    // بـ orderController.createOrder)
    Restaurant.findByPk(order.restaurant_id, { attributes: ['user_id'] })
      .then((store) => {
        if (!store) return;
        return createNotification({
          userId: store.user_id,
          title: 'تقييم جديد',
          body: `حصل متجرك على تقييم جديد (${rating} نجوم)`,
          type: 'NewReview',
          relatedType: 'Restaurant',
          relatedId: order.restaurant_id,
          io: getIo()
        });
      })
      .catch((err) => console.error('❌ createNotification (NewReview) error:', err));

    res.status(201).json({ success: true, message: 'Review created', review: formatReview(review) });
  } catch (error) {
    if (error.status === 409 || error.name === 'SequelizeUniqueConstraintError') {
      // ✅ الفحص المسبق فوق بيمسك أغلب الحالات، بس الضغط المزدوج على "إرسال"
      // (double-tap) ممكن يوصل هون بالضبط بنفس اللحظة - قيد unique بالجدول
      // هو خط الدفاع الأخير، ومنحوّل خطأه لرسالة 409 واضحة بدل 500 عام
      return res.status(409).json({ success: false, message: 'This order already has a review. Use update instead.' });
    }
    console.error('❌ Create review error:', error);
    res.status(500).json({ success: false, message: 'Server error while creating review' });
  }
};

// ===========================
// 📌 PUT /api/reviews/:id  (تعديل تقييمي أنا فقط)
// ===========================
const updateReview = async (req, res) => {
  try {
    const review = await Review.findByPk(req.params.id);
    if (!review) {
      return res.status(404).json({ success: false, message: 'Review not found' });
    }
    if (review.customer_id !== req.user.user_id) {
      return res.status(403).json({ success: false, message: 'This review does not belong to you' });
    }

    const { rating, comment } = req.body;
    if (rating !== undefined && !isValidRating(rating)) {
      return res.status(400).json({ success: false, message: 'Rating must be a whole number between 1 and 5' });
    }

    await sequelize.transaction(async (t) => {
      await review.update({
        rating: rating !== undefined ? rating : review.rating,
        comment: comment !== undefined ? comment : review.comment
      }, { transaction: t });

      await recalculateStoreRating(review.restaurant_id, t);

      const order = await Order.findByPk(review.order_id, { transaction: t });
      await syncProductReviews(
        order,
        { rating: review.rating, comment: review.comment, customerId: review.customer_id },
        t
      );
    });

    res.status(200).json({ success: true, message: 'Review updated', review: formatReview(review) });
  } catch (error) {
    console.error('❌ Update review error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating review' });
  }
};

// ===========================
// 📌 DELETE /api/reviews/:id  (صاحب التقييم أو الأدمن)
// ===========================
const deleteReview = async (req, res) => {
  try {
    const review = await Review.findByPk(req.params.id);
    if (!review) {
      return res.status(404).json({ success: false, message: 'Review not found' });
    }
    if (review.customer_id !== req.user.user_id && req.user.role !== 'Admin') {
      return res.status(403).json({ success: false, message: 'Not authorized to delete this review' });
    }

    const restaurantId = review.restaurant_id;
    const orderId = review.order_id;
    await sequelize.transaction(async (t) => {
      const productReviews = await ProductReview.findAll({
        where: { order_id: orderId },
        attributes: ['product_id'],
        transaction: t
      });
      const productIds = [...new Set(productReviews.map((r) => r.product_id))];

      await review.destroy({ transaction: t });
      await recalculateStoreRating(restaurantId, t);

      await ProductReview.destroy({ where: { order_id: orderId }, transaction: t });
      for (const productId of productIds) {
        await recalculateProductRating(productId, t);
      }
    });

    res.status(200).json({ success: true, message: 'Review deleted' });
  } catch (error) {
    console.error('❌ Delete review error:', error);
    res.status(500).json({ success: false, message: 'Server error while deleting review' });
  }
};

// ===========================
// 📌 GET /api/reviews/order/:orderId  (تقييم طلب معيّن إن وجد - لصاحب الطلب فقط)
// ===========================
const getReviewForOrder = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.orderId);
    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }
    if (order.customer_id !== req.user.user_id) {
      return res.status(403).json({ success: false, message: 'This order does not belong to you' });
    }

    const review = await Review.findOne({ where: { order_id: order.order_id } });
    res.status(200).json({ success: true, review: review ? formatReview(review) : null });
  } catch (error) {
    console.error('❌ Get review for order error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching review' });
  }
};

// ===========================
// 📌 GET /api/reviews/mine?order_ids=1,2,3  (تقييماتي لعدة طلبات دفعة وحدة)
// ===========================
// ✅ كانت شاشة "طلباتي" بتنادي /reviews/order/:orderId لكل طلب Delivered
// لحاله بحلقة for متسلسلة (N نداء شبكة لعميل عنده N طلب مسلّم) - هلق نداء
// واحد بس. الأمان بسيط وكافٍ: منرجّع بس تقييمات المستخدم الحالي (customer_id
// من التوكن)، فحتى لو order_id بالقائمة مش إله أصلاً بيختفي من النتيجة
// بصمت، مش بيكشف تقييم حدا تاني.
const getMyReviewsForOrders = async (req, res) => {
  try {
    const raw = req.query.order_ids;
    if (!raw) {
      return res.status(200).json({ success: true, reviews: {} });
    }

    const orderIds = String(raw)
      .split(',')
      .map((s) => parseInt(s, 10))
      .filter((n) => Number.isInteger(n));

    if (!orderIds.length) {
      return res.status(200).json({ success: true, reviews: {} });
    }

    const reviews = await Review.findAll({
      where: { order_id: { [Op.in]: orderIds }, customer_id: req.user.user_id }
    });

    const byOrderId = {};
    for (const review of reviews) {
      byOrderId[review.order_id] = formatReview(review);
    }

    res.status(200).json({ success: true, reviews: byOrderId });
  } catch (error) {
    console.error('❌ Get my reviews for orders error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching reviews' });
  }
};

// ===========================
// 📌 GET /api/reviews/product/:productId  (عامة - قائمة تقييمات منتج، الأحدث أولًا)
// ===========================
const getProductReviews = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));

    const { rows, count } = await ProductReview.findAndCountAll({
      where: { product_id: req.params.productId },
      include: [{ model: User, as: 'customer', attributes: ['full_name'] }],
      order: [['created_at', 'DESC']],
      limit,
      offset: (page - 1) * limit
    });

    res.status(200).json({
      success: true,
      reviews: rows.map(formatProductReview),
      total: count,
      page,
      limit
    });
  } catch (error) {
    console.error('❌ Get product reviews error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching product reviews' });
  }
};

module.exports = {
  createReview,
  updateReview,
  deleteReview,
  getReviewForOrder,
  getMyReviewsForOrders,
  getProductReviews,
  formatReview,
  formatProductReview
};
