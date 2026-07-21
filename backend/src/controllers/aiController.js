// src/controllers/aiController.js
const { sendMessage: sendAiMessage } = require('../services/ai/aiChatService');
const { getFormattedHistory, clearHistory } = require('../services/ai/aiChatHistoryService');

// ===========================
// 📌 POST /api/ai/message  { message, locale }
// ===========================
const sendMessage = async (req, res) => {
  const httpStartedAt = Date.now();
  try {
    const { message, locale } = req.body;
    const result = await sendAiMessage(req.user, message, locale || 'en');
    res.status(200).json({ success: true, reply: result.reply });
    console.log(`📬 [HTTP] Response sent 200 (+${Date.now() - httpStartedAt}ms total)`);
  } catch (error) {
    if (error.status === 400) {
      return res.status(400).json({ success: false, message: error.message });
    }
    // ✅ تحقيق إنتاج: هون بالضبط كان الخطأ الحقيقي (429 RESOURCE_EXHAUSTED
    // من Gemini بمعظم الحالات المرصودة) بينلبّس رسالة عامة واحدة بدون أي
    // أثر لسببه الحقيقي بالسجل - نسجّل status/name/message الحقيقيين هون
    // بوضوح (بدون ما نسرّبهم للعميل - نفس فلسفة الـ global error handler
    // بـ app.js). الآن geminiClient.js بيعيد المحاولة تلقائيًا لأي خطأ
    // retryable (429/5xx/شبكة) قبل ما يوصل هون أصلاً - لو وصلنا هون فعليًا
    // يعني استنفذنا كل المحاولات، وهاد استثنائي حقًا مش السلوك الطبيعي.
    console.error(
      `❌ [HTTP] AI sendMessage failed (+${Date.now() - httpStartedAt}ms) status=${error.status} name=${error.name}:`,
      error.message || error
    );
    res.status(503).json({ success: false, message: 'AI assistant is temporarily unavailable. Please try again shortly.' });
  }
};

// ===========================
// 📌 GET /api/ai/history
// ===========================
const getHistory = async (req, res) => {
  try {
    const messages = await getFormattedHistory(req.user.user_id);
    res.status(200).json({ success: true, messages });
  } catch (error) {
    console.error('❌ AI getHistory error:', error);
    res.status(500).json({ success: false, message: 'Server error while fetching chat history' });
  }
};

// ===========================
// 📌 DELETE /api/ai/history
// ===========================
const deleteHistory = async (req, res) => {
  try {
    await clearHistory(req.user.user_id);
    res.status(200).json({ success: true, message: 'Chat history cleared' });
  } catch (error) {
    console.error('❌ AI deleteHistory error:', error);
    res.status(500).json({ success: false, message: 'Server error while clearing chat history' });
  }
};

module.exports = { sendMessage, getHistory, deleteHistory };
