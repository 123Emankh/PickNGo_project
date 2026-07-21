// src/app.js
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');
const { generalLimiter } = require('./middleware/rateLimit');

dotenv.config();

const app = express();

// ===========================
// 📌 Middlewares
// ===========================
// ✅ رؤوس أمان أساسية (HSTS, X-Content-Type-Options, hidePoweredBy إلخ) - ما
// كانت موجودة إطلاقًا سابقًا. crossOriginResourcePolicy مفكوك لأن /uploads
// (صور المنتجات/الأفاتار) لازم تنعرض من أصل تاني (تطبيق الموبايل/لوحة الويب).
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
// ✅ نداء cors() واحد كافٍ ومصدر الحقيقة الوحيد لرؤوس CORS - كان في نسخة
// يدوية مكرّرة تحته بالضبط (نفس الرؤوس تمامًا) بلا أي داعي. الـ API هون
// Bearer-token (JWT بالـ Authorization header، مش كوكيز)، فمافي خطر CSRF
// حقيقي من فتحها؛ تقييدها لأصل محدد يحتاج معرفة نطاق الإنتاج الفعلي (غير
// معروف بهاد المرحلة) - محجوز كخطوة تالية وقت الـ deployment الحقيقي.
app.use(cors());
// ✅ سقف عام لمعدل الطلبات على كل /api - لم يكن موجودًا إطلاقًا سابقًا
app.use('/api', generalLimiter);
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));

// ===========================
// 📌 Create required directories
// ===========================
const requiredDirs = ['uploads', 'uploads/profiles'];
requiredDirs.forEach(dir => {
  const dirPath = path.join(__dirname, dir);
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
    console.log(`📁 Created directory: ${dir}`);
  }
});

// ===========================
// 📌 Static files
// ===========================
app.use('/uploads', express.static(path.join(__dirname, 'uploads'), {
  maxAge: '1d'
}));

// ===========================
// 📌 Routes
// ===========================
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/stores', require('./routes/storeRoutes'));
app.use('/api/orders', require('./routes/orderRoutes'));
app.use('/api/admin', require('./routes/adminRoutes'));
app.use('/api/payments', require('./routes/paymentRoutes'));
app.use('/api/company', require('./routes/companyRoutes'));
app.use('/api/reviews', require('./routes/reviewRoutes'));
app.use('/api/coupons', require('./routes/couponRoutes'));
app.use('/api/favorites', require('./routes/favoriteRoutes'));
app.use('/api/drivers', require('./routes/driverRoutes'));
app.use('/api/notifications', require('./routes/notificationRoutes'));
app.use('/api/recommendations', require('./routes/recommendationRoutes'));
app.use('/api/loyalty', require('./routes/loyaltyRoutes'));
app.use('/api/ai', require('./routes/aiRoutes'));

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Test route
app.get('/test', (req, res) => {
  res.json({ message: 'Server is running!' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route ${req.url} not found`
  });
});

// Global error handler
// ✅ رسالة الخطأ الداخلية (تفاصيل Sequelize/DB إلخ) كانت تترسل للعميل مباشرة
// بلا أي فحص NODE_ENV - تسريب معلومات داخلية حقيقي بالإنتاج. هلق: بالتطوير
// منرجّع نفس التفصيل (مفيد وقت الـ debugging)، وبالإنتاج رسالة عامة بس -
// التفاصيل الكاملة تضل تُسجَّل بالسيرفر (console.error) بكل الأحوال.
app.use((err, req, res, next) => {
  console.error('❌ Global error:', err);
  const isProd = process.env.NODE_ENV === 'production';
  res.status(err.status || 500).json({
    success: false,
    message: isProd ? 'Internal server error' : (err.message || 'Internal server error')
  });
});

module.exports = app;