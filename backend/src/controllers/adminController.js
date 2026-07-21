// src/controllers/adminController.js
const { Op } = require('sequelize');
const { User, Category, Restaurant, Product, Order, OrderItem, Coupon, DeliveryGroup, DeliveryGroupItem, SystemSettings, sequelize } = require('../models');
const { formatCoupon } = require('./couponController');
const { getEffectiveStatus, setDriverStatus } = require('../services/driverStatusService');
const { getGroupingStats, getLiveGroupingSettings, evaluateGroupingMatch } = require('../services/groupingService');
const GROUPING_DEFAULTS = require('../services/grouping/config');
const LOYALTY_DEFAULTS = require('../services/loyalty/config');
const { createNotification, notifyRole } = require('../services/notificationService');
const { getIo } = require('../sockets');
const { haversineKm } = require('../utils/geo');
const { rankCandidates } = require('../services/assignment/scoringEngine');
const { buildScoringOrderInput, sortedItems, validSortedItems } = require('../services/groupAssignmentService');
const { computeDriverPerformance } = require('../services/analytics/driverAnalyticsService');
const { computeStoreAnalytics } = require('../services/analytics/storeAnalyticsService');
const { computeAdminAnalytics } = require('../services/analytics/adminAnalyticsService');

// ✅ سائق احتياطي (توصية #5): ثاني أفضل مرشح لو المجموعة/الطلب اتعيّن/معروض
// عليه سائق أصلًا - مش حقل مخزّن (بدون أي تعديل بقاعدة البيانات)، بس حساب
// حي وقت الطلب عبر نفس محرك الترتيب (scoringEngine.rankCandidates) مستثنين
// السائق الحالي. الفشل التلقائي الفعلي للسائق التالي عند انتهاء مهلة العرض
// موجود أصلًا (sweepExpiredGroupOffers/sweepExpiredOffers) - هاد بس يعرض
// "مين التالي" مقدّمًا للأدمن.
async function computeBackupDriver(scoringInput, currentDriverId) {
  if (!currentDriverId || !scoringInput || !scoringInput.store) return null;
  try {
    const candidates = await rankCandidates(scoringInput, [currentDriverId]);
    if (!candidates.length) return null;
    const top = candidates[0];
    return { id: top.driver.user_id.toString(), name: top.driver.full_name, score: top.score };
  } catch (error) {
    console.error('❌ computeBackupDriver error:', error);
    return null;
  }
}

// ✅ سجل زمني كامل لرحلة توصيل مجمّعة (توصية #10) - مبني بالكامل من بيانات
// موجودة أصلًا (created_at/assigned_at + status_history لكل طلب عضو)، بدون
// أي عمود جديد بقاعدة البيانات.
const GROUP_TIMELINE_LABELS = {
  group_created: 'Order Created',
  order_grouped: 'Grouped',
  driver_assigned: 'Driver Assigned',
  pickup: 'Pickup',
  delivered: 'Delivered'
};

function buildGroupTimeline(group) {
  const items = sortedItems(group);
  const events = [{ type: 'group_created', at: group.created_at }];

  items.slice(1).forEach((item) => {
    events.push({ type: 'order_grouped', at: item.created_at, order_id: item.order_id.toString() });
  });
  if (group.assigned_at) {
    events.push({ type: 'driver_assigned', at: group.assigned_at });
  }
  items.forEach((item) => {
    const order = item.order;
    const history = Array.isArray(order && order.status_history) ? order.status_history : [];
    const storeName = order && order.store ? order.store.name : null;
    history.forEach((entry) => {
      if (entry.status === 'PickedUp') {
        events.push({ type: 'pickup', at: entry.at, store_name: storeName, order_id: item.order_id.toString() });
      } else if (entry.status === 'Delivered') {
        events.push({ type: 'delivered', at: entry.at, order_id: item.order_id.toString() });
      }
    });
  });

  events.sort((a, b) => new Date(a.at) - new Date(b.at));
  return events.map((e) => ({
    type: e.type,
    label: GROUP_TIMELINE_LABELS[e.type] || e.type,
    at: e.at,
    order_id: e.order_id || null,
    store_name: e.store_name || null
  }));
}

const VALID_USER_STATUSES = ['Pending', 'Approved', 'Rejected', 'Suspended'];

const USER_STATUS_NOTIFICATION_BODY = {
  Approved: 'تم اعتماد حسابك - أصبح بإمكانك استخدام كل ميزات المنصة الآن',
  Suspended: 'تم تعليق حسابك من قِبل الإدارة',
  Rejected: 'تم رفض حسابك من قِبل الإدارة',
  Pending: 'حسابك الآن قيد المراجعة من الإدارة'
};

const formatStoreForAdmin = (store) => ({
  id: store.restaurant_id,
  name: store.name,
  category: store.category ? store.category.name : null,
  address: store.address,
  image_url: store.image_url,
  approval_status: store.approval_status,
  is_featured: !!store.is_featured
});

// ===========================
// 📌 GET /api/admin/dashboard
// ===========================
const getDashboardStats = async (req, res) => {
  try {
    const [totalUsers, totalStores, totalOrders, revenue, ordersByStatus, deliveryGroups] = await Promise.all([
      User.count(),
      Restaurant.count(),
      Order.count(),
      Order.sum('final_amount', { where: { status: 'Delivered' } }),
      Order.findAll({
        attributes: ['status', [sequelize.fn('COUNT', sequelize.col('order_id')), 'count']],
        group: ['status']
      }),
      // ✅ Grouped Delivery (Smart Order Clustering) - راجع groupingService.getGroupingStats
      getGroupingStats()
    ]);

    res.status(200).json({
      success: true,
      stats: {
        total_users: totalUsers,
        total_stores: totalStores,
        total_orders: totalOrders,
        revenue: revenue || 0,
        delivery_groups: deliveryGroups
      },
      orders_by_status: ordersByStatus.map(o => ({
        status: o.status,
        count: Number(o.get('count'))
      }))
    });
  } catch (error) {
    console.error('❌ Admin dashboard stats error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching dashboard stats' });
  }
};

// ===========================
// 📌 GET /api/admin/stores  (كل المتاجر بغض النظر عن حالة الموافقة)
// ===========================
const getStores = async (req, res) => {
  try {
    const stores = await Restaurant.findAll({
      include: [{ model: Category, as: 'category', attributes: ['category_id', 'name'] }],
      order: [['created_at', 'DESC']]
    });
    res.status(200).json({ success: true, stores: stores.map(formatStoreForAdmin) });
  } catch (error) {
    console.error('❌ Admin get stores error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching stores' });
  }
};

// ===========================
// 📌 PUT /api/admin/stores/:id/approve
// ===========================
const approveStore = async (req, res) => {
  try {
    const store = await Restaurant.findByPk(req.params.id);
    if (!store) {
      return res.status(404).json({ success: false, message: 'Store not found' });
    }
    await store.update({ approval_status: 'Approved', rejection_reason: null });

    // متزامن مع حالة حساب صاحب المتجر (User.status) عشان ما تضل عالقة Pending
    const owner = await User.findByPk(store.user_id);
    if (owner && owner.status === 'Pending') {
      await owner.update({ status: 'Approved' });
    }

    // ✅ باج كان موجود: موافقة/رفض متجر ما كان يبلّغ صاحبه بأي إشعار - هاد
    // بالضبط زر الموافقة الفعلي يلي الأدمن بيستخدمه (بعكس updateUserStatus
    // العام يلي بيبلّغ)
    if (owner) {
      createNotification({
        userId: owner.user_id,
        title: 'تم اعتماد متجرك',
        body: `تمت الموافقة على متجرك "${store.name}" وهو الآن ظاهر للزبائن`,
        type: 'AdminApproval',
        relatedType: 'Restaurant',
        relatedId: store.restaurant_id,
        io: getIo()
      }).catch((err) => console.error('❌ createNotification (AdminApproval/store-approve) error:', err));
    }

    res.status(200).json({ success: true, message: 'Store approved' });
  } catch (error) {
    console.error('❌ Admin approve store error:', error);
    res.status(500).json({ success: false, message: 'Server error while approving store' });
  }
};

// ===========================
// 📌 PUT /api/admin/stores/:id/reject
// ===========================
const rejectStore = async (req, res) => {
  try {
    const store = await Restaurant.findByPk(req.params.id);
    if (!store) {
      return res.status(404).json({ success: false, message: 'Store not found' });
    }
    await store.update({
      approval_status: 'Rejected',
      rejection_reason: req.body.reason || null
    });

    // ✅ باج كان موجود: نفس فجوة approveStore - وrejection_reason كان
    // يُخزَّن بس ما يوصل صاحب المتجر أبدًا (مش حتى برسالة الرفض)
    createNotification({
      userId: store.user_id,
      title: 'تم رفض متجرك',
      body: req.body.reason
        ? `تم رفض متجرك "${store.name}": ${req.body.reason}`
        : `تم رفض متجرك "${store.name}"`,
      type: 'AdminApproval',
      relatedType: 'Restaurant',
      relatedId: store.restaurant_id,
      io: getIo()
    }).catch((err) => console.error('❌ createNotification (AdminApproval/store-reject) error:', err));

    res.status(200).json({ success: true, message: 'Store rejected' });
  } catch (error) {
    console.error('❌ Admin reject store error:', error);
    res.status(500).json({ success: false, message: 'Server error while rejecting store' });
  }
};

// ===========================
// 📌 PATCH /api/admin/stores/:id/featured
// ===========================
const toggleFeaturedStore = async (req, res) => {
  try {
    const store = await Restaurant.findByPk(req.params.id);
    if (!store) {
      return res.status(404).json({ success: false, message: 'Store not found' });
    }
    await store.update({ is_featured: !!req.body.is_featured });
    res.status(200).json({ success: true, message: 'Store featured flag updated', is_featured: store.is_featured });
  } catch (error) {
    console.error('❌ Admin toggle featured error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating featured flag' });
  }
};

// ===========================
// 📌 DELETE /api/admin/stores/:id
// ===========================
const deleteStore = async (req, res) => {
  try {
    const store = await Restaurant.findByPk(req.params.id);
    if (!store) {
      return res.status(404).json({ success: false, message: 'Store not found' });
    }
    await store.destroy();
    res.status(200).json({ success: true, message: 'Store deleted' });
  } catch (error) {
    console.error('❌ Admin delete store error:', error);
    res.status(500).json({ success: false, message: 'Server error while deleting store' });
  }
};

// ===========================
// 📌 GET /api/admin/companies  (حسابات شركات التوصيل - User بـ business_type='Fleet / Company')
// ===========================
const getDeliveryCompanies = async (req, res) => {
  try {
    const companies = await User.findAll({
      where: { role: 'Driver', business_type: 'Fleet / Company' },
      attributes: { exclude: ['password', 'reset_password_token', 'reset_password_expires'] },
      order: [['created_at', 'DESC']]
    });
    res.status(200).json({
      success: true,
      companies: companies.map(c => ({
        id: c.user_id,
        name: c.full_name,
        email: c.email,
        phone: c.phone,
        city: c.city,
        region: c.region,
        status: c.status
      }))
    });
  } catch (error) {
    console.error('❌ Admin get delivery companies error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching delivery companies' });
  }
};

// ===========================
// 📌 PUT /api/admin/companies/:id/approve
// ===========================
const approveCompany = async (req, res) => {
  try {
    const company = await User.findByPk(req.params.id);
    if (!company || company.role !== 'Driver' || company.business_type !== 'Fleet / Company') {
      return res.status(404).json({ success: false, message: 'Delivery company not found' });
    }
    await company.update({ status: 'Approved' });

    createNotification({
      userId: company.user_id,
      title: 'تم اعتماد حساب شركتك',
      body: 'تمت الموافقة على حساب شركة التوصيل الخاص فيك',
      type: 'AdminApproval',
      relatedType: 'User',
      relatedId: company.user_id,
      io: getIo()
    }).catch((err) => console.error('❌ createNotification (AdminApproval/company-approve) error:', err));

    res.status(200).json({ success: true, message: 'Delivery company approved' });
  } catch (error) {
    console.error('❌ Admin approve company error:', error);
    res.status(500).json({ success: false, message: 'Server error while approving delivery company' });
  }
};

// ===========================
// 📌 PUT /api/admin/companies/:id/reject
// ===========================
const rejectCompany = async (req, res) => {
  try {
    const company = await User.findByPk(req.params.id);
    if (!company || company.role !== 'Driver' || company.business_type !== 'Fleet / Company') {
      return res.status(404).json({ success: false, message: 'Delivery company not found' });
    }
    await company.update({ status: 'Rejected' });

    createNotification({
      userId: company.user_id,
      title: 'تم رفض حساب شركتك',
      body: 'تم رفض حساب شركة التوصيل الخاص فيك',
      type: 'AdminApproval',
      relatedType: 'User',
      relatedId: company.user_id,
      io: getIo()
    }).catch((err) => console.error('❌ createNotification (AdminApproval/company-reject) error:', err));

    res.status(200).json({ success: true, message: 'Delivery company rejected' });
  } catch (error) {
    console.error('❌ Admin reject company error:', error);
    res.status(500).json({ success: false, message: 'Server error while rejecting delivery company' });
  }
};

// ===========================
// 📌 GET /api/admin/coupons  (كل الكوبونات - متجرية وعامة - للمراقبة فقط)
// ===========================
const getAllCoupons = async (req, res) => {
  try {
    const coupons = await Coupon.findAll({
      include: [{ model: Restaurant, as: 'store', attributes: ['name'] }],
      order: [['created_at', 'DESC']]
    });
    res.status(200).json({
      success: true,
      coupons: coupons.map(c => ({
        ...formatCoupon(c),
        store_name: c.store ? c.store.name : null // null = كوبون عام
      }))
    });
  } catch (error) {
    console.error('❌ Admin get coupons error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching coupons' });
  }
};

// ===========================
// 📌 GET /api/admin/orders  (كل الطلبات - فلترة اختيارية حسب الحالة)
// ===========================
const getOrders = async (req, res) => {
  try {
    const { status } = req.query;
    const where = {};
    if (status) where.status = status;

    const orders = await Order.findAll({
      where,
      include: [
        { model: Restaurant, as: 'store', attributes: ['name'] },
        { model: User, as: 'customer', attributes: ['full_name'] },
        {
          model: User,
          as: 'driver',
          attributes: ['full_name'],
          include: [{ model: User, as: 'company', attributes: ['full_name'] }]
        }
      ],
      order: [['order_time', 'DESC']]
    });

    res.status(200).json({
      success: true,
      orders: orders.map(o => ({
        id: o.order_id,
        order_number: o.order_number,
        status: o.status,
        final_amount: parseFloat(o.final_amount),
        store_name: o.store ? o.store.name : null,
        customer_name: o.customer ? o.customer.full_name : null,
        driver_name: o.driver ? o.driver.full_name : null,
        // ✅ استكمال: اسم شركة التوصيل (لو السائق تابع لشركة) - كان مفقود كليًا
        driver_company_name: o.driver && o.driver.company ? o.driver.company.full_name : null,
        order_time: o.order_time,
        updated_at: o.updated_at,
        delivery_group_id: o.delivery_group_id ? o.delivery_group_id.toString() : null,
        // ✅ Phase 3 - Smart Assignment: تتبّع قرار التعيين للدعم/المراجعة
        assigned_at: o.assigned_at,
        assignment_type: o.assignment_type,
        assignment_reason: o.assignment_reason,
        offer_history: o.offer_history
      }))
    });
  } catch (error) {
    console.error('❌ Admin get orders error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching orders' });
  }
};

// ===========================
// 📌 GET /api/admin/orders/:id  (تفاصيل طلب كاملة - العميل/المتجر/السائق/
// الشركة/العناصر/سجل الحالات/معلومات التعيين الذكي/رحلة التوصيل المجمّعة إن وجدت)
// ===========================
const getOrderDetail = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id, {
      include: [
        { model: Restaurant, as: 'store' },
        { model: User, as: 'customer', attributes: ['user_id', 'full_name', 'email', 'phone'] },
        {
          model: User,
          as: 'driver',
          attributes: ['user_id', 'full_name', 'phone', 'business_type'],
          include: [{ model: User, as: 'company', attributes: ['user_id', 'full_name'] }]
        },
        { model: OrderItem, as: 'items', include: [{ model: Product, as: 'product' }] }
      ]
    });

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    // ✅ سائق احتياطي (#5) - null لو الطلب خلص/ملغي أو ما في سائق حالي إطلاقًا
    const currentDriverId = order.driver_id || order.offered_driver_id;
    const isFinished = ['Delivered', 'Cancelled', 'Refunded'].includes(order.status);

    let deliveryGroup = null;
    let backupDriver = null;
    if (order.delivery_group_id) {
      const group = await DeliveryGroup.findByPk(order.delivery_group_id, {
        include: [{
          model: DeliveryGroupItem,
          as: 'items',
          include: [{ model: Order, as: 'order', include: [{ model: Restaurant, as: 'store' }] }]
        }]
      });
      if (group) {
        const items = validSortedItems(group);
        deliveryGroup = {
          group_id: group.group_id.toString(),
          status: group.status,
          stores: items.map((i) => ({
            order_id: i.order.order_id.toString(),
            order_status: i.order.status,
            store_name: i.order.store ? i.order.store.name : null,
            pickup_sequence: i.pickup_sequence,
            matched_with_order_id: i.matched_with_order_id ? i.matched_with_order_id.toString() : null,
            store_distance_km: i.store_distance_km !== null ? parseFloat(i.store_distance_km) : null,
            delivery_distance_km: i.delivery_distance_km !== null ? parseFloat(i.delivery_distance_km) : null,
            time_difference_minutes: i.time_difference_minutes,
            rules_satisfied: i.rules_satisfied
          })),
          timeline: buildGroupTimeline(group)
        };
        if (currentDriverId && !isFinished) {
          backupDriver = await computeBackupDriver(buildScoringOrderInput(group), currentDriverId);
        }
      }
    } else if (currentDriverId && !isFinished && order.store) {
      backupDriver = await computeBackupDriver(
        { order_id: order.order_id, store: order.store, required_vehicle_type: order.required_vehicle_type, preferred_company_id: order.preferred_company_id },
        currentDriverId
      );
    }

    res.status(200).json({
      success: true,
      order: {
        id: order.order_id.toString(),
        order_number: order.order_number,
        status: order.status,
        total_amount: parseFloat(order.total_amount),
        delivery_fee: parseFloat(order.delivery_fee),
        discount: parseFloat(order.discount || 0),
        final_amount: parseFloat(order.final_amount),
        delivery_address: order.delivery_address,
        special_instructions: order.special_instructions,
        payment_method: order.payment_method,
        payment_status: order.payment_status,
        order_time: order.order_time,
        completed_time: order.completed_time,
        created_at: order.created_at,
        updated_at: order.updated_at,
        status_history: order.status_history || [],
        store: order.store ? {
          id: order.store.restaurant_id.toString(),
          name: order.store.name,
          address: order.store.address,
          phone: order.store.phone
        } : null,
        customer: order.customer ? {
          id: order.customer.user_id.toString(),
          full_name: order.customer.full_name,
          email: order.customer.email,
          phone: order.customer.phone
        } : null,
        driver: order.driver ? {
          id: order.driver.user_id.toString(),
          full_name: order.driver.full_name,
          phone: order.driver.phone,
          vehicle_type: order.driver.business_type,
          company_name: order.driver.company ? order.driver.company.full_name : null
        } : null,
        items: (order.items || []).map((i) => ({
          product_id: i.product_id.toString(),
          name: i.product ? i.product.name : '',
          quantity: i.quantity,
          unit_price: parseFloat(i.unit_price),
          variant_label: i.variant_label || null,
          subtotal: parseFloat(i.subtotal)
        })),
        // ✅ Phase 3 - Smart Assignment
        assigned_at: order.assigned_at,
        assignment_type: order.assignment_type,
        assignment_reason: order.assignment_reason,
        offer_history: order.offer_history || [],
        // ✅ سائق احتياطي (#5) - ثاني أفضل مرشح حاليًا، null لو ما في سائق
        // حالي أو الطلب خلص
        backup_driver: backupDriver,
        // ✅ Grouped Delivery (لو الطلب جزء من رحلة مجمّعة)
        delivery_group: deliveryGroup
      }
    });
  } catch (error) {
    console.error('❌ Admin get order detail error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching order detail' });
  }
};

// ===========================
// 📌 GET /api/admin/users
// ===========================
const getUsers = async (req, res) => {
  try {
    const users = await User.findAll({
      attributes: { exclude: ['password', 'reset_password_token', 'reset_password_expires'] },
      order: [['created_at', 'DESC']]
    });
    res.status(200).json({
      success: true,
      users: users.map(u => ({
        id: u.user_id,
        full_name: u.full_name,
        email: u.email,
        role: u.role,
        // ✅ استكمال إدارة المستخدمين (لوحة الأدمن Phase 3): كانت هاي الحقول
        // موجودة بالـ User أصلًا بس ما كانت ترجع هون - بدونها الفرونت ما بيقدر
        // يعرض حالة الحساب ولا يفلتر حسب النوع/الحالة
        business_type: u.business_type,
        phone: u.phone,
        status: u.status,
        is_active: u.is_active,
        city: u.city,
        region: u.region,
        loyalty_points: u.loyalty_points,
        created_at: u.created_at
      }))
    });
  } catch (error) {
    console.error('❌ Admin get users error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching users' });
  }
};

// ===========================
// 📌 PATCH /api/admin/users/:id/status  (تعديل حالة أي مستخدم بغض النظر عن
// دوره - Active/Approved، Suspended، Pending، Rejected. نقطة الوصول
// العامة الوحيدة لتغيير User.status - راجعي approveStore/rejectStore/
// approveCompany/rejectCompany لتدفقات موافقة خاصة (متجر/شركة) لسا موجودة
// وما لمسناها، بس هاي أول نقطة تسمح بتغيير حالة أي مستخدم (زبون مثلاً) عمومًا)
// ===========================
const updateUserStatus = async (req, res) => {
  try {
    const { status } = req.body;
    if (!VALID_USER_STATUSES.includes(status)) {
      return res.status(400).json({ success: false, message: `status must be one of: ${VALID_USER_STATUSES.join(', ')}` });
    }

    const user = await User.findByPk(req.params.id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    await user.update({ status });

    // ✅ تعليق الحساب لازم يوقف أي نشاط فعلي فورًا - مش بس يغيّر راية بقاعدة
    // البيانات. ما منعمل أي شي عكسي تلقائي عند إعادة التفعيل (صاحب المتجر/
    // السائق لازم يفعّل شغله يدويًا من جديد) - قرار متحفظ ومقصود.
    if (status === 'Suspended') {
      if (user.role === 'Restaurant') {
        await Restaurant.update({ is_active: false }, { where: { user_id: user.user_id } });
      } else if (user.role === 'Driver') {
        await setDriverStatus(user.user_id, 'Offline', getIo());
      }
    }

    // ✅ Phase 4 - إشعار المستخدم بتغيّر حالة حسابه
    createNotification({
      userId: user.user_id,
      title: 'تحديث حالة الحساب',
      body: USER_STATUS_NOTIFICATION_BODY[status] || `تم تحديث حالة حسابك إلى ${status}`,
      type: 'UserStatus',
      io: getIo()
    }).catch((err) => console.error('❌ createNotification (UserStatus) error:', err));

    res.status(200).json({ success: true, message: 'User status updated', status: user.status });
  } catch (error) {
    console.error('❌ Admin update user status error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating user status' });
  }
};

// ===========================
// 📌 GET /api/admin/drivers  (سائقين مستقلين/تابعين لشركة - مش حسابات الشركات نفسها)
// ===========================
const getDrivers = async (req, res) => {
  try {
    const drivers = await User.findAll({
      // ✅ business_type IS NULL (سائق فردي عادي بدون قيمة محفوظة) كان يُستبعد
      // صامتًا بـ Op.ne (مقارنة NULL بـ SQL نتيجتها NULL مش true) - نفس الباج
      // اللي انلقى بمحرك التعيين الذكي (scoringEngine.js)
      where: { role: 'Driver', [Op.or]: [{ business_type: { [Op.ne]: 'Fleet / Company' } }, { business_type: null }] },
      include: [{ model: User, as: 'company', attributes: ['user_id', 'full_name'] }],
      attributes: { exclude: ['password', 'reset_password_token', 'reset_password_expires'] },
      order: [['created_at', 'DESC']]
    });

    const driverIds = drivers.map((d) => d.user_id);
    const deliveredCounts = driverIds.length
      ? await Order.findAll({
          attributes: ['driver_id', [sequelize.fn('COUNT', sequelize.col('order_id')), 'count']],
          where: { status: 'Delivered', driver_id: driverIds },
          group: ['driver_id'],
          raw: true
        })
      : [];
    const countByDriver = new Map(deliveredCounts.map((r) => [r.driver_id, parseInt(r.count, 10)]));

    res.status(200).json({
      success: true,
      drivers: drivers.map((d) => ({
        id: d.user_id.toString(),
        full_name: d.full_name,
        phone: d.phone,
        email: d.email,
        vehicle_type: d.business_type,
        account_status: d.status,
        is_active: d.is_active,
        driver_status: getEffectiveStatus(d),
        company_name: d.company ? d.company.full_name : null,
        delivered_count: countByDriver.get(d.user_id) || 0,
        created_at: d.created_at,
        // ⚠️ ما في نظام تقييم سائقين بالمشروع لسا (Review مربوط بالمتجر بس،
        // مش بالسائق) - null صريح بدل ما نخترع رقم. لو انبنى لاحقًا، يتعبى هون بس.
        rating: null
      }))
    });
  } catch (error) {
    console.error('❌ Admin get drivers error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching drivers' });
  }
};

// ===========================
// 📌 GET /api/admin/categories  (فئات + عدد المتاجر والمنتجات بكل فئة)
// ===========================
const getCategories = async (req, res) => {
  try {
    const categories = await Category.findAll({ order: [['sort_order', 'ASC']] });

    const [storeCounts, productCounts] = await Promise.all([
      Restaurant.findAll({
        attributes: ['category_id', [sequelize.fn('COUNT', sequelize.col('restaurant_id')), 'count']],
        group: ['category_id'],
        raw: true
      }),
      Product.findAll({
        attributes: [
          [sequelize.col('store.category_id'), 'category_id'],
          [sequelize.fn('COUNT', sequelize.col('Product.product_id')), 'count']
        ],
        include: [{ model: Restaurant, as: 'store', attributes: [] }],
        group: ['store.category_id'],
        raw: true
      })
    ]);
    const storeCountByCategory = new Map(storeCounts.map((r) => [r.category_id, parseInt(r.count, 10)]));
    const productCountByCategory = new Map(productCounts.map((r) => [r.category_id, parseInt(r.count, 10)]));

    const withCounts = categories.map((c) => ({
      id: c.category_id,
      name: c.name,
      icon: c.icon,
      store_count: storeCountByCategory.get(c.category_id) || 0,
      product_count: productCountByCategory.get(c.category_id) || 0
    }));

    res.status(200).json({ success: true, categories: withCounts });
  } catch (error) {
    console.error('❌ Admin get categories error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching categories' });
  }
};

// ===========================
// 📌 GET /api/admin/delivery-groups  (كل رحلات التوصيل المجمّعة - Grouped Delivery)
// ===========================
const getDeliveryGroups = async (req, res) => {
  try {
    const groups = await DeliveryGroup.findAll({
      include: [
        { model: User, as: 'customer', attributes: ['user_id', 'full_name'] },
        { model: User, as: 'driver', attributes: ['user_id', 'full_name'] },
        {
          model: DeliveryGroupItem,
          as: 'items',
          include: [{ model: Order, as: 'order', include: [{ model: Restaurant, as: 'store' }] }]
        }
      ],
      order: [['created_at', 'DESC']]
    });

    const GROUP_FINISHED_STATUSES = ['Completed', 'Cancelled'];
    const formatted = await Promise.all(groups.map(async (g) => {
      const items = validSortedItems(g);

      const currentDriverId = g.driver_id || g.offered_driver_id;
      const backupDriver = currentDriverId && !GROUP_FINISHED_STATUSES.includes(g.status)
        ? await computeBackupDriver(buildScoringOrderInput(g), currentDriverId)
        : null;

      return {
        id: g.group_id.toString(),
        status: g.status,
        customer_name: g.customer ? g.customer.full_name : null,
        driver_name: g.driver ? g.driver.full_name : null,
        assignment_type: g.assignment_type,
        assignment_reason: g.assignment_reason,
        created_at: g.created_at,
        assigned_at: g.assigned_at,
        backup_driver: backupDriver,
        timeline: buildGroupTimeline(g),
        stores: items.map((i) => ({
          order_id: i.order.order_id.toString(),
          order_status: i.order.status,
          store_name: i.order.store ? i.order.store.name : null,
          pickup_sequence: i.pickup_sequence,
          matched_with_order_id: i.matched_with_order_id ? i.matched_with_order_id.toString() : null,
          store_distance_km: i.store_distance_km !== null ? parseFloat(i.store_distance_km) : null,
          delivery_distance_km: i.delivery_distance_km !== null ? parseFloat(i.delivery_distance_km) : null,
          time_difference_minutes: i.time_difference_minutes,
          rules_satisfied: i.rules_satisfied
        }))
      };
    }));

    res.status(200).json({ success: true, groups: formatted });
  } catch (error) {
    console.error('❌ Admin get delivery groups error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching delivery groups' });
  }
};

// ===========================
// 📌 GET /api/admin/settings  (إعدادات Grouped Delivery - صف وحيد id=1)
// PUT /api/admin/settings
// ===========================
const SETTINGS_NUMERIC_FIELDS = [
  'max_store_distance',
  'max_delivery_distance',
  'max_time_between_orders',
  'max_orders_per_group',
  'max_stores_per_trip',
  'minimum_driver_rating',
  'points_earn_rate',
  'points_redeem_rate'
];
const SETTINGS_BOOLEAN_FIELDS = ['grouped_delivery_enabled', 'auto_assign_driver', 'loyalty_enabled'];
const SETTINGS_UPDATABLE_FIELDS = [...SETTINGS_NUMERIC_FIELDS, ...SETTINGS_BOOLEAN_FIELDS];

// ✅ القيم الافتراضية جايين من services/grouping/config.js و
// services/loyalty/config.js (مصدر وحيد لكل - أول صف بينخلق بيها لو ما كان
// في صف أصلاً (findOrCreate)
const SETTINGS_DEFAULTS = {
  grouped_delivery_enabled: GROUPING_DEFAULTS.GROUPED_DELIVERY_ENABLED,
  max_store_distance: GROUPING_DEFAULTS.MAX_STORE_DISTANCE_KM,
  max_delivery_distance: GROUPING_DEFAULTS.MAX_DROPOFF_DISTANCE_KM,
  max_time_between_orders: GROUPING_DEFAULTS.MAX_GROUPING_WINDOW_MIN,
  max_orders_per_group: GROUPING_DEFAULTS.MAX_ORDERS_PER_GROUP,
  max_stores_per_trip: GROUPING_DEFAULTS.MAX_STORES_PER_TRIP,
  minimum_driver_rating: GROUPING_DEFAULTS.MINIMUM_DRIVER_RATING,
  auto_assign_driver: GROUPING_DEFAULTS.AUTO_ASSIGN_DRIVER,
  loyalty_enabled: LOYALTY_DEFAULTS.LOYALTY_ENABLED,
  points_earn_rate: LOYALTY_DEFAULTS.POINTS_EARN_RATE,
  points_redeem_rate: LOYALTY_DEFAULTS.POINTS_REDEEM_RATE
};

function validateSettingsPayload(body) {
  for (const field of SETTINGS_NUMERIC_FIELDS) {
    if (body[field] === undefined) continue;
    const value = Number(body[field]);
    if (Number.isNaN(value)) return `${field} must be a number`;
    if ((field === 'max_store_distance' || field === 'max_delivery_distance') && value < 0) {
      return `${field} cannot be negative`;
    }
    if (field === 'max_time_between_orders' && value <= 0) {
      return `${field} must be greater than 0`;
    }
    if ((field === 'max_orders_per_group' || field === 'max_stores_per_trip') && value < 2) {
      return `${field} must be at least 2`;
    }
    if (field === 'minimum_driver_rating' && (value < 0 || value > 5)) {
      return `${field} must be between 0 and 5`;
    }
    if ((field === 'points_earn_rate' || field === 'points_redeem_rate') && value < 0) {
      return `${field} cannot be negative`;
    }
  }
  for (const field of SETTINGS_BOOLEAN_FIELDS) {
    if (body[field] !== undefined && typeof body[field] !== 'boolean') {
      return `${field} must be true or false`;
    }
  }
  return null;
}

const getSystemSettings = async (req, res) => {
  try {
    const [settings] = await SystemSettings.findOrCreate({
      where: { id: 1 },
      defaults: SETTINGS_DEFAULTS
    });
    res.status(200).json({ success: true, settings });
  } catch (error) {
    console.error('❌ Admin get system settings error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching system settings' });
  }
};

const updateSystemSettings = async (req, res) => {
  try {
    const validationError = validateSettingsPayload(req.body);
    if (validationError) {
      return res.status(400).json({ success: false, message: validationError });
    }

    const [settings] = await SystemSettings.findOrCreate({
      where: { id: 1 },
      defaults: SETTINGS_DEFAULTS
    });

    const updates = {};
    for (const field of SETTINGS_UPDATABLE_FIELDS) {
      if (req.body[field] !== undefined) updates[field] = req.body[field];
    }
    await settings.update(updates);

    res.status(200).json({ success: true, message: 'Settings updated', settings });
  } catch (error) {
    console.error('❌ Admin update system settings error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating system settings' });
  }
};

// ===========================
// 📌 GET /api/admin/live-map  (خريطة تفاعلية حية - متاجر معتمدة + سائقين
// أونلاين + رحلات مجمّعة نشطة، توصية #2)
// ===========================
const getLiveMapData = async (req, res) => {
  try {
    const [stores, drivers, activeGroups] = await Promise.all([
      Restaurant.findAll({
        where: {
          approval_status: 'Approved',
          location_lat: { [Op.ne]: null },
          location_lng: { [Op.ne]: null }
        },
        include: [{ model: Category, as: 'category', attributes: ['category_id', 'name', 'icon'] }],
        attributes: ['restaurant_id', 'name', 'location_lat', 'location_lng', 'is_open']
      }),
      User.findAll({
        where: {
          role: 'Driver',
          // ✅ نفس باج NULL business_type - راجع getDrivers فوق
          [Op.or]: [{ business_type: { [Op.ne]: 'Fleet / Company' } }, { business_type: null }],
          is_active: true,
          status: 'Approved',
          current_lat: { [Op.ne]: null },
          current_lng: { [Op.ne]: null }
        },
        attributes: ['user_id', 'full_name', 'current_lat', 'current_lng', 'location_updated_at', 'business_type']
      }),
      DeliveryGroup.findAll({
        where: { status: { [Op.in]: ['Forming', 'Assigned'] } },
        include: [
          { model: User, as: 'driver', attributes: ['user_id', 'full_name', 'current_lat', 'current_lng'] },
          {
            model: DeliveryGroupItem,
            as: 'items',
            include: [{ model: Order, as: 'order', include: [{ model: Restaurant, as: 'store', attributes: ['restaurant_id', 'name', 'location_lat', 'location_lng'] }] }]
          }
        ]
      })
    ]);

    res.status(200).json({
      success: true,
      stores: stores.map((s) => ({
        id: s.restaurant_id.toString(),
        name: s.name,
        category: s.category ? s.category.name : null,
        icon: s.category ? s.category.icon : null,
        lat: parseFloat(s.location_lat),
        lng: parseFloat(s.location_lng),
        is_open: !!s.is_open
      })),
      drivers: drivers.map((d) => ({
        id: d.user_id.toString(),
        name: d.full_name,
        vehicle_type: d.business_type,
        status: getEffectiveStatus(d),
        lat: parseFloat(d.current_lat),
        lng: parseFloat(d.current_lng),
        location_updated_at: d.location_updated_at
      })),
      active_groups: activeGroups.map((g) => {
        const items = sortedItems(g);
        return {
          id: g.group_id.toString(),
          status: g.status,
          driver: g.driver && g.driver.current_lat != null && g.driver.current_lng != null ? {
            id: g.driver.user_id.toString(),
            name: g.driver.full_name,
            lat: parseFloat(g.driver.current_lat),
            lng: parseFloat(g.driver.current_lng)
          } : null,
          stops: items
            .filter((i) => i.order && i.order.store && i.order.store.location_lat != null)
            .map((i) => ({
              order_id: i.order.order_id.toString(),
              store_name: i.order.store.name,
              lat: parseFloat(i.order.store.location_lat),
              lng: parseFloat(i.order.store.location_lng),
              pickup_sequence: i.pickup_sequence
            }))
        };
      })
    });
  } catch (error) {
    console.error('❌ Admin get live map data error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching live map data' });
  }
};

// ===========================
// 📌 POST /api/admin/simulate-grouping  (Delivery Simulation - يجرب سيناريو
// افتراضي ويرجع هل كانت رح تنجمع، بنفس الإعدادات الحية الحالية، توصية #6)
// ===========================
const simulateGrouping = async (req, res) => {
  try {
    const { store_a, store_b, customer_a, customer_b, time_difference_minutes } = req.body;
    const coordsValid = (p) => p && typeof p.lat === 'number' && typeof p.lng === 'number';

    if (!coordsValid(store_a) || !coordsValid(store_b) || !coordsValid(customer_a)) {
      return res.status(400).json({
        success: false,
        message: 'store_a, store_b and customer_a must each include numeric lat/lng'
      });
    }
    // ✅ customer_b اختياري - لو ما انبعت، بنفترض نفس عنوان التوصيل (السيناريو
    // الشائع: نفس الزبون بنفس الطلبين). لو انبعت، بيسمح نجرب زبونين مختلفين
    // بنفس الشرط الأساسي (مسافة التوصيل) بدون افتراض عنوان مشترك.
    const dropoffB = coordsValid(customer_b) ? customer_b : customer_a;

    const timeDifferenceMinutes = Number(time_difference_minutes);
    if (Number.isNaN(timeDifferenceMinutes) || timeDifferenceMinutes < 0) {
      return res.status(400).json({ success: false, message: 'time_difference_minutes must be a non-negative number' });
    }

    const settings = await getLiveGroupingSettings();
    const storeDistanceKm = haversineKm(store_a.lat, store_a.lng, store_b.lat, store_b.lng);
    const dropoffDistanceKm = haversineKm(customer_a.lat, customer_a.lng, dropoffB.lat, dropoffB.lng);

    const result = evaluateGroupingMatch({ storeDistanceKm, dropoffDistanceKm, timeDifferenceMinutes }, settings);

    res.status(200).json({
      success: true,
      simulation: {
        store_distance_km: storeDistanceKm !== null ? Math.round(storeDistanceKm * 1000) / 1000 : null,
        delivery_distance_km: dropoffDistanceKm !== null ? Math.round(dropoffDistanceKm * 1000) / 1000 : null,
        time_difference_minutes: timeDifferenceMinutes,
        rules_satisfied: result.rulesSatisfied,
        rules_failed: result.rulesFailed,
        thresholds: result.thresholds,
        will_group: result.matched
      }
    });
  } catch (error) {
    console.error('❌ Admin simulate grouping error:', error);
    res.status(500).json({ success: false, message: 'Server error while simulating grouping' });
  }
};

// ===========================
// 📌 GET /api/admin/drivers/:id/performance  (تحليلات أداء سائق معيّن)
// ===========================
const getDriverPerformance = async (req, res) => {
  try {
    const driver = await User.findOne({ where: { user_id: req.params.id, role: 'Driver' } });
    if (!driver) {
      return res.status(404).json({ success: false, message: 'Driver not found' });
    }
    const performance = await computeDriverPerformance(driver.user_id);
    res.status(200).json({ success: true, driver: { id: driver.user_id.toString(), full_name: driver.full_name }, performance });
  } catch (error) {
    console.error('❌ Admin get driver performance error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching driver performance' });
  }
};

// ===========================
// 📌 GET /api/admin/stores/:id/analytics  (تحليلات متجر معيّن)
// ===========================
const getStoreAnalytics = async (req, res) => {
  try {
    const store = await Restaurant.findByPk(req.params.id);
    if (!store) {
      return res.status(404).json({ success: false, message: 'Store not found' });
    }
    const analytics = await computeStoreAnalytics(store.restaurant_id);
    res.status(200).json({ success: true, store: { id: store.restaurant_id.toString(), name: store.name }, analytics });
  } catch (error) {
    console.error('❌ Admin get store analytics error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching store analytics' });
  }
};

// ===========================
// 📌 GET /api/admin/analytics?days=14  (لوحة التحليلات الرئيسية: طلبات
// يومية، إيرادات، أنشط المتاجر، أفضل السائقين، نجاح التعيين الذكي، نسبة التجميع)
// ===========================
const getAnalyticsDashboard = async (req, res) => {
  try {
    const days = req.query.days ? parseInt(req.query.days, 10) : 14;
    const analytics = await computeAdminAnalytics({ days: Number.isFinite(days) && days > 0 ? days : 14 });
    res.status(200).json({ success: true, analytics });
  } catch (error) {
    console.error('❌ Admin get analytics dashboard error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching analytics dashboard' });
  }
};

module.exports = {
  getDashboardStats,
  getStores,
  approveStore,
  rejectStore,
  toggleFeaturedStore,
  deleteStore,
  getDeliveryCompanies,
  approveCompany,
  rejectCompany,
  getAllCoupons,
  getOrders,
  getOrderDetail,
  getUsers,
  updateUserStatus,
  getDrivers,
  getCategories,
  getDeliveryGroups,
  getSystemSettings,
  updateSystemSettings,
  getLiveMapData,
  simulateGrouping,
  getDriverPerformance,
  getStoreAnalytics,
  getAnalyticsDashboard
};
