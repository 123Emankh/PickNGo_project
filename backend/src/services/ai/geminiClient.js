// src/services/ai/geminiClient.js
//
// المساعد الذكي: يعزل كل التعامل المباشر مع Gemini API عن باقي الخدمات -
// نفس فكرة hyperpayService.js. بخلاف hyperpayService (fetch مباشر)، هون
// مستخدمين حزمة @google/genai الرسمية لأن بروتوكول Function Calling
// متعدد الأدوار (تعيين نموذج → تنفيذ tool → رجوع نتيجة → تعيين تالي) معقّد
// كفاية إنه إعادة كتابته يدويًا فوق fetch خطر وسهل الكسر مقابل فايدة قليلة.
//
// ✅ كل شكل حقل/دالة هون (functionCall.id/name/args، FunctionResponse.id/
// name/response، Tool.functionDeclarations، createModelContent/
// createUserContent/createPartFromFunctionResponse، response.text/
// response.functionCalls، GenerateContentConfig.automaticFunctionCalling)
// مُتحقّق منه فعليًا مقابل @google/genai@1.52.0 المثبتة فعليًا بالمشروع
// (node_modules/@google/genai/dist/genai.d.ts) - مش من معرفة عامة، بخلاف
// hyperpayService.js يلي لسا محتاج تأكيد حي.
//
// ⚠️ تحقيق إنتاج (Production investigation): المستخدمين كانوا بشوفوا
// "AI assistant is temporarily unavailable" بشكل متكرر وبينحل بمجرد إعادة
// المحاولة يدويًا. السبب الحقيقي المؤكد من السجلات الفعلية: Gemini free
// tier بيرمي 429 RESOURCE_EXHAUSTED (quota per-minute ضيق جدًا - شفناها
// فعليًا بالسجل: "Please retry in 4.7s") - وكل رسالة مستخدم واحدة ممكن
// تستهلك عدة نداءات Gemini حقيقية (كل جولة tool-calling = نداء)، فبسهولة
// بتتجاوز الحصة بمحادثة وحدة عادية. الحل الجذري: إعادة محاولة تلقائية
// بالباك إند (exponential backoff) لأي خطأ retryable - المستخدم ما لازم
// يعمل "retry" يدوي إطلاقًا لخطأ مؤقت بيتصلح لحاله بعد كم ثانية.
require('dotenv').config();
const { GoogleGenAI, createModelContent, createUserContent, createPartFromFunctionResponse } = require('@google/genai');

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
// ✅ 'gemini-flash-latest' هو alias بيحافظ عليه Google نفسه ليأشر دايمًا
// لآخر جيل Flash مستقر - تفضيله على اسم إصدار ثابت (زي 'gemini-2.5-flash')
// مقصود: جرّبنا فعليًا وقت الفحص إنه Google بيوقف دعم إصدارات قديمة للمفاتيح
// الجديدة بدون سابق إنذار (رجع 404 "no longer available to new users") -
// الـ alias هو الدفاع الوحيد ضد هاد النوع من الكسر المستقبلي بدون تدخل كود.
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-flash-latest';
const MAX_TOOL_ROUNDS = 5; // سقف أمان يمنع حلقة استدعاء أدوات بلا نهاية

// ✅ إعادة المحاولة التلقائية - راجع تعليق التحقيق فوق. 3 محاولات كافية
// لتغطية نافذة الـ per-minute quota (بتصفّر خلال ثواني قليلة حسب الأخطاء
// الفعلية المرصودة)، مع exponential backoff + jitter بسيط لتجنب thundering
// herd لو أكتر من مستخدم ضرب نفس الحصة بنفس اللحظة.
const MAX_API_RETRIES = 3;
const RETRY_BASE_DELAY_MS = 900;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * ⚠️ اكتشاف مهم من stress test حقيقي بـ 50 رسالة متتالية: 429
 * RESOURCE_EXHAUSTED مش نوع واحد دايمًا. جسم خطأ Gemini بيحدد quotaId
 * صريح داخل details[].violations[] - وفيه فرق جوهري بين:
 *   - "GenerateRequestsPerMinutePerProjectPerModel-FreeTier" (شفناها
 *     بالتحقيق الأول، quotaValue:5) - نافذة بتصفّر بثواني، إعادة المحاولة
 *     القريبة منطقية وفعليًا بتنجح (هاد سبب مشكلة "برجر" الأصلية).
 *   - "GenerateRequestsPerDayPerProjectPerModel-FreeTier" (شفناها هلق
 *     بـ stress test، quotaValue:20) - سقف يومي كامل. إعادة محاولة بثواني
 *     مستحيل تنجح إطلاقًا لحد ما اليوم يتبدّل عند Google - وبالتالي كل
 *     إعادة محاولة هون مجرد إهدار وقت (٦-٨ ثواني انتظار المستخدم لغاية
 *     الفشل النهائي) بدون أي فايدة.
 * الحل: نفحص quotaId الحقيقي من جسم الخطأ - لو "PerDay" منفشل فورًا
 * (retryable=false) بدل ما نستنزف وقت/محاولات على شي مستحيل ينجح.
 */
function isDailyQuotaExhausted(error) {
  const message = error && error.message;
  return typeof message === 'string' && message.includes('PerDay') && message.includes('RESOURCE_EXHAUSTED');
}

/**
 * أخطاء "مؤقتة" فعليًا يستحق يُعاد المحاولة عليها: 429 (rate limit/quota -
 * ما عدا السقف اليومي، راجع isDailyQuotaExhausted فوق)، 500/502/503/504
 * (مشاكل خدمة مؤقتة من طرف Google)، أو خطأ شبكة بدون status أصلاً (فشل
 * الاتصال قبل ما يوصل رد HTTP). أي إشي تاني (401/403 مفتاح غلط، 400 طلب
 * غلط بنيويًا) ما بيستفيد من إعادة المحاولة - بيفشل بنفس الشكل كل مرة.
 */
function isRetryableApiError(error) {
  if (isDailyQuotaExhausted(error)) return false;
  const status = error && error.status;
  if (status === 429) return true;
  if (typeof status === 'number' && status >= 500) return true;
  if (!status) return true; // خطأ شبكة/timeout قبل الحصول على رد HTTP أصلاً
  return false;
}

async function generateContentWithRetry(ai, params, label) {
  let lastError;
  for (let attempt = 0; attempt <= MAX_API_RETRIES; attempt++) {
    const attemptStartedAt = Date.now();
    try {
      const response = await ai.models.generateContent(params);
      if (attempt > 0) {
        console.log(`✅ AI [${label}] succeeded on retry attempt ${attempt} (+${Date.now() - attemptStartedAt}ms)`);
      }
      return response;
    } catch (error) {
      lastError = error;
      const retryable = isRetryableApiError(error);
      if (isDailyQuotaExhausted(error)) {
        // ✅ سطر مميّز بسهولة grep - لو ظهر هاد بالإنتاج، الحل الوحيد هو
        // تفعيل الفوترة على مشروع Gemini API (لا كود ولا زيادة مهلة/محاولات
        // ممكن يصلحه - راجع تعليق isDailyQuotaExhausted فوق)
        console.error(`🚫 AI [${label}] DAILY QUOTA EXHAUSTED - failing fast, no retry can help until Google resets the daily window or billing is enabled.`);
        break;
      }
      console.error(
        `❌ AI [${label}] generateContent attempt ${attempt + 1}/${MAX_API_RETRIES + 1} failed ` +
          `(status=${error && error.status}, retryable=${retryable}, +${Date.now() - attemptStartedAt}ms):`,
        error && error.message ? error.message : error
      );
      if (!retryable || attempt === MAX_API_RETRIES) break;
      const delay = RETRY_BASE_DELAY_MS * 2 ** attempt + Math.floor(Math.random() * 300);
      console.log(`⏳ AI [${label}] retrying in ${delay}ms...`);
      await sleep(delay);
    }
  }
  throw lastError;
}

let client = null;
function getClient() {
  if (!GEMINI_API_KEY || GEMINI_API_KEY === 'YOUR_GEMINI_API_KEY') {
    throw new Error('GEMINI_API_KEY is not configured');
  }
  if (!client) {
    client = new GoogleGenAI({ apiKey: GEMINI_API_KEY });
  }
  return client;
}

/**
 * يشغّل محادثة كاملة مع الموديل، بما فيها حلقة استدعاء الأدوات (Function
 * Calling) لو الموديل طلب بيانات حية من قاعدة البيانات. بيرجع النص النهائي
 * بس (بدون أي تفاصيل تقنية) + أسماء الأدوات المستخدمة (لغايات metadata/تشخيص).
 *
 * ✅ بتعالج استدعاءات أدوات متوازية (parallel function calls) بنفس الدورة -
 * موديلات Gemini 2.5 بتطلب أكتر من tool بنفس الرد بشكل طبيعي، ولازم كل
 * الردود (FunctionResponse) ترجع سوا بدورة وحدة، مش وحدة وحدة.
 *
 * @param {object} params
 * @param {string} params.systemPrompt
 * @param {Array}  params.history - [{role: 'user'|'model', parts: [{text}]}]
 * @param {string} params.message - رسالة المستخدم الجديدة
 * @param {Array}  params.toolDeclarations - [{name, description, parameters}]
 * @param {Object.<string, Function>} params.toolHandlers - name -> async (args) => result
 */
async function runConversation({ systemPrompt, history, message, toolDeclarations, toolHandlers }) {
  const ai = getClient();
  const contents = [...history, { role: 'user', parts: [{ text: message }] }];
  const toolsUsed = [];
  const startedAt = Date.now();

  const config = { systemInstruction: systemPrompt };
  if (toolDeclarations && toolDeclarations.length > 0) {
    config.tools = [{ functionDeclarations: toolDeclarations }];
    // ✅ مستخدمين حلقة تنفيذ يدوية (تحكم كامل بالتفويض/الأمان لكل tool) -
    // منعطّل Automatic Function Calling الخاص بالـ SDK بشكل صريح، بدل ما
    // نعتمد إنه "ما رح يفعّل تلقائيًا" لأنه بس بيشتغل مع دوال JS حقيقية
    // (يلي ما منمررها هون، منمرر functionDeclarations فقط).
    config.automaticFunctionCalling = { disable: true };
  }

  for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
    console.log(`🤖 AI round ${round + 1}/${MAX_TOOL_ROUNDS} started (+${Date.now() - startedAt}ms)`);
    const response = await generateContentWithRetry(ai, { model: GEMINI_MODEL, contents, config }, `round ${round + 1}`);

    const candidateParts = response?.candidates?.[0]?.content?.parts || [];
    const functionCallParts = candidateParts.filter((p) => p.functionCall);

    if (functionCallParts.length === 0) {
      console.log(`🤖 AI round ${round + 1} finished with final text (+${Date.now() - startedAt}ms)`);
      return { replyText: (response.text || '').trim(), toolsUsed };
    }

    // ✅ رد الموديل نفسه (بما فيه كل استدعاءات الأدوات المطلوبة) لازم يُضاف
    // للتاريخ قبل أي رد أدوات - نفس ترتيب الدورة يلي الـ API بيتوقعه
    contents.push(createModelContent(candidateParts));

    const functionResponseParts = await Promise.all(
      functionCallParts.map(async (part) => {
        const { id, name, args } = part.functionCall;
        const handler = toolHandlers[name];
        const toolStartedAt = Date.now();
        let toolResult;
        try {
          toolResult = handler ? await handler(args || {}) : { error: `Unknown tool: ${name}` };
          console.log(`🔧 AI tool "${name}" done (+${Date.now() - toolStartedAt}ms)`);
        } catch (toolError) {
          console.error(`❌ AI tool "${name}" execution error (+${Date.now() - toolStartedAt}ms):`, toolError);
          toolResult = { error: 'Failed to fetch this data right now.' };
        }
        toolsUsed.push(name);
        return createPartFromFunctionResponse(id, name, toolResult);
      })
    );

    // ✅ كل ردود الأدوات المتوازية سوا بدورة وحدة (مش دورة لكل رد) - هاد
    // الشكل يلي Gemini بيتوقعه لما يطلب أكتر من tool بنفس الرد
    contents.push(createUserContent(functionResponseParts));
  }

  // ✅ تجاوز سقف الجولات - لوحظ فعليًا بسؤال "اقترحلي مطاعم برجر" (5 استدعاءات
  // search_restaurants/recommend_for_me متتالية بدون رد نهائي، لأن الموديل
  // كان يعيد المحاولة بأشكال مختلفة بدل ما يقبل نتيجة فاضية ويرد). الحل هون:
  // بدل رسالة عامة غير مفيدة، منجبر رد نهائي حقيقي بنداء أخير *بدون* أدوات -
  // الموديل عنده كل نتائج الأدوات يلي جمعها بالـ contents لحد هلق، فقادر
  // يلخّص/يجاوب فعليًا بدل ما "يعلّق". لو حتى هاد النداء فشل (نادر جدًا)،
  // بس هون بنرجع الرسالة الآمنة كـ fallback أخير.
  console.log(`🤖 AI exceeded ${MAX_TOOL_ROUNDS} rounds, forcing final answer-only call (+${Date.now() - startedAt}ms)`);
  try {
    const finalResponse = await generateContentWithRetry(
      ai,
      {
        model: GEMINI_MODEL,
        contents: [
          ...contents,
          {
            role: 'user',
            parts: [{ text: 'Please answer now in plain text using whatever information you already gathered above - do not call any more tools.' }]
          }
        ],
        config: { systemInstruction: systemPrompt } // ✅ بدون tools هون عمداً - يمنع أي جولة استدعاء إضافية
      },
      'final-answer-fallback'
    );
    const finalText = (finalResponse.text || '').trim();
    if (finalText) return { replyText: finalText, toolsUsed };
  } catch (finalError) {
    console.error('❌ AI final-answer fallback call failed:', finalError);
  }

  return { replyText: '', toolsUsed, exceededMaxRounds: true };
}

module.exports = { runConversation, GEMINI_MODEL };
