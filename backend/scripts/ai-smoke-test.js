// scripts/ai-smoke-test.js
//
// المساعد الذكي: فحص مباشر لطبقة Gemini/@google/genai بس (geminiClient.js)،
// بمعزل عن الباك إند/قاعدة البيانات - بيستخدم أدوات مزيّفة (mock) بدل
// aiTools.js الحقيقية، عشان نتحقق من شكل الطلب/الرد الفعلي مقابل الـ API
// الحقيقي بدون ما نحتاج سيرفر شغّال أو قاعدة بيانات معبّاة. شغّليه بعد ما
// تحطي GEMINI_API_KEY حقيقي بـ .env:
//
//   npm run ai:smoke-test
//
// كل تست بيطبع PASS/FAIL + التفاصيل. Exit code 1 لو أي تست فشل (مفيد لو
// حبيتي تربطيه بـ CI مستقبلًا).
require('dotenv').config();
const { runConversation } = require('../src/services/ai/geminiClient');

let failures = 0;

function check(label, condition, details) {
  if (condition) {
    console.log(`✅ PASS - ${label}`);
  } else {
    failures++;
    console.log(`❌ FAIL - ${label}`);
    if (details !== undefined) console.log('   details:', details);
  }
}

async function testPlainConversationNoTools() {
  console.log('\n--- Test 1: plain conversation, no tools (Driver-like FAQ) ---');
  const result = await runConversation({
    systemPrompt: 'You are a helpful assistant for a delivery app. Answer briefly.',
    history: [],
    message: 'In one short sentence, what does a delivery app do?',
    toolDeclarations: [],
    toolHandlers: {}
  });
  check('got a non-empty reply', typeof result.replyText === 'string' && result.replyText.length > 0, result);
  check('no tools were used', result.toolsUsed.length === 0, result.toolsUsed);
  check('did not exceed max rounds', !result.exceededMaxRounds);
}

async function testSingleFunctionCall() {
  console.log('\n--- Test 2: single forced function call (get_order_status-like tool) ---');
  let handlerCalledWith = null;
  const result = await runConversation({
    systemPrompt: 'You are a delivery app assistant. You MUST use the get_fake_order_status tool to answer any question about order status - never guess.',
    history: [],
    message: 'Where is my order? My order number is PN-9001.',
    toolDeclarations: [
      {
        name: 'get_fake_order_status',
        description: 'Get the status of an order by order number.',
        parameters: {
          type: 'OBJECT',
          properties: { order_number: { type: 'STRING' } },
          required: ['order_number']
        }
      }
    ],
    toolHandlers: {
      get_fake_order_status: async (args) => {
        handlerCalledWith = args;
        return { order_number: args.order_number, status: 'PickedUp', eta_minutes: 12 };
      }
    }
  });

  check('tool handler was actually invoked', handlerCalledWith !== null, handlerCalledWith);
  check('tool handler received the order_number arg', handlerCalledWith && handlerCalledWith.order_number, handlerCalledWith);
  check('tools_used includes our tool', result.toolsUsed.includes('get_fake_order_status'), result.toolsUsed);
  check('final reply mentions the ETA/status info (not empty)', result.replyText.length > 0, result.replyText);
  console.log('   model final reply:', result.replyText);
}

async function testParallelFunctionCalls() {
  console.log('\n--- Test 3: encourage parallel/multiple function calls in one turn ---');
  const calledTools = [];
  const result = await runConversation({
    systemPrompt: 'You are an admin dashboard assistant. Use the provided tools to answer. If the user asks about two different things, call both relevant tools before answering.',
    history: [],
    message: 'How many orders were completed today, AND how many drivers are online right now? Answer both.',
    toolDeclarations: [
      { name: 'get_fake_today_orders', description: 'Get count of orders completed today.', parameters: { type: 'OBJECT', properties: {} } },
      { name: 'get_fake_online_drivers', description: 'Get count of drivers currently online.', parameters: { type: 'OBJECT', properties: {} } }
    ],
    toolHandlers: {
      get_fake_today_orders: async () => { calledTools.push('get_fake_today_orders'); return { completed_orders_today: 42 }; },
      get_fake_online_drivers: async () => { calledTools.push('get_fake_online_drivers'); return { online_drivers: 7 }; }
    }
  });

  // ✅ مش شرط الموديل يطلب الأداتين بنفس الجولة (سلوك غير حتمي) - المهم إنه
  // بالنهاية استدعى الأداتين (بجولة وحدة أو أكتر) والحلقة قدرت تتعامل مع
  // الحالتين بدون خطأ
  check('both fake tools were eventually called', calledTools.includes('get_fake_today_orders') && calledTools.includes('get_fake_online_drivers'), calledTools);
  check('final reply is non-empty and did not exceed max rounds', result.replyText.length > 0 && !result.exceededMaxRounds, result);
  console.log('   model final reply:', result.replyText);
}

async function testUnknownToolGracefulHandling() {
  console.log('\n--- Test 4: tool handler throws - loop should degrade gracefully, not crash ---');
  const result = await runConversation({
    systemPrompt: 'You must call get_will_fail to answer any question, then tell the user what it returned or that it failed.',
    history: [],
    message: 'Please check the status using the tool.',
    toolDeclarations: [
      { name: 'get_will_fail', description: 'Always fails.', parameters: { type: 'OBJECT', properties: {} } }
    ],
    toolHandlers: {
      get_will_fail: async () => { throw new Error('Simulated DB failure'); }
    }
  });
  check('did not throw, returned a reply instead', typeof result.replyText === 'string', result);
}

async function main() {
  if (!process.env.GEMINI_API_KEY || process.env.GEMINI_API_KEY === 'YOUR_GEMINI_API_KEY') {
    console.error('❌ GEMINI_API_KEY is not set in backend/.env - set a real key before running this smoke test.');
    process.exit(1);
  }

  await testPlainConversationNoTools();
  await testSingleFunctionCall();
  await testParallelFunctionCalls();
  await testUnknownToolGracefulHandling();

  console.log(failures === 0 ? '\n✅ All smoke tests passed.' : `\n❌ ${failures} check(s) failed.`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error('❌ Smoke test crashed unexpectedly:', err);
  process.exit(1);
});
