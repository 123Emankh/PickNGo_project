// src/services/assignment/factors.js
//
// نقطة التوسّع الوحيدة لمحرك التعيين الذكي (Phase 3): كل عامل هون دالة نقية
// compute(candidate, order) => رقم بين 0 و1 (كلما أعلى كان السائق أفضل)، أو
// null لو العامل "مش قابل للتطبيق" على هاد الطلب (بيتم تجاهله من المعدل
// الموزون بدل ما يعاقب السائق بصفر). لإضافة عامل جديد (تقييم سائق مثلًا):
// أضيفي كائن جديد لمصفوفة SCORING_FACTORS بنفس الشكل - scoringEngine.js
// ما بحتاج يتعدّل إطلاقًا.
//
// candidate = { driver, distanceKm, activeOrders } (جاهزة مسبقًا من scoringEngine)

// أبعد مسافة (كم) بين السائق والمتجر لسا معقولة نعرض عليه فيها الطلب.
// أبعد من هيك = استبعاد كامل (hard filter) بغض النظر عن باقي العوامل.
const MAX_ASSIGNMENT_RADIUS_KM = 15;

// أكتر عدد طلبات نشطة (assigned أو مو مسلّمة بعد) يقدر السائق يستحملها
// بنفس الوقت قبل ما نعتبره "مليان" ونستبعده من عروض جديدة.
const MAX_CONCURRENT_ACTIVE_ORDERS = 3;

const distanceFactor = {
  name: 'distance',
  weight: 0.45,
  compute(candidate) {
    if (candidate.distanceKm === null || candidate.distanceKm === undefined) return 0;
    const score = 1 - candidate.distanceKm / MAX_ASSIGNMENT_RADIUS_KM;
    return Math.max(0, Math.min(1, score));
  }
};

const loadFactor = {
  name: 'active_load',
  weight: 0.30,
  compute(candidate) {
    const score = 1 - candidate.activeOrders / MAX_CONCURRENT_ACTIVE_ORDERS;
    return Math.max(0, Math.min(1, score));
  }
};

const companyFactor = {
  name: 'company_priority',
  weight: 0.25,
  compute(candidate, order) {
    // ✅ ما عند الطلب شركة مفضّلة -> العامل مش قابل للتطبيق (منحيّده، مش منعاقب
    // السائق المستقل عليه)
    if (!order.preferred_company_id) return null;
    const isCompanyDriver =
      candidate.driver.company_id === order.preferred_company_id &&
      candidate.driver.company_join_status === 'Approved';
    return isCompanyDriver ? 1 : 0;
  }
};

// ✅ الترتيب هون بيصير ترتيب العرض بـ assignment_reason.factors بس - ما إله
// تأثير على النتيجة (كل عامل بيوزن بـ weight تبعه).
const SCORING_FACTORS = [distanceFactor, loadFactor, companyFactor];

// ✅ نقطة عرض واحدة تحوّل breakdown (ناتج scoringEngine.scoreCandidate) لجملة
// عربية بسيطة يفهمها السائق "ليش أنا؟" - ما بتضيف أي منطق تسجيل جديد، بس
// تفسّر نفس الأرقام المحسوبة أصلًا. تُستخدم بعرض order:offer (فردي ومجمّع).
function buildOfferReasonLabel(breakdown, distanceKm) {
  if (!Array.isArray(breakdown)) return null;
  const scoreOf = (name) => breakdown.find((b) => b.factor === name)?.score;

  // ✅ تفضيل الشركة إشارة ثنائية صريحة (1 أو 0) - لو انطبقت، هي أوضح سبب
  // ومقصود من صاحب المتجر، فمنقدّمها على أي تفسير تاني
  if (scoreOf('company_priority') === 1) {
    return 'اخترناك لأنك سائق الشركة المفضّلة لهذا المتجر';
  }
  if (distanceKm !== null && distanceKm !== undefined) {
    return `اخترناك لأنك الأقرب للمتجر (${distanceKm.toFixed(1)} كم)`;
  }
  if (scoreOf('active_load') !== undefined) {
    return 'اخترناك لأن لديك أقل عدد من الطلبات الحالية';
  }
  return null;
}

module.exports = {
  SCORING_FACTORS,
  MAX_ASSIGNMENT_RADIUS_KM,
  MAX_CONCURRENT_ACTIVE_ORDERS,
  buildOfferReasonLabel
};
