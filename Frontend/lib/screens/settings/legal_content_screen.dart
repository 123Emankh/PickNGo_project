// lib/screens/settings/legal_content_screen.dart
//
// شاشة عرض محتوى نصي طويل (سياسة الخصوصية / شروط الاستخدام) - بتقسّم
// النص لفقرات بناءً على "\n\n"، وأي فقرة تبدأ بـ "## " بتترسم كعنوان قسم.
// شاشة واحدة عامة تُستخدم لكلا المحتويين بدل تكرار الكود.

import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../widgets/main_layout.dart';

class LegalContentScreen extends StatelessWidget {
  final String titleKey;
  final String bodyKey;

  const LegalContentScreen({
    super.key,
    required this.titleKey,
    required this.bodyKey,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final body = AppLocalizations.t(locale, bodyKey);
    final paragraphs = body.split('\n\n');

    return MainLayout(
      builder: (context, isWeb, padding, width) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.t(locale, titleKey),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              for (final paragraph in paragraphs) _buildParagraph(context, paragraph),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, String paragraph) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color;
    final isHeading = paragraph.startsWith('## ');

    if (isHeading) {
      final lines = paragraph.split('\n');
      final heading = lines.first.replaceFirst('## ', '');
      final rest = lines.skip(1).join('\n');
      return Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(heading, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(rest, style: TextStyle(fontSize: 13.5, height: 1.7, color: bodyColor)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(paragraph, style: TextStyle(fontSize: 13.5, height: 1.7, color: bodyColor)),
    );
  }
}
