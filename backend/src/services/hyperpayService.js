// src/services/hyperpayService.js
// يعزل كل التعامل المباشر مع HyperPay API (Copy&Pay) عن الكونترولر - نفس فكرة otpService.js.
require('dotenv').config();

const BASE_URL = process.env.HYPERPAY_BASE_URL;
const ENTITY_ID = process.env.HYPERPAY_ENTITY_ID;
const ACCESS_TOKEN = process.env.HYPERPAY_ACCESS_TOKEN;

/**
 * ينشئ checkout session جديدة عند HyperPay قبل ما نعرض فورم الدفع للعميل.
 * بيرجع { checkoutId, raw } أو يرمي خطأ لو HyperPay رفض الطلب (مفاتيح غلط، عملة مش مدعومة...).
 */
async function createCheckout({ amount, currency }) {
  const body = new URLSearchParams({
    entityId: ENTITY_ID,
    amount: Number(amount).toFixed(2),
    currency,
    paymentType: 'DB'
  });

  const response = await fetch(`${BASE_URL}/v1/checkouts`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${ACCESS_TOKEN}`,
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body
  });

  const raw = await response.json();

  if (!response.ok || !raw.id) {
    throw new Error(raw?.result?.description || 'HyperPay checkout creation failed');
  }

  return { checkoutId: raw.id, raw };
}

/**
 * يستعلم عن نتيجة الدفع الفعلية من HyperPay (مصدر الحقيقة الوحيد - ما منثق بأي رجوع من الفرونت).
 */
async function getPaymentStatus(checkoutId) {
  const response = await fetch(
    `${BASE_URL}/v1/checkouts/${checkoutId}/payment?entityId=${ENTITY_ID}`,
    {
      method: 'GET',
      headers: { Authorization: `Bearer ${ACCESS_TOKEN}` }
    }
  );

  const raw = await response.json();
  if (!response.ok) {
    throw new Error(raw?.result?.description || 'HyperPay status check failed');
  }
  return raw;
}

// ⚠️ الأنماط دي مكتوبة من معرفة عامة بتوثيق HyperPay/OPPWA بدون وصول حي لتوثيقهم الحالي.
// لازم تتأكدي منها مقابل صفحة "Response Codes" الرسمية أول ما توصلك بيانات اعتماد حقيقية،
// قبل أي استخدام فعلي بالإنتاج. البنية (Paid/Pending/Failed مع fail-closed) هي الجزء الثابت.
const SUCCESS_PATTERN = /^(000\.000\.|000\.100\.1|000\.[36])/;
const PENDING_PATTERN = /^(000\.200)/;

function classifyResultCode(code) {
  if (SUCCESS_PATTERN.test(code)) return 'Paid';
  if (PENDING_PATTERN.test(code)) return 'Pending';
  return 'Failed'; // fail-closed: أي كود مش معروف = فشل، منفترضش نجاح
}

module.exports = { createCheckout, getPaymentStatus, classifyResultCode };
