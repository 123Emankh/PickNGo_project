// lib/widgets/chat/chat_floating_button.dart
//
// زر دائري عائم لفتح شاشة المساعد الذكي - نفس أسلوب ActiveOrderBanner
// (Material شفاف + InkWell + Container بظل) بس بشكل دائري بدل "pill".
//
// ⚠️ عمداً بدون Tooltip: هاد الزر مبني داخل MaterialApp.builder (راجع
// main.dart) يعني هو شقيق لـ Navigator بالشجرة مش من ذريته. الـ Overlay
// الوحيد بالتطبيق أصلاً هو داخل Navigator (Flutter بيصنعه تلقائياً)، فأي
// widget بيحتاج Overlay.of(context) من هاد الموقع (Tooltip، PopupMenuButton،
// showMenu...) بيفشل بـ "No Overlay widget found." عند أول محاولة استخدام
// (بالنسبة لـ Tooltip: عند أول hover) - جرّبنا هاد فعليًا وشفنا الخطأ حرفيًا.
// جرّبنا حل بديل (إضافة Overlay فوق MaterialApp بالكامل بـ main.dart) بس
// طلع بيكسر إقلاع التطبيق (Null check operator used on a null value من أول
// فريم) - رجعناه. الحل الفعلي: تجنّب أي widget بيحتاج Overlay ambient
// lookup بهاد الموضع بالشجرة تمامًا، بدل ما نحاول نأمّن له Overlay مصطنع.
import 'package:flutter/material.dart';
import '../../core/theme/app_themes.dart';
import '../../core/navigation/root_navigator.dart';
import '../../screens/chat/ai_chat_screen.dart';

class ChatFloatingButton extends StatelessWidget {
  const ChatFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          // ✅ context هنا فوق الـ Navigator الحقيقي بالشجرة (مبني داخل
          // MaterialApp.builder) - Navigator.of(context) بيفشل من هون
          // (راجع root_navigator.dart). لازم نستخدم المفتاح العام.
          rootNavigatorKey.currentState?.push(
            MaterialPageRoute(builder: (context) => const AiChatScreen()),
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
