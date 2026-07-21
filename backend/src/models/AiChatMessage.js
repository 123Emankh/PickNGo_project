// src/models/AiChatMessage.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

// ✅ المساعد الذكي (Gemini): سجل رسائل محادثة مسطّح لكل مستخدم - راجع
// migrations/20260719000001-create-ai-chat-messages.js لتفاصيل القرار.
const AiChatMessage = sequelize.define('AiChatMessage', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  user_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: 'users', key: 'user_id' }
  },
  role: {
    type: DataTypes.ENUM('user', 'model'),
    allowNull: false
  },
  content: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  metadata: {
    // ✅ مثلاً { tools_used: ['get_order_status'] } - تشخيص فقط، ما بيوصل للمستخدم
    type: DataTypes.JSON,
    allowNull: true
  }
}, {
  tableName: 'ai_chat_messages',
  timestamps: true,
  createdAt: 'created_at',
  updatedAt: 'updated_at'
});

module.exports = AiChatMessage;
