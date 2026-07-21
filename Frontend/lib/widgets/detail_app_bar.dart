// lib/widgets/detail_app_bar.dart
//
// AppBar موحّد لشاشات التفاصيل المفتوحة بـ Navigator.push من أي لوحة
// (طلب/مستخدم/أرباح/أداء/توصيل نشط/توصيل جماعي/تقييمات...) - بدل نفس
// السطر المكرر 7 مرات (backgroundColor: cardColor + foregroundColor +
// elevation: 0) بكل شاشة على حدة. زر الرجوع الافتراضي يجي تلقائيًا من
// AppBar نفسها (Navigator.canPop) زي أي شاشة توصلها Navigator.push.
// بيضيف زري تبديل اللغة/الوضع دايمًا - نفس ما هو متاح بهيدرات اللوحات
// الرئيسية، عشان تبقى الميزتين متاحتين من أي شاشة بالتطبيق.
import 'package:flutter/material.dart';
import 'app_header.dart';

class DetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;

  const DetailAppBar({super.key, required this.title, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).textTheme.bodyLarge?.color;
    return AppBar(
      title: Text(title),
      backgroundColor: Theme.of(context).cardColor,
      foregroundColor: iconColor,
      elevation: 0,
      actions: [
        ...actions,
        LanguageToggleButton(iconColor: iconColor),
        ThemeToggleButton(iconColor: iconColor),
      ],
    );
  }
}
