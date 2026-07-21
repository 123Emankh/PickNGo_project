// src/services/analytics/storeAnalyticsService.js
//
// تحليلات متجر - كلها مبنية من orders/order_items الموجودة أصلًا، بدون أي
// جدول جديد. استعلامان اثنان بس (طلبات المتجر + عناصر الطلبات الصالحة).
const { Order, OrderItem, Product, sequelize } = require('../../models');

function round2(n) {
  return Math.round(n * 100) / 100;
}

async function computeStoreAnalytics(restaurantId) {
  const orders = await Order.findAll({
    where: { restaurant_id: restaurantId },
    attributes: ['order_id', 'customer_id', 'status', 'final_amount', 'order_time']
  });

  const totalOrders = orders.length;
  const cancelledOrders = orders.filter((o) => o.status === 'Cancelled').length;
  const validOrders = orders.filter((o) => o.status !== 'Cancelled');

  // ✅ متوسط قيمة الطلب: على الطلبات الصالحة (غير الملغاة) - طلب ملغي ما بيمثّل
  // قيمة فعلية استلمها المتجر
  const avgOrderValue = validOrders.length
    ? round2(validOrders.reduce((sum, o) => sum + parseFloat(o.final_amount), 0) / validOrders.length)
    : null;

  // ✅ ساعات الذروة: توزيع كل الطلبات (بما فيها الملغاة - بتعكس وقت اهتمام
  // الزبائن بالمتجر بغض النظر عن مصير الطلب) على 24 ساعة، أعلى 5 ساعات
  const hourCounts = new Array(24).fill(0);
  for (const o of orders) hourCounts[new Date(o.order_time).getHours()] += 1;
  const peakHours = hourCounts
    .map((count, hour) => ({ hour, count }))
    .filter((h) => h.count > 0)
    .sort((a, b) => b.count - a.count)
    .slice(0, 5);

  // ✅ عملاء متكررون: عميل طلب أكتر من مرة وحدة من هاد المتجر
  const customerOrderCounts = new Map();
  for (const o of orders) {
    customerOrderCounts.set(o.customer_id, (customerOrderCounts.get(o.customer_id) || 0) + 1);
  }
  const uniqueCustomers = customerOrderCounts.size;
  const repeatCustomers = [...customerOrderCounts.values()].filter((c) => c > 1).length;

  // ✅ أكثر المنتجات مبيعًا: كمية/إيراد مجمّع من order_items للطلبات الصالحة بس
  const validOrderIds = validOrders.map((o) => o.order_id);
  const topProductsRaw = validOrderIds.length
    ? await OrderItem.findAll({
        where: { order_id: validOrderIds },
        attributes: [
          'product_id',
          [sequelize.fn('SUM', sequelize.col('OrderItem.quantity')), 'total_qty'],
          [sequelize.fn('SUM', sequelize.col('OrderItem.subtotal')), 'total_revenue']
        ],
        include: [{ model: Product, as: 'product', attributes: ['name'] }],
        group: ['product_id', 'product.product_id'],
        order: [[sequelize.literal('total_qty'), 'DESC']],
        limit: 10
      })
    : [];

  return {
    total_orders: totalOrders,
    cancelled_orders: cancelledOrders,
    cancellation_rate: totalOrders ? round2(cancelledOrders / totalOrders) : null,
    avg_order_value: avgOrderValue,
    unique_customers: uniqueCustomers,
    repeat_customers: repeatCustomers,
    repeat_customer_rate: uniqueCustomers ? round2(repeatCustomers / uniqueCustomers) : null,
    peak_hours: peakHours,
    top_products: topProductsRaw.map((r) => ({
      product_id: r.product_id.toString(),
      name: r.product ? r.product.name : '',
      total_quantity: parseInt(r.get('total_qty'), 10),
      total_revenue: parseFloat(r.get('total_revenue'))
    }))
  };
}

module.exports = { computeStoreAnalytics };
