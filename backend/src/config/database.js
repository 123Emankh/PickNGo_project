// src/config/database.js
const { Sequelize } = require('sequelize');
require('dotenv').config();

const sequelize = new Sequelize(
  process.env.DB_NAME,
  process.env.DB_USER,
  process.env.DB_PASS,
  {
    host: process.env.DB_HOST,
    dialect: 'mysql',
    port: process.env.DB_PORT || 3306,
    
    pool: {
      max: 10,
      min: 2,
      acquire: 30000,
      idle: 10000,
      evict: 5000
    },
    
    retry: {
      max: 3,
      timeout: 3000
    },
    
    logging: false,
    timezone: '+02:00',
    
    dialectOptions: {
      connectTimeout: 60000
    }
  }
);

const testConnection = async () => {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connection established successfully.');
  } catch (error) {
    console.error('❌ Unable to connect to database:', error.message);
    console.log('🔄 Retrying in 5 seconds...');
    setTimeout(testConnection, 5000);
  }
};

setInterval(async () => {
  try {
    await sequelize.query('SELECT 1');
  } catch (err) {
    console.error('⚠️ Database keep-alive failed:', err.message);
  }
}, 60000);

module.exports = sequelize;