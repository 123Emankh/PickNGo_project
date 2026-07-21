// src/config/config.js
//
// إعدادات الاتصال بقاعدة البيانات لأداة sequelize-cli (migrations/seeders).
// نفس مصدر الحقيقة المستخدم بـ src/config/database.js، بس بالشكل اللي
// sequelize-cli متوقعه (module.exports مباشر لكل بيئة).
require('dotenv').config();

const base = {
  username: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 3306,
  dialect: 'mysql',
  timezone: '+02:00',
};

module.exports = {
  development: base,
  test: base,
  production: base,
};
