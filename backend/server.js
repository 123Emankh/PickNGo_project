// src/server.js
const app = require('./src/app');
const sequelize = require('./src/config/database');
const { cleanExpiredOTPs } = require('./src/services/otpService');
require('dotenv').config();

const PORT = process.env.PORT || 5000;

setInterval(async () => {
  try {
    const count = await cleanExpiredOTPs();
    if (count > 0) {
      console.log(`🧹 Cleaned ${count} expired OTPs`);
    }
  } catch (error) {
    console.error('❌ Error cleaning OTPs:', error);
  }
}, 60 * 60 * 1000);

const startServer = async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connection established successfully.');

    await sequelize.sync({ alter: process.env.NODE_ENV === 'development' });
    console.log('✅ Models synchronized with database.');

    app.listen(PORT, () => {
      console.log(`🚀 Server running on http://localhost:${PORT}`);
      console.log(`📧 Email service: ${process.env.SMTP_USER ? 'Configured' : 'Not configured'}`);
      console.log(`🔐 JWT: ${process.env.JWT_SECRET ? 'Configured' : '⚠️ Missing!'}`);
      console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('📋 API Endpoints:');
      console.log(`   POST   /api/auth/signup          - Initial signup (send OTP)`);
      console.log(`   POST   /api/auth/verify-signup   - Verify OTP and complete signup`);
      console.log(`   POST   /api/auth/resend-otp      - Resend OTP`);
      console.log(`   POST   /api/auth/login           - Login`);
      console.log(`   POST   /api/auth/forgot-password - Request password reset`);
      console.log(`   POST   /api/auth/reset-password  - Reset password with OTP`);
      console.log(`   POST   /api/auth/verify-otp      - Verify OTP only`);
      console.log(`   POST   /api/auth/logout          - Logout (protected)`);
      console.log(`   GET    /api/auth/profile         - Get user profile (protected)`);
      console.log(`   PUT    /api/auth/profile         - Update profile (protected)`);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    });

  } catch (error) {
    console.error('❌ Failed to start server:', error.message);
    console.log('🔄 Retrying in 5 seconds...');
    setTimeout(startServer, 5000);
  }
};

process.on('uncaughtException', (error) => {
  console.error('💥 Uncaught exception:', error);
});

process.on('unhandledRejection', (reason) => {
  console.error('💥 Unhandled rejection:', reason);
});

startServer();