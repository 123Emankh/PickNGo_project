// src/services/ai/aiChatService.js
//
// المساعد الذكي: نقطة الدخول الوحيدة يلي aiController.js بينادي عليها.
// بتجمع كل القطع التانية (history/tools/prompt/cache/gemini) بخطوة واحدة،
// نفس نمط orchestration بالخدمات التانية (مثلًا couponService/loyaltyService
// اللي orderController بينادي عليها كنقطة وحيدة بدل ما يعرف تفاصيلها).
const { runConversation } = require('./geminiClient');
const { getToolsForRole } = require('./aiTools');
const { buildSystemPrompt } = require('./systemPrompts');
const { getRecentHistory, appendMessage } = require('./aiChatHistoryService');
const aiCache = require('./aiCache');

const MAX_MESSAGE_LENGTH = 1000;

let requestCounter = 0;
function nextRequestId() {
  requestCounter = (requestCounter + 1) % 1_000_000;
  return `ai-${Date.now().toString(36)}-${requestCounter}`;
}

/**
 * ✅ تحقيق إنتاج (Production investigation) - راجع تعليق geminiClient.js
 * للسبب الجذري. هاي السجلات المرحلية (Request received/AI started/AI
 * finished/Response sent) مطلوبة بالتحقيق لتتبّع أي طلب فردي بدقة عبر كل
 * مرحلة، بمعرّف request موحّد (rid) - أهم من مجرد "حصل خطأ" هو "بأي مرحلة
 * بالضبط، وبعد كم مللي ثانية".
 */
async function sendMessage(user, rawMessage, locale = 'en') {
  const rid = nextRequestId();
  const startedAt = Date.now();
  const elapsed = () => Date.now() - startedAt;

  console.log(`📥 [${rid}] Request received - user_id=${user.user_id} role=${user.role} locale=${locale}`);

  const message = String(rawMessage || '').trim().slice(0, MAX_MESSAGE_LENGTH);
  if (!message) {
    throw Object.assign(new Error('Message is required'), { status: 400 });
  }

  if (aiCache.isCacheableRole(user.role)) {
    const cached = aiCache.get(user.user_id, message);
    if (cached) {
      console.log(`⚡ [${rid}] Served from cache (+${elapsed()}ms)`);
      return { reply: cached, cached: true };
    }
  }

  const history = await getRecentHistory(user.user_id);
  const { declarations, handlers } = getToolsForRole(user.role, user);
  const systemPrompt = buildSystemPrompt(user.role, locale);

  console.log(`🚀 [${rid}] AI started - history=${history.length} msgs, tools=${declarations.length} (+${elapsed()}ms)`);
  const { replyText, toolsUsed, exceededMaxRounds } = await runConversation({
    systemPrompt,
    history,
    message,
    toolDeclarations: declarations,
    toolHandlers: handlers
  });
  console.log(`🏁 [${rid}] AI finished - tools_used=[${toolsUsed.join(',')}] exceededMaxRounds=${!!exceededMaxRounds} (+${elapsed()}ms)`);

  const reply = exceededMaxRounds || !replyText
    ? "Sorry, I couldn't process that right now. Could you rephrase your question?"
    : replyText;

  await appendMessage(user.user_id, 'user', message);
  await appendMessage(user.user_id, 'model', reply, toolsUsed.length ? { tools_used: toolsUsed } : null);

  if (aiCache.isCacheableRole(user.role) && !exceededMaxRounds) {
    aiCache.set(user.user_id, message, reply);
  }

  console.log(`📤 [${rid}] Response ready (+${elapsed()}ms)`);
  return { reply, cached: false };
}

module.exports = { sendMessage };
