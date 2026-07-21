// src/controllers/orderController.js
const { Op } = require('sequelize');
const { Order, OrderItem, Product, ProductVariant, ProductAddon, ProductOptionValue, ProductOptionGroup, Restaurant, User, CouponRedemption, DeliveryGroup, DeliveryGroupItem, sequelize } = require('../models');
const { getIo } = require('../sockets');
const { resolveCoupon } = require('../services/couponService');
const { haversineKm, isOpenNow } = require('../utils/geo');
const { calculateDeliveryFee } = require('../utils/deliveryFee');
const { setDriverStatus } = require('../services/driverStatusService');
const { tryAutoAssign, respondToOffer, clearPendingOffer } = require('../services/assignmentService');
const { maybeGroupOrder, getLiveGroupingSettings } = require('../services/groupingService');
const { tryAutoAssignGroupIfReady, withGroupContext, sortedItems, validSortedItems } = require('../services/groupAssignmentService');
const { buildOfferReasonLabel, MAX_CONCURRENT_ACTIVE_ORDERS } = require('../services/assignment/factors');
const { createNotification } = require('../services/notificationService');
const { predictOrderEta } = require('../services/analytics/etaService');
const {
  resolvePointsRedemption,
  linkRedemptionToOrder,
  handleOrderStatusChange
} = require('../services/loyaltyService');

// ✅ يلاقي آخر محاولة عرض "Offered" لهاد السائق بسجل offer_history (فردي أو
// مجمّع) ويحوّلها لجملة سبب مقروءة + نفس المسافة المحسوبة وقت العرض - تستخدمها
// getMyPendingOffer (fallback السوكيت) بنفس منطق التسمية المستخدم وقت البث الحي.
function extractOfferReasonInfo(offerHistory, driverId) {
  const history = Array.isArray(offerHistory) ? offerHistory : [];
  const lastOffer = [...history].reverse().find((h) => h.driver_id === driverId && h.status === 'Offered');
  if (!lastOffer || !lastOffer.reason) return { label: null, distanceKm: null };
  return {
    label: buildOfferReasonLabel(lastOffer.reason.breakdown, lastOffer.reason.distance_km),
    distanceKm: lastOffer.reason.distance_km ?? null
  };
}

// ✅ حالات نهائية للطلب - يستخدمها كاسكيد "تم التسليم" بالمجموعة المجمّعة
// وحساب حالة DeliveryGroup.status='Completed'
const TERMINAL_ORDER_STATUSES = ['Delivered', 'Cancelled', 'Refunded'];

// طلب لسا "نشط" على سائق (متعيّن إله بس لسا ما سلّمه) - يستخدمها حساب الحمل
// الحالي بعد التسليم (stillBusy) وبمحرك التسجيل الذكي
const ACTIVE_DRIVER_ORDER_STATUSES = ['Delivered', 'Cancelled', 'Refunded'];

// ===========================
// 📌 POST /api/orders  (إنشاء طلب من السلة — Checkout)
// ===========================
const createOrder = async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const {
      restaurant_id,
      items, // [{ product_id, quantity }]
      delivery_address,
      delivery_city,
      delivery_region,
      delivery_lat,
      delivery_lng,
      payment_method,
      special_instructions,
      coupon_code,
      redeem_points
    } = req.body;

    if (!restaurant_id || !items || !items.length || !delivery_address || !payment_method) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Missing required order fields' });
    }

    // ✅ لازمين لحساب رسم التوصيل الصحيح (راجع utils/deliveryFee.js) - بدون
    // تخمين من إحداثيات GPS. delivery_lat/lng تضل اختيارية (خرائط/تتبع بس)
    if (!delivery_city || !delivery_region) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Delivery city and region are required' });
    }

    const store = await Restaurant.findByPk(restaurant_id, { transaction: t });
    if (!store) {
      await t.rollback();
      return res.status(404).json({ success: false, message: 'Store not found' });
    }

    // ✅ نفس فحوصات ظهور المتجر للزبون (getStores/getStoreDetail) لازم تنطبق
    // هون كمان - وإلا زبون يعرف/يخمّن restaurant_id قادر يطلب من متجر معطّل
    // من الأدمن، مش موافق عليه بعد، أو مسكّر حاليًا (يدويًا أو خارج أوقات
    // الدوام) بمجرد ما يبعث الطلب مباشرة بدل ما يمر بشاشة تصفح المتجر
    if (!store.is_active || store.approval_status !== 'Approved') {
      await t.rollback();
      return res.status(403).json({ success: false, message: 'This store is not currently accepting orders' });
    }

    if (!isOpenNow(store.opening_time, store.closing_time, store.is_open)) {
      await t.rollback();
      return res.status(403).json({ success: false, message: 'This store is currently closed' });
    }

    // ✅ نجيب أسعار المنتجات الحقيقية من قاعدة البيانات (منحطش ثقة بأسعار جاية من الفرونت)
    // ملاحظة: بنستخدم Set عشان لو نفس المنتج تكرر بأكتر من عنصر بالسلة (مثلاً
    // بفارينت أو إضافات مختلفة)، الـ IN query بترجع صف واحد له مش صفين
    const productIds = [...new Set(items.map(i => i.product_id))];
    const products = await Product.findAll({ where: { product_id: productIds }, transaction: t });

    if (products.length !== productIds.length) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'One or more products not found' });
    }

    // ✅ لو في عناصر محددة حجم (variant_id)، نجيب أسعار الأحجام الحقيقية كمان
    // (نفس منطق عدم الثقة بأي سعر جاي من الفرونت)
    const variantIds = items.map(i => i.variant_id).filter(Boolean);
    const variants = variantIds.length
      ? await ProductVariant.findAll({ where: { variant_id: variantIds }, transaction: t })
      : [];

    // ✅ نفس المنطق للإضافات (addon_ids) - نجيب أسعارها الحقيقية من الداتابيز
    const addonIds = items.flatMap(i => i.addon_ids || []);
    const addons = addonIds.length
      ? await ProductAddon.findAll({ where: { addon_id: addonIds }, transaction: t })
      : [];

    // ✅ نفس المنطق لمجموعات المواصفات المخصصة (option_value_ids) - نجيب
    // القيم الحقيقية مع مجموعتها (عشان نتحقق من الملكية وقواعد
    // single/required) من قاعدة البيانات
    const optionValueIds = items.flatMap(i => i.option_value_ids || []);
    const optionValues = optionValueIds.length
      ? await ProductOptionValue.findAll({
          where: { value_id: optionValueIds },
          include: [{ model: ProductOptionGroup, as: 'group' }],
          transaction: t
        })
      : [];
    // ✅ كل مجموعات المواصفات (المطلوبة وغيرها) لمنتجات الطلب - لازم نعرفها
    // كلها عشان نتحقق إنه المجموعات is_required=true انختار منها شي
    const optionGroups = await ProductOptionGroup.findAll({
      where: { product_id: productIds },
      transaction: t
    });

    let totalAmount = 0;
    const orderItemsData = [];
    for (const item of items) {
      const product = products.find(p => String(p.product_id) === String(item.product_id));
      let unitPrice = product.price;
      let variantId = null;
      let variantLabel = null;

      if (item.variant_id) {
        const variant = variants.find(v => String(v.variant_id) === String(item.variant_id));
        if (!variant || String(variant.product_id) !== String(product.product_id)) {
          await t.rollback();
          return res.status(400).json({ success: false, message: 'Invalid product variant' });
        }
        unitPrice = variant.price;
        variantId = variant.variant_id;
        variantLabel = variant.label;
      }

      let selectedAddons = [];
      if (Array.isArray(item.addon_ids) && item.addon_ids.length) {
        selectedAddons = item.addon_ids.map((id) => {
          const addon = addons.find(a => String(a.addon_id) === String(id));
          if (!addon || String(addon.product_id) !== String(product.product_id)) {
            return null;
          }
          return { id: addon.addon_id, name: addon.name, price: parseFloat(addon.price) };
        });
        if (selectedAddons.includes(null)) {
          await t.rollback();
          return res.status(400).json({ success: false, message: 'Invalid product addon' });
        }
      }
      const addonsTotal = selectedAddons.reduce((sum, a) => sum + a.price, 0);

      const specialRequests = Array.isArray(item.special_requests)
        ? item.special_requests.filter((r) => typeof r === 'string' && r.trim())
        : [];

      // ✅ مجموعات المواصفات المخصصة (option_value_ids): نتحقق من الملكية
      // (القيمة تابعة لمجموعة تابعة لنفس المنتج)، ومن قواعد كل مجموعة
      // (single = قيمة وحدة كحد أقصى، required = لازم قيمة وحدة ع الأقل)
      let selectedOptions = [];
      if (Array.isArray(item.option_value_ids) && item.option_value_ids.length) {
        selectedOptions = item.option_value_ids.map((id) => {
          const value = optionValues.find(v => String(v.value_id) === String(id));
          if (!value || !value.group || String(value.group.product_id) !== String(product.product_id)) {
            return null;
          }
          return {
            group_id: value.group.group_id,
            group_name: value.group.name,
            value_id: value.value_id,
            label: value.label,
            price: parseFloat(value.price)
          };
        });
        if (selectedOptions.includes(null)) {
          await t.rollback();
          return res.status(400).json({ success: false, message: 'Invalid product option value' });
        }
      }

      const productGroups = optionGroups.filter(g => String(g.product_id) === String(product.product_id));
      for (const group of productGroups) {
        const picked = selectedOptions.filter(o => String(o.group_id) === String(group.group_id));
        if (group.is_required && picked.length < 1) {
          await t.rollback();
          return res.status(400).json({ success: false, message: `"${group.name}" is required` });
        }
        if (group.selection_mode === 'single' && picked.length > 1) {
          await t.rollback();
          return res.status(400).json({ success: false, message: `Only one choice allowed for "${group.name}"` });
        }
      }

      const optionsTotal = selectedOptions.reduce((sum, o) => sum + o.price, 0);

      const subtotal = (parseFloat(unitPrice) + addonsTotal + optionsTotal) * item.quantity;
      totalAmount += subtotal;
      orderItemsData.push({
        product_id: product.product_id,
        quantity: item.quantity,
        unit_price: unitPrice,
        variant_id: variantId,
        variant_label: variantLabel,
        addons: selectedAddons.length ? selectedAddons : null,
        special_requests: specialRequests.length ? specialRequests : null,
        selected_options: selectedOptions.length ? selectedOptions : null,
        subtotal
      });
    }

    // ✅ رسم التوصيل الحقيقي حسب مدينة/منطقة الزبون مقابل مدينة/منطقة
    // المتجر (داخل المدينة/مدينة تانية/مناطق محتلة) - راجع utils/deliveryFee.js
    const deliveryFee = calculateDeliveryFee(store, delivery_city, delivery_region);

    // ✅ كوبون اختياري: لو مش صالح لهاد المتجر بالذات (منتهي، متجر تاني، تجاوز الحد...)
    // منكمل الطلب عادي بدون خصم - مش بنفشل الطلب كامل (خصوصًا مع سلة فيها أكتر من متجر).
    let discount = 0;
    let appliedCoupon = null;
    if (coupon_code) {
      try {
        const result = await resolveCoupon({
          code: coupon_code,
          restaurantId: store.restaurant_id,
          customerId: req.user.user_id,
          cartTotal: totalAmount,
          transaction: t
        });
        discount = result.discountAmount;
        appliedCoupon = result.coupon;
      } catch (couponError) {
        // كوبون مش صالح لهاد الطلب بالذات - نتجاهله ونكمل بدون خصم
        discount = 0;
        appliedCoupon = null;
      }
    }

    // ✅ استبدال نقاط اختياري (Loyalty) - على عكس الكوبون، فشل هون بيفشّل
    // الطلب كامل بدل تجاهله بصمت: هاي عملية حسم فعلي ومقصود من الزبون (مش
    // كود ترويجي "لو انطبق"), فلازم يعرف فورًا لو رصيده تغيّر أو مش كافي
    // (سباق تزامن، أو الشاشة عندها رقم قديم) بدل ما يتفاجأ إنه ما تطبّق بصمت.
    let pointsRedeemed = 0;
    let pointsDiscount = 0;
    if (redeem_points) {
      try {
        const remainingAfterCoupon = totalAmount + deliveryFee - discount;
        const result = await resolvePointsRedemption({
          userId: req.user.user_id,
          requestedPoints: redeem_points,
          cartTotal: remainingAfterCoupon,
          transaction: t
        });
        pointsRedeemed = result.pointsRedeemed;
        pointsDiscount = result.discountAmount;
      } catch (loyaltyError) {
        await t.rollback();
        const status = loyaltyError.status || 500;
        return res.status(status).json({ success: false, message: loyaltyError.message || 'Could not redeem points' });
      }
    }

    const finalAmount = totalAmount + deliveryFee - discount - pointsDiscount;
    const orderNumber = `ORD-${Date.now()}`;

    const order = await Order.create({
      customer_id: req.user.user_id,
      restaurant_id: store.restaurant_id,
      order_number: orderNumber,
      status: 'Pending',
      total_amount: totalAmount,
      delivery_fee: deliveryFee,
      discount,
      final_amount: finalAmount,
      points_redeemed: pointsRedeemed,
      points_redeemed_value: pointsDiscount,
      delivery_address,
      delivery_city,
      delivery_region,
      delivery_lat: delivery_lat || null,
      delivery_lng: delivery_lng || null,
      special_instructions: special_instructions || null,
      payment_method,
      payment_status: 'Pending',
      status_history: [{ status: 'Pending', at: new Date() }],
      // ✅ نسخة عن تفضيلات المتجر وقت الإنشاء - يستخدمها محرك التعيين الذكي
      // (Phase 3) لاحقًا لما الطلب يصير Ready، بنفس منطق نسخ delivery_fee
      preferred_company_id: store.preferred_company_id || null,
      required_vehicle_type: store.required_vehicle_type || null
    }, { transaction: t });

    // ✅ لازم بعد ما order_id يصير معروف - حركة الاستبدال فوق انكتبت بدفتر
    // الأستاذ بـ order_id=null (الطلب لسا ما انخلق وقتها) - هلق منربطها
    if (pointsRedeemed > 0) {
      await linkRedemptionToOrder(req.user.user_id, order.order_id, t);
    }

    await OrderItem.bulkCreate(
      orderItemsData.map(i => ({ ...i, order_id: order.order_id })),
      { transaction: t }
    );

    // ✅ Grouped Delivery (Smart Order Clustering): يفحص لو في طلب سابق لنفس
    // الزبون من متجر قريب (<100م) وبنفس عنوان توصيل قريب وخلال 10 دقايق -
    // لو لقى، يربط الطلبين برحلة توصيل مجمّعة وحدة. فشل هون (أي سبب) ما
    // بيأثر على إنشاء الطلب نفسه - الطلب بيضل فردي عادي (delivery_group_id=null)
    await maybeGroupOrder(order, store, t);

    if (appliedCoupon) {
      await CouponRedemption.create({
        coupon_id: appliedCoupon.coupon_id,
        customer_id: req.user.user_id,
        order_id: order.order_id,
        discount_amount: discount
      }, { transaction: t });
      await appliedCoupon.increment('used_count', { transaction: t });
    }

    await t.commit();

    const fullOrder = await Order.findByPk(order.order_id, {
      include: [{ model: OrderItem, as: 'items', include: [{ model: Product, as: 'product' }] }]
    });

    // ✅ Phase 4 - إشعار صاحب المتجر بطلب جديد. بعد الـ commit عن قصد (ما لازم
    // فشل الإشعار يرجّع الطلب كامل) - fire-and-forget زي أي إشعار تاني
    createNotification({
      userId: store.user_id,
      title: 'طلب جديد',
      body: `وصلك طلب جديد #${order.order_number}`,
      type: 'NewOrder',
      relatedType: 'Order',
      relatedId: order.order_id,
      io: getIo()
    }).catch((err) => console.error('❌ createNotification (NewOrder) error:', err));

    res.status(201).json({ success: true, message: 'Order placed successfully', order: formatOrder(fullOrder) });
  } catch (error) {
    await t.rollback();
    console.error('❌ Create order error:', error);
    res.status(500).json({ success: false, message: 'Server error while creating order' });
  }
};

// ===========================
// 📌 Helper: يجيب معلومات المجموعة (Grouped Delivery) لكل الطلبات المجمّعة
// الموجودة بقائمة طلبات - استعلام واحد إضافي (مو N+1) بغض النظر عن حجم
// القائمة. بيرجع Map بمفتاح group_id تستخدمها formatOrder.
// ===========================
async function buildGroupInfoMap(orders) {
  const groupIds = [...new Set(orders.map((o) => o.delivery_group_id).filter(Boolean))];
  if (!groupIds.length) return {};

  const groups = await DeliveryGroup.findAll({
    where: { group_id: groupIds },
    include: [{
      model: DeliveryGroupItem,
      as: 'items',
      include: [{ model: Order, as: 'order', include: [{ model: Restaurant, as: 'store' }] }]
    }]
  });

  const map = {};
  for (const group of groups) {
    // ✅ validSortedItems (مش sortedItems الخام) - عنصر بدون طلب محمّل
    // (بيانات ناقصة/قديمة) بيتجاهل بدل ما يفجّر .map تحت بـ i.order.*
    const items = validSortedItems(group);
    map[group.group_id] = {
      status: group.status,
      stores: items.map((i) => ({
        order_id: i.order.order_id.toString(),
        order_status: i.order.status,
        restaurant_id: i.order.restaurant_id ? i.order.restaurant_id.toString() : null,
        name: i.order.store ? i.order.store.name : null,
        address: i.order.store ? i.order.store.address : null,
        pickup_sequence: i.pickup_sequence
      }))
    };
  }
  return map;
}

// ===========================
// 📌 GET /api/orders/my  (طلبات المستخدم الحالي — حسب دوره)
// ===========================
const getMyOrders = async (req, res) => {
  try {
    const { role, user_id } = req.user;
    let where = {};

    if (role === 'Customer') where = { customer_id: user_id };
    else if (role === 'Restaurant') {
      const store = await Restaurant.findOne({ where: { user_id } });
      if (!store) return res.status(200).json({ success: true, orders: [] });
      where = { restaurant_id: store.restaurant_id };
    } else if (role === 'Driver') where = { driver_id: user_id };

    // ✅ فلترة تاريخ اختيارية (تقرير طلبات الزبون - ?from=&to=، صيغة ISO) -
    // اختيارية بالكامل ومتوافقة مع أي استدعاء قديم بدونها (نفس نمط
    // computeAdminAnalytics: Op.gte/Op.lte على order_time، بدون أي جدول جديد)
    const { from, to } = req.query;
    if (from || to) {
      where.order_time = {};
      if (from) {
        const fromDate = new Date(from);
        if (!isNaN(fromDate.getTime())) where.order_time[Op.gte] = fromDate;
      }
      if (to) {
        const toDate = new Date(to);
        if (!isNaN(toDate.getTime())) {
          toDate.setHours(23, 59, 59, 999); // نهاية اليوم المحدد، مش بدايته
          where.order_time[Op.lte] = toDate;
        }
      }
    }

    const orders = await Order.findAll({
      where,
      include: [
        { model: OrderItem, as: 'items', include: [{ model: Product, as: 'product' }] },
        { model: Restaurant, as: 'store' }
      ],
      order: [['order_time', 'DESC']]
    });

    const groupInfoMap = await buildGroupInfoMap(orders);
    res.status(200).json({ success: true, orders: orders.map((o) => formatOrder(o, groupInfoMap)) });
  } catch (error) {
    console.error('❌ Get my orders error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching orders' });
  }
};

// ===========================
// 📌 GET /api/orders/available  (طلبات جاهزة تحتاج سائق)
// ===========================
const getAvailableOrders = async (req, res) => {
  try {
    const orders = await Order.findAll({
      where: {
        status: 'Ready',
        driver_id: null,
        // ✅ Fallback الوحيد: طلب معروض حاليًا على سائق بعينه (محرك التعيين
        // الذكي - Phase 3، فردي أو مجمّع) ما لازم يظهر بالقائمة المفتوحة
        // العامة حتى ما يسرقه سائق تاني وهو لسا بانتظار رد الأول. لو المهلة
        // خلصت والـ sweep لسا ما لحق ينضّفها، منعتبرها منتهية هون كمان
        // (حماية إضافية). Grouped Delivery: نفس الحقول بالضبط منسوخة على
        // كل عضو بالمجموعة وقت العرض - فهاد الفلتر يشتغل صح بدون أي تعديل.
        [Op.or]: [
          { offered_driver_id: null },
          { offer_expires_at: { [Op.lt]: new Date() } }
        ]
      },
      include: [{ model: Restaurant, as: 'store' }],
      order: [['order_time', 'ASC']]
    });

    const groupInfoMap = await buildGroupInfoMap(orders);
    res.status(200).json({ success: true, orders: orders.map((o) => formatOrder(o, groupInfoMap)) });
  } catch (error) {
    console.error('❌ Get available orders error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching available orders' });
  }
};

// ===========================
// 📌 PUT /api/orders/:id/status  (تحديث حالة الطلب)
// ===========================
const updateOrderStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const validStatuses = ['Pending', 'Confirmed', 'Preparing', 'Ready', 'PickedUp', 'Delivered', 'Cancelled'];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status value' });
    }

    const order = await Order.findByPk(req.params.id);
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });

    const { role, user_id } = req.user;

    // ✅ لكل دور، منحدد شو مسموح يعمل وعلى أي طلب (منمنع صاحب محل يعدّل طلب محل تاني، إلخ)
    if (role === 'Restaurant') {
      const store = await Restaurant.findOne({ where: { user_id } });
      if (!store || store.restaurant_id !== order.restaurant_id) {
        return res.status(403).json({ success: false, message: 'This order does not belong to your store' });
      }
      const allowed = ['Confirmed', 'Preparing', 'Ready', 'Cancelled'];
      if (!allowed.includes(status)) {
        return res.status(403).json({ success: false, message: 'Restaurants cannot set this status' });
      }
    } else if (role === 'Driver') {
      const allowed = ['PickedUp', 'Delivered'];
      if (!allowed.includes(status)) {
        return res.status(403).json({ success: false, message: 'Drivers cannot set this status' });
      }
      if (status === 'Delivered' && order.driver_id !== user_id) {
        return res.status(403).json({ success: false, message: 'You are not assigned to this order' });
      }
      if (status === 'PickedUp' && order.driver_id && order.driver_id !== user_id) {
        return res.status(403).json({ success: false, message: 'This order is already assigned to another driver' });
      }
    } else if (role === 'Customer') {
      if (order.customer_id !== user_id || status !== 'Cancelled' || order.status !== 'Pending') {
        return res.status(403).json({ success: false, message: 'You can only cancel your own pending orders' });
      }
    } else if (role !== 'Admin') {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    // ✅ لو السائق قابل الطلب (PickedUp) ولسا ما محدد سائق -> نحطه هو
    // (Manual Accept - نفس النظام الأصلي، يضل شغال متل ما هو كـ fallback
    // للتعيين الذكي التلقائي). منسجّل نوع التعيين "يدوي" لتتبّع القرارات.
    if (status === 'PickedUp' && !order.driver_id && role === 'Driver') {
      // ✅ نفس حد "التعيين الذكي" الأقصى (MAX_CONCURRENT_ACTIVE_ORDERS) - كان
      // غير مطبّق إطلاقًا هون، فسائق كان يقدر ياخد طلبات يدوية بلا أي حد حتى
      // لو عنده أصلاً 3 (أو أكتر) طلبات نشطة، بعكس مسار التعيين التلقائي
      // اللي بيرفض هيك سائق من الأساس (scoringEngine.js passesHardFilters).
      const activeOrderCount = await Order.count({
        where: { driver_id: user_id, status: { [Op.notIn]: ACTIVE_DRIVER_ORDER_STATUSES } }
      });
      if (activeOrderCount >= MAX_CONCURRENT_ACTIVE_ORDERS) {
        return res.status(409).json({
          success: false,
          message: `You already have ${activeOrderCount} active orders (max ${MAX_CONCURRENT_ACTIVE_ORDERS}). Deliver one before accepting another.`
        });
      }

      order.driver_id = user_id;
      order.assigned_at = new Date();
      order.assignment_type = 'Manual';
      order.assignment_reason = { type: 'manual', note: 'Driver self-assigned from open orders list' };
    }

    const previousStatus = order.status;
    order.status = status;
    if (status === 'Delivered') order.completed_time = new Date();
    // ✅ لازم reassignment كامل للمصفوفة (مو push) عشان Sequelize يلتقط التغيير على عمود JSON
    order.status_history = [...(order.status_history || []), { status, at: new Date() }];

    // ✅ إلغاء الطلب لازم يقفل أي عرض تعيين ذكي معلّق عليه (وإلا بيضل معروض
    // على سائق لطلب ملغي لحد ما تنتهي مهلته لحالها)
    let groupPendingCancel = null;
    if (status === 'Cancelled') {
      clearPendingOffer(order);

      // ✅ Grouped Delivery: لو الطلب الملغي جزء من مجموعة لسا Forming (ما
      // تعيّن إلها سائق بعد)، لازم نفصله عنها - وإلا باقي أعضاء المجموعة
      // بيضلوا ينتظروا متجر ملغي أبدًا يصير Ready ولا رحلة تتعيّن إلها سائق.
      // لو المجموعة تعيّن إلها سائق أصلًا (Assigned)، منسيبها متل ما هي -
      // الطلب الملغي بيضل بينها بحالة Cancelled وباقي الأعضاء بيكملوا عادي.
      if (order.delivery_group_id) {
        const group = await DeliveryGroup.findByPk(order.delivery_group_id);
        if (group && group.status === 'Forming') {
          groupPendingCancel = group;
          order.delivery_group_id = null;
        }
      }
    }

    if (groupPendingCancel) {
      // ✅ حذف آخر عنصر بالمجموعة + تحديث حالتها + حفظ الطلب نفسه لازم يصيروا
      // بمعاملة وحدة ذرّية (transaction) - كانوا سابقًا عمليات منفصلة، وبينهم
      // نافذة زمنية حقيقية كانت المجموعة تظهر Forming بصفر عناصر (لو كانت آخر
      // عنصر إلها) أو الطلب يضل مرتبط بمجموعة ملغاة أصلًا لأي قراءة متزامنة
      // (خصوصًا sweepPendingGroupsBySize كل 20 ثانية) - وهاد بالضبط اللي كان
      // بيفجّر buildScoringOrderInput ويوقف السيرفر. بالمعاملة، أي قراءة تانية
      // بتشوف إما الحالة القديمة كاملة أو الجديدة كاملة، أبدًا الحالة الوسطى.
      await sequelize.transaction(async (t) => {
        await DeliveryGroupItem.destroy({ where: { order_id: order.order_id }, transaction: t });
        const remainingCount = await DeliveryGroupItem.count({ where: { group_id: groupPendingCancel.group_id }, transaction: t });
        if (remainingCount === 0) {
          groupPendingCancel.status = 'Cancelled';
          await groupPendingCancel.save({ transaction: t });
        }
        await order.save({ transaction: t });
      });
    } else {
      await order.save();
    }

    const io = getIo();

    // ✅ Loyalty: كسب نقاط (دخول Delivered)، سحبها (خروج منها - إلغاء بعد
    // التسليم أو إعادة فتح إدارية)، أو إرجاع نقاط استبدال (إلغاء). ما بيوقف
    // استجابة الـ endpoint لو فشل - نفس فلسفة الإشعارات (fire-safe، بس هون
    // await مش fire-and-forget عشان الرصيد يضل متسق فورًا لأي قراءة بعدها).
    try {
      await handleOrderStatusChange(order, previousStatus, status, io);
    } catch (loyaltyError) {
      console.error('❌ Loyalty status-change error:', loyaltyError);
    }

    if (io) {
      io.to(`order:${order.order_id}`).emit('order:status', {
        order_id: order.order_id,
        status: order.status
      });
    }

    // ✅ Phase 4 - إشعار الزبون بتغيّر حالة طلبه. ما منبعتلوش إشعار لو هو
    // نفسه اللي عمل التغيير (إلغاء طلبه الخاص - الحالة الوحيدة المسموحة لدور
    // Customer أصلًا) لأنه ما في داعي يبلّغ حاله بشي عمله للتو
    if (role !== 'Customer') {
      createNotification({
        userId: order.customer_id,
        title: 'تحديث حالة الطلب',
        body: `طلبك #${order.order_number} أصبح الآن: ${status}`,
        type: 'OrderStatus',
        relatedType: 'Order',
        relatedId: order.order_id,
        io
      }).catch((err) => console.error('❌ createNotification (OrderStatus) error:', err));
    } else {
      // ✅ باج كان موجود: إلغاء الزبون لطلبه (الحالة الوحيدة المسموحة لدوره)
      // ما كان يبلّغ حدا - صاحب المتجر ما بيعرف إلا لو فتح التطبيق بالصدفة.
      // role === 'Customer' هون معناها status === 'Cancelled' حتمًا (الفحص
      // فوق برفض أي إشي تاني لهاد الدور).
      Restaurant.findByPk(order.restaurant_id, { attributes: ['user_id'] })
        .then((cancelledStore) => {
          if (!cancelledStore) return;
          return createNotification({
            userId: cancelledStore.user_id,
            title: 'تم إلغاء طلب',
            body: `الزبون ألغى الطلب #${order.order_number}`,
            type: 'OrderStatus',
            relatedType: 'Order',
            relatedId: order.order_id,
            io
          });
        })
        .catch((err) => console.error('❌ createNotification (OrderStatus/customer-cancel) error:', err));
    }

    // ✅ Grouped Delivery: تسليم طلب لعميل هو فعليًا لحظة توصيل الرحلة كاملة -
    // أي طلب تاني بنفس المجموعة السائق خلص استلمه من متجره (PickedUp) بيتسلّم
    // بنفس اللحظة (بدل ما تطبيق السائق يحتاج ينادي الحالة لكل طلب لحاله).
    // أعضاء لسا Ready (ما استلمهم السائق بعد) بيضلوا متل ما هم - سيناريو ما
    // المفروض يصير لو السائق ماشي بالتسلسل الصحيح.
    if (role === 'Driver' && status === 'Delivered' && order.delivery_group_id) {
      const siblingsToDeliver = await Order.findAll({
        where: {
          delivery_group_id: order.delivery_group_id,
          order_id: { [Op.ne]: order.order_id },
          status: 'PickedUp'
        }
      });
      for (const sibling of siblingsToDeliver) {
        sibling.status = 'Delivered';
        sibling.completed_time = new Date();
        sibling.status_history = [...(sibling.status_history || []), { status: 'Delivered', at: new Date() }];
        await sibling.save();
        try {
          await handleOrderStatusChange(sibling, 'PickedUp', 'Delivered', io);
        } catch (loyaltyError) {
          console.error('❌ Loyalty status-change (sibling) error:', loyaltyError);
        }
        if (io) {
          io.to(`order:${sibling.order_id}`).emit('order:status', { order_id: sibling.order_id, status: 'Delivered' });
        }
        createNotification({
          userId: sibling.customer_id,
          title: 'تحديث حالة الطلب',
          body: `طلبك #${sibling.order_number} أصبح الآن: Delivered`,
          type: 'OrderStatus',
          relatedType: 'Order',
          relatedId: sibling.order_id,
          io
        }).catch((err) => console.error('❌ createNotification (OrderStatus/group) error:', err));
      }

      const remainingActive = await Order.count({
        where: { delivery_group_id: order.delivery_group_id, status: { [Op.notIn]: ACTIVE_DRIVER_ORDER_STATUSES } }
      });
      if (remainingActive === 0) {
        await DeliveryGroup.update({ status: 'Completed' }, { where: { group_id: order.delivery_group_id } });
      }
    }

    // ✅ Driver Availability: قبول طلب -> Busy، تسليمه -> Available (لو ما
    // في طلب تاني شغال عليه حالياً). كل تغيير حالة سائق مبثوث لحظيًا عبر
    // driverStatusService (نفس الخدمة المستخدمة بلوحة الشركة/الأدمن).
    if (role === 'Driver' && status === 'PickedUp') {
      await setDriverStatus(order.driver_id, 'Busy', io);
    } else if (role === 'Driver' && status === 'Delivered') {
      // ✅ NOT IN (Delivered/Cancelled/Refunded) مش بس PickedUp - عشان يحسب
      // كمان طلبات متعيّنة (Phase 3 Auto-assign) لسا ما وصلت PickedUp
      const stillBusy = await Order.count({
        where: { driver_id: order.driver_id, status: { [Op.notIn]: ACTIVE_DRIVER_ORDER_STATUSES } }
      });
      if (stillBusy === 0) await setDriverStatus(order.driver_id, 'Available', io);
    }

    // ✅ Phase 3/4 - Smart Assignment: لما المتجر يحط الطلب Ready، منجرب نلاقيله
    // أفضل سائق متاح ونعرضه عليه (fire-and-forget - فشل هون ما لازم يفشل
    // تحديث الحالة نفسه؛ الطلب بيضل Ready+driver_id=null = نفس الفالباك
    // للقائمة المفتوحة لو صار خطأ غير متوقع). Grouped Delivery: لو الطلب
    // جزء من مجموعة، منفوّض القرار لـ groupAssignmentService (يتحقق إنه كل
    // أعضاء المجموعة Ready قبل ما يعرضها كرحلة وحدة) بدل التعيين الفردي.
    if (role === 'Restaurant' && status === 'Ready') {
      if (order.delivery_group_id) {
        // ✅ مفتاح "Auto Assign Driver" بإعدادات الأدمن بيتحكم بس بالتعيين
        // التلقائي للرحلات المجمّعة - لو معطّل، الرحلة بتضل بلا سائق لحد ما
        // حدا يعيّنها يدويًا (acceptGroupManually، ما تأثر)
        getLiveGroupingSettings()
          .then((settings) => {
            if (settings.auto_assign_driver) {
              return tryAutoAssignGroupIfReady(order.delivery_group_id, io);
            }
          })
          .catch((err) => {
            console.error('❌ tryAutoAssignGroupIfReady error:', err);
          });
      } else {
        tryAutoAssign(order.order_id, io).catch((err) => {
          console.error('❌ tryAutoAssign error:', err);
        });
      }
    }

    res.status(200).json({ success: true, message: 'Order status updated', order: formatOrder(order) });
  } catch (error) {
    console.error('❌ Update order status error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating order status' });
  }
};

// ===========================
// 📌 GET /api/orders/:id/tracking  (تتبّع لحظي: يرجع مواقع المتجر/الوجهة/السائق الحالية)
// ===========================
const getOrderTracking = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id, {
      include: [
        { model: Restaurant, as: 'store' },
        {
          model: User,
          as: 'driver',
          attributes: { exclude: ['password'] },
          include: [{ model: User, as: 'company', attributes: ['user_id', 'full_name'] }]
        }
      ]
    });

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    const { role, user_id } = req.user;
    let allowed = role === 'Admin';
    if (role === 'Customer') allowed = order.customer_id === user_id;
    else if (role === 'Driver') allowed = order.driver_id === user_id;
    else if (role === 'Restaurant') {
      const store = await Restaurant.findOne({ where: { user_id } });
      allowed = !!store && store.restaurant_id === order.restaurant_id;
    }

    if (!allowed) {
      return res.status(403).json({ success: false, message: 'Not authorized to track this order' });
    }

    const storeLat = order.store ? parseFloat(order.store.location_lat) : null;
    const storeLng = order.store ? parseFloat(order.store.location_lng) : null;
    const deliveryLat = order.delivery_lat ? parseFloat(order.delivery_lat) : null;
    const deliveryLng = order.delivery_lng ? parseFloat(order.delivery_lng) : null;
    const distanceKm = haversineKm(storeLat, storeLng, deliveryLat, deliveryLng);

    // ✅ توصية #8 - لو الطلب جزء من رحلة توصيل مجمّعة، منرجع كل محطات الرحلة
    // (كل متجر بترتيب الاستلام) عشان شاشة السائق النشطة ترسم المسار كامل
    // على الخريطة، مش بس متجر هاد الطلب لحاله
    let groupStops = null;
    if (order.delivery_group_id) {
      const group = await withGroupContext(order.delivery_group_id);
      if (group) {
        groupStops = sortedItems(group)
          .filter((i) => i.order && i.order.store && i.order.store.location_lat != null)
          .map((i) => ({
            order_id: i.order.order_id.toString(),
            store_name: i.order.store.name,
            lat: parseFloat(i.order.store.location_lat),
            lng: parseFloat(i.order.store.location_lng),
            pickup_sequence: i.pickup_sequence,
            status: i.order.status
          }));
      }
    }

    res.status(200).json({
      success: true,
      order: {
        ...formatOrder(order),
        store_lat: storeLat,
        store_lng: storeLng,
        delivery_lat: deliveryLat,
        delivery_lng: deliveryLng,
        driver_current_lat: order.driver_current_lat ? parseFloat(order.driver_current_lat) : null,
        driver_current_lng: order.driver_current_lng ? parseFloat(order.driver_current_lng) : null,
        driver_location_updated_at: order.driver_location_updated_at,
        driver_name: order.driver ? order.driver.full_name : null,
        driver_phone: order.driver ? order.driver.phone : null,
        driver_photo: order.driver ? order.driver.profile_picture : null,
        driver_vehicle_type: order.driver ? order.driver.business_type : null,
        // ✅ ما منعرض اسم الشركة إلا لو الشركة وافقت فعلاً على انضمام السائق
        // (company_join_status='Approved') - غير هيك بيكون طلب لسا Pending
        driver_company_name: order.driver && order.driver.company && order.driver.company_join_status === 'Approved'
          ? order.driver.company.full_name
          : null,
        status_history: buildStatusHistory(order),
        eta: await predictOrderEta(order, distanceKm),
        group_stops: groupStops
      }
    });
  } catch (error) {
    console.error('❌ Get order tracking error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching order tracking' });
  }
};

// ===========================
// 📌 Helper: سجل زمني حقيقي لكل تغيير حالة - مع fallback بسيط لطلبات قديمة
// اتنشأت قبل إضافة عمود status_history (ما نكسرها، بس تقديرها أبسط)
// ===========================
function buildStatusHistory(order) {
  if (Array.isArray(order.status_history) && order.status_history.length) {
    return order.status_history;
  }
  const history = [{ status: 'Pending', at: order.order_time }];
  if (order.status !== 'Pending') {
    history.push({ status: order.status, at: order.completed_time || order.updated_at });
  }
  return history;
}

function formatOrder(order, groupInfoMap = {}) {
  const groupInfo = order.delivery_group_id ? groupInfoMap[order.delivery_group_id] : null;
  return {
    id: order.order_id.toString(),
    order_number: order.order_number,
    status: order.status,
    total_amount: parseFloat(order.total_amount),
    delivery_fee: parseFloat(order.delivery_fee),
    discount: parseFloat(order.discount || 0),
    final_amount: parseFloat(order.final_amount),
    delivery_address: order.delivery_address,
    special_instructions: order.special_instructions || null,
    payment_method: order.payment_method,
    payment_status: order.payment_status,
    order_time: order.order_time,
    store_id: order.restaurant_id ? order.restaurant_id.toString() : null,
    store_name: order.store ? order.store.name : undefined,
    store_image: order.store ? (order.store.image_url || order.store.logo || null) : undefined,
    store_address: order.store ? order.store.address : undefined,
    store_city: order.store ? order.store.city : undefined,
    driver_id: order.driver_id ? order.driver_id.toString() : null,
    // ✅ Phase 3 - Smart Assignment: معلومات تتبّع التعيين (سبب/وقت/نوع)
    // وحالة العرض المعلّق الحالي إن وجد - مفيدة لشاشات الأدمن/الدعم
    assigned_at: order.assigned_at || null,
    assignment_type: order.assignment_type || null,
    assignment_reason: order.assignment_reason || null,
    offered_driver_id: order.offered_driver_id ? order.offered_driver_id.toString() : null,
    offer_expires_at: order.offer_expires_at || null,
    // ✅ Grouped Delivery: لو الطلب جزء من رحلة توصيل مجمّعة - راجع buildGroupInfoMap
    delivery_group_id: order.delivery_group_id ? order.delivery_group_id.toString() : null,
    group_status: groupInfo ? groupInfo.status : null,
    group_stores: groupInfo ? groupInfo.stores : null,
    items: (order.items || []).map(i => ({
      product_id: i.product_id.toString(),
      name: i.product ? i.product.name : '',
      image_url: i.product ? (i.product.image_url || null) : null,
      quantity: i.quantity,
      unit_price: parseFloat(i.unit_price),
      variant_label: i.variant_label || null,
      addons: i.addons || [],
      special_requests: i.special_requests || [],
      selected_options: i.selected_options || [],
      subtotal: parseFloat(i.subtotal)
    }))
  };
}

// ===========================
// 📌 GET /api/orders/offers/mine  (العرض المعلّق حاليًا على السائق، إن وجد)
// يغطّي حالة إنو تطبيق السائق كان مقفول لما وصل event السوكيت order:offer
// ===========================
const getMyPendingOffer = async (req, res) => {
  try {
    const order = await Order.findOne({
      where: {
        offered_driver_id: req.user.user_id,
        offer_expires_at: { [Op.gt]: new Date() }
      },
      include: [{ model: Restaurant, as: 'store' }]
    });

    if (!order) return res.status(200).json({ success: true, offer: null });

    // ✅ Grouped Delivery: offered_driver_id/offer_expires_at منسوخة على كل
    // عضو بالمجموعة وقت العرض (راجع groupAssignmentService) - findOne فوق
    // ممكن يلقط أي واحد منهم. لو الطلب جزء من مجموعة، منرجع تفصيل الرحلة
    // كاملة بدل طلب واحد بس.
    if (order.delivery_group_id) {
      const group = await withGroupContext(order.delivery_group_id);
      const items = group ? validSortedItems(group) : [];
      const reasonInfo = group ? extractOfferReasonInfo(group.offer_history, req.user.user_id) : { label: null, distanceKm: null };
      return res.status(200).json({
        success: true,
        offer: {
          is_group: true,
          group_id: order.delivery_group_id.toString(),
          order_count: items.length,
          order_ids: items.map((i) => i.order.order_id.toString()),
          stores: items.map((i) => ({
            restaurant_id: i.order.store ? i.order.store.restaurant_id.toString() : null,
            name: i.order.store ? i.order.store.name : null,
            address: i.order.store ? i.order.store.address : null,
            pickup_sequence: i.pickup_sequence
          })),
          delivery_address: order.delivery_address,
          delivery_fee: items.reduce((sum, i) => sum + parseFloat(i.order.delivery_fee || 0), 0),
          distance_km: reasonInfo.distanceKm,
          reason_label: reasonInfo.label,
          expires_at: order.offer_expires_at
        }
      });
    }

    const reasonInfo = extractOfferReasonInfo(order.offer_history, req.user.user_id);
    res.status(200).json({
      success: true,
      offer: {
        is_group: false,
        order_id: order.order_id.toString(),
        order_number: order.order_number,
        order_count: 1,
        store_name: order.store ? order.store.name : null,
        store_address: order.store ? order.store.address : null,
        delivery_address: order.delivery_address,
        delivery_fee: parseFloat(order.delivery_fee),
        distance_km: reasonInfo.distanceKm,
        reason_label: reasonInfo.label,
        expires_at: order.offer_expires_at
      }
    });
  } catch (error) {
    console.error('❌ Get my pending offer error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching pending offer' });
  }
};

// ===========================
// 📌 POST /api/orders/:id/offer/respond  (قبول/رفض عرض Phase 3 - body: { action: 'accept'|'reject' })
// ===========================
const respondToOrderOffer = async (req, res) => {
  try {
    const { action } = req.body;
    if (!['accept', 'reject'].includes(action)) {
      return res.status(400).json({ success: false, message: "action must be 'accept' or 'reject'" });
    }

    const result = await respondToOffer(req.params.id, req.user.user_id, action, getIo());

    if (!result.success) {
      const messages = {
        NOT_FOUND: 'Order not found',
        NOT_OFFERED: 'This order is not currently offered to you',
        EXPIRED: 'This offer has expired'
      };
      return res.status(409).json({ success: false, code: result.code, message: messages[result.code] || 'Unable to respond to offer' });
    }

    res.status(200).json({
      success: true,
      message: action === 'accept' ? 'Order accepted' : 'Order rejected',
      order: formatOrder(result.order)
    });
  } catch (error) {
    console.error('❌ Respond to order offer error:', error);
    res.status(500).json({ success: false, message: 'Server error while responding to offer' });
  }
};

module.exports = {
  createOrder,
  getMyOrders,
  getAvailableOrders,
  updateOrderStatus,
  getOrderTracking,
  getMyPendingOffer,
  respondToOrderOffer
};
