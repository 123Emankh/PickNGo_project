// lib/widgets/notification_bell.dart
//
// Phase 4 - نظام الإشعارات: أيقونة جرس + عداد غير المقروء، تُستخدم بكل
// هيدرات الأدوار (الزبون/صاحب المتجر/السائق/الأدمن) - نفس الودجة بالضبط
// بكل مكان عشان يضل شكل وسلوك البادج موحّد.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';
import '../screens/notifications/notifications_screen.dart';

class NotificationBell extends ConsumerWidget {
  final Color? iconColor;

  const NotificationBell({super.key, this.iconColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ يحمّل القائمة + يوصل السوكيت أول مرة بس (idempotent) - أي شاشة فيها
    // هيدر بتضمن إنه في نسخة محدّثة من العداد بدون ما تكرر التحميل.
    // Future.microtask بدل نداء مباشر - loadInitial() بيعدّل الـ state
    // (isLoading) قبل أول await فيها، ونداءها مباشرة جوا build() بيخالف قاعدة
    // Riverpod "ما تعدّل provider أثناء بناء شجرة الـ widgets" (كان عم يرمي
    // DartError فعليًا). التأجيل لمايكروتاسك بيخلي التعديل يصير بعد ما
    // الـ build يخلص، بنفس اللحظة تقريبًا.
    Future.microtask(() => ref.read(notificationProvider.notifier).loadInitial());
    final unreadCount = ref.watch(notificationProvider.select((s) => s.unreadCount));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_none_outlined,
            color: iconColor,
            size: 22,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationsScreen()),
            );
          },
        ),
        if (unreadCount > 0)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
