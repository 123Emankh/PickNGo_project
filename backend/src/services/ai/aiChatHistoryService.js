// src/services/ai/aiChatHistoryService.js
//
// المساعد الذكي: كل التعامل مع جدول ai_chat_messages - نفس أسلوب باقي
// services/analytics (دوال عادية بترجع بيانات جاهزة، بدون لمس req/res).
const { AiChatMessage } = require('../../models');

const DEFAULT_HISTORY_LIMIT = 20;

function toGeminiContent(message) {
  return { role: message.role, parts: [{ text: message.content }] };
}

/**
 * آخر N رسالة لمستخدم، بترتيب زمني تصاعدي (الأقدم أولًا) - الشكل يلي
 * Gemini بيتوقعه بحقل contents.
 */
async function getRecentHistory(userId, limit = DEFAULT_HISTORY_LIMIT) {
  const rows = await AiChatMessage.findAll({
    where: { user_id: userId },
    attributes: ['role', 'content'],
    order: [['created_at', 'DESC']],
    limit
  });
  return rows.reverse().map(toGeminiContent);
}

async function getFormattedHistory(userId, limit = 50) {
  const rows = await AiChatMessage.findAll({
    where: { user_id: userId },
    attributes: ['id', 'role', 'content', 'created_at'],
    order: [['created_at', 'ASC']],
    limit
  });
  return rows.map((r) => ({ id: r.id, role: r.role, content: r.content, created_at: r.created_at }));
}

async function appendMessage(userId, role, content, metadata = null) {
  return AiChatMessage.create({ user_id: userId, role, content, metadata });
}

async function clearHistory(userId) {
  await AiChatMessage.destroy({ where: { user_id: userId } });
}

module.exports = { getRecentHistory, getFormattedHistory, appendMessage, clearHistory };
