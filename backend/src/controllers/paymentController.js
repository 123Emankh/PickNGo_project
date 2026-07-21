// src/controllers/paymentController.js
const { Order } = require('../models');
const { getIo } = require('../sockets');
const hyperpayService = require('../services/hyperpayService');

const CARD_METHODS = ['CreditCard', 'DebitCard'];

// ===========================
// 📌 POST /api/payments/checkout  (إنشاء جلسة دفع HyperPay لطلب موجود - Customer فقط)
// ===========================
const createCheckoutSession = async (req, res) => {
  try {
    const { order_id } = req.body;
    const order = await Order.findByPk(order_id);

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }
    if (order.customer_id !== req.user.user_id) {
      return res.status(403).json({ success: false, message: 'This order does not belong to you' });
    }
    if (!CARD_METHODS.includes(order.payment_method)) {
      return res.status(400).json({ success: false, message: 'This order is not set up for card payment' });
    }
    if (order.payment_status !== 'Pending') {
      return res.status(400).json({ success: false, message: `Payment already ${order.payment_status}` });
    }

    const { checkoutId } = await hyperpayService.createCheckout({
      amount: order.final_amount,
      currency: process.env.HYPERPAY_CURRENCY
    });

    order.payment_checkout_id = checkoutId;
    await order.save();

    res.status(200).json({
      success: true,
      checkoutId,
      widgetUrl: `${req.protocol}://${req.get('host')}/api/payments/widget/${checkoutId}`
    });
  } catch (error) {
    console.error('❌ Create checkout session error:', error);
    res.status(502).json({ success: false, message: 'Could not start card payment. Please try again.' });
  }
};

// ===========================
// 📌 GET /api/payments/widget/:checkoutId  (صفحة Copy&Pay - عامة، بتفتح جوا WebView بدون JWT)
// ===========================
const renderWidgetPage = async (req, res) => {
  try {
    const { checkoutId } = req.params;
    // ✅ منجيب order_id من قاعدة البيانات (مش من query الطالب) عشان يضل مصدر موثوق
    const order = await Order.findOne({ where: { payment_checkout_id: checkoutId } });

    if (!order) {
      return res.status(404).send('<h3>Checkout session not found</h3>');
    }

    const returnUrl = `${req.protocol}://${req.get('host')}/api/payments/return?order_id=${order.order_id}`;

    res.type('html').send(`<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script src="${process.env.HYPERPAY_BASE_URL}/v1/paymentWidgets.js?checkoutId=${checkoutId}"></script>
</head>
<body style="font-family: sans-serif; padding: 16px;">
  <form action="${returnUrl}" class="paymentWidgets" data-brands="VISA MASTER"></form>
</body>
</html>`);
  } catch (error) {
    console.error('❌ Render widget page error:', error);
    res.status(500).send('<h3>Server error</h3>');
  }
};

// ===========================
// 📌 GET /api/payments/return  (نقطة رجوع الويدجت - عامة، مجرد إشارة تنقّل - ما بتعدّل payment_status إطلاقًا)
// ===========================
// ⚠️ لا تضيفي هون أي تحديث لـ payment_status حتى لو بدا "مريح" - هاد بالضبط الثغرة يلي التصميم
// مبني لتفاديها (تصديق redirect العميل بدل التحقق الحقيقي من السيرفر). التحقق الوحيد الموثوق
// هو verifyAndGetStatus تحت.
const handleReturn = async (req, res) => {
  res.type('html').send(`<!doctype html>
<html><body style="font-family: sans-serif; padding: 16px; text-align: center;">
  <p>جاري التحقق من الدفع... يمكنك إغلاق هذه الصفحة.</p>
</body></html>`);
};

// ===========================
// 📌 GET /api/payments/status/:orderId  (التحقق الحقيقي من نتيجة الدفع - Customer فقط، idempotent)
// ===========================
const verifyAndGetStatus = async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.orderId);
    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }
    if (order.customer_id !== req.user.user_id) {
      return res.status(403).json({ success: false, message: 'This order does not belong to you' });
    }
    if (!order.payment_checkout_id) {
      return res.status(400).json({ success: false, message: 'No payment session was started for this order' });
    }

    // idempotent: لو الحالة انحسمت أصلاً، منرجعها كما هي بدون ما نعيد نداء HyperPay
    if (order.payment_status !== 'Pending') {
      return res.status(200).json({ success: true, payment_status: order.payment_status });
    }

    const result = await hyperpayService.getPaymentStatus(order.payment_checkout_id);
    const status = hyperpayService.classifyResultCode(result?.result?.code || '');

    order.payment_status = status;
    if (status === 'Paid') {
      order.payment_id = result.id;
    }
    await order.save();

    const io = getIo();
    if (io) {
      io.to(`order:${order.order_id}`).emit('order:status', {
        order_id: order.order_id,
        status: order.status,
        payment_status: order.payment_status
      });
    }

    res.status(200).json({ success: true, payment_status: order.payment_status });
  } catch (error) {
    console.error('❌ Verify payment status error:', error);
    res.status(502).json({ success: false, message: 'Could not verify payment status. Please try again.' });
  }
};

module.exports = {
  createCheckoutSession,
  renderWidgetPage,
  handleReturn,
  verifyAndGetStatus
};
