// lib/screens/settings/about_screen.dart
import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_themes.dart';
import '../../widgets/main_layout.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // ✅ لازم يطابق "version" بـ pubspec.yaml. ما أضفنا مكتبة package_info_plus
  // لهالغرض البسيط - مش مبرر إضافة native dependency جديدة بس لعرض رقم إصدار.
  static const String _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);

    return MainLayout(
      builder: (context, isWeb, padding, width) => SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      AppLocalizations.t(locale, 'settings_about_app'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(Icons.delivery_dining, size: 44, color: AppColors.brand),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.t(locale, 'app_name'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.t(locale, 'about_tagline'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.t(locale, 'about_description'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${AppLocalizations.t(locale, 'about_version')} $_appVersion',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
