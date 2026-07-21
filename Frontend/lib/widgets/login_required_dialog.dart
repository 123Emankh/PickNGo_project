// lib/widgets/login_required_dialog.dart
//
// نافذة حوار مشتركة تظهر لما ضيف (مش مسجل دخول) يحاول يعمل أي إجراء
// شراء (زي إضافة منتج للسلة). فيها زر مباشر يودي لـ RegisterScreen.

import 'package:flutter/material.dart';
import '../screens/auth/register_screen.dart';
import '../core/i18n/app_localizations.dart';

void showLoginRequiredDialog(BuildContext context) {
  final locale = Localizations.localeOf(context);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        AppLocalizations.t(locale, 'dialog_login_required_title'),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Text(
        AppLocalizations.t(locale, 'dialog_login_required_message'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppLocalizations.t(locale, 'dialog_cancel'),
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF006D32),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            Navigator.pop(context); // إغلاق الـ Dialog الأول
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegisterScreen()),
            );
          },
          child: Text(AppLocalizations.t(locale, 'dialog_login_signup')),
        ),
      ],
    ),
  );
}
