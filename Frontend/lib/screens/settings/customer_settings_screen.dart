// lib/screens/settings/customer_settings_screen.dart
//
// شاشة إعدادات الزبون - تجمع كل شيء يخص الحساب والتفضيلات في مكان واحد:
// تعديل الملف الشخصي (شاشة موجودة مسبقًا)، تغيير الصورة الشخصية، تغيير
// كلمة المرور، اللغة، المظهر (Dark Mode - كان مبني بالكامل بدون واجهة بعد
// تسجيل الدخول)، حول التطبيق، سياسة الخصوصية، شروط الاستخدام، وتسجيل الخروج.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/api_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_notifier.dart';
import '../../core/theme/app_themes.dart';
import '../../core/theme/theme_notifier.dart';
import '../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/main_layout.dart';
import '../landing/landing_screen.dart';
import '../profile/profile_screen.dart';
import 'about_screen.dart';
import 'change_password_screen.dart';
import 'legal_content_screen.dart';
import 'order_report_screen.dart';

class CustomerSettingsScreen extends ConsumerStatefulWidget {
  const CustomerSettingsScreen({super.key});

  @override
  ConsumerState<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends ConsumerState<CustomerSettingsScreen> {
  bool _uploadingAvatar = false;

  Future<void> _pickAvatar(Locale locale) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    final success = await ref.read(authProvider.notifier).uploadAvatar(File(picked.path));
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.t(
            locale,
            success ? 'settings_avatar_updated' : 'settings_avatar_update_failed',
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(Locale locale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t(locale, 'settings_logout_confirm_title')),
        content: Text(AppLocalizations.t(locale, 'settings_logout_confirm_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.t(locale, 'settings_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppLocalizations.t(locale, 'settings_confirm'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LandingScreen()),
      (route) => false,
    );
  }

  void _showLanguagePicker(Locale locale) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.t(locale, 'settings_select_language'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            for (final option in const [Locale('en'), Locale('ar'), Locale('fr')])
              ListTile(
                title: Text(AppLocalizations.t(locale, 'language_${option.languageCode}')),
                trailing: locale.languageCode == option.languageCode
                    ? const Icon(Icons.check, color: AppColors.brand)
                    : null,
                onTap: () {
                  ref.read(localeNotifierProvider.notifier).setLocale(option);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showThemePicker(Locale locale) {
    final current = ref.read(themeNotifierProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.t(locale, 'settings_select_theme'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            for (final mode in const [ThemeMode.system, ThemeMode.light, ThemeMode.dark])
              ListTile(
                leading: Icon(
                  mode == ThemeMode.dark
                      ? Icons.dark_mode_outlined
                      : mode == ThemeMode.light
                          ? Icons.light_mode_outlined
                          : Icons.brightness_auto_outlined,
                ),
                title: Text(AppLocalizations.t(locale, 'landing2_theme_${mode.name}')),
                trailing: current == mode ? const Icon(Icons.check, color: AppColors.brand) : null,
                onTap: () {
                  ref.read(themeNotifierProvider.notifier).setThemeMode(mode);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final user = ref.watch(authProvider).user;
    final themeMode = ref.watch(themeNotifierProvider);

    return MainLayout(
      builder: (context, isWeb, padding, width) => SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      AppLocalizations.t(locale, 'settings_title'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildAvatarHeader(locale, user),
                  const SizedBox(height: 28),
                  _sectionLabel(locale, 'settings_section_account'),
                  _buildCard([
                    _tile(
                      icon: Icons.person_outline,
                      title: AppLocalizations.t(locale, 'settings_edit_profile'),
                      subtitle: AppLocalizations.t(locale, 'settings_edit_profile_subtitle'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      ),
                    ),
                    _divider(),
                    _tile(
                      icon: Icons.lock_outline,
                      title: AppLocalizations.t(locale, 'settings_change_password'),
                      subtitle: AppLocalizations.t(locale, 'settings_change_password_subtitle'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                      ),
                    ),
                    _divider(),
                    _tile(
                      icon: Icons.receipt_long_outlined,
                      title: AppLocalizations.t(locale, 'settings_order_report'),
                      subtitle: AppLocalizations.t(locale, 'settings_order_report_subtitle'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OrderReportScreen()),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _sectionLabel(locale, 'settings_section_preferences'),
                  _buildCard([
                    _tile(
                      icon: Icons.language,
                      title: AppLocalizations.t(locale, 'settings_language'),
                      subtitle: AppLocalizations.t(locale, 'language_${locale.languageCode}'),
                      onTap: () => _showLanguagePicker(locale),
                    ),
                    _divider(),
                    _tile(
                      icon: Icons.brightness_6_outlined,
                      title: AppLocalizations.t(locale, 'settings_theme'),
                      subtitle: AppLocalizations.t(locale, 'landing2_theme_${themeMode.name}'),
                      onTap: () => _showThemePicker(locale),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _sectionLabel(locale, 'settings_section_about'),
                  _buildCard([
                    _tile(
                      icon: Icons.info_outline,
                      title: AppLocalizations.t(locale, 'settings_about_app'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
                    ),
                    _divider(),
                    _tile(
                      icon: Icons.privacy_tip_outlined,
                      title: AppLocalizations.t(locale, 'settings_privacy_policy'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalContentScreen(
                            titleKey: 'privacy_title',
                            bodyKey: 'privacy_body',
                          ),
                        ),
                      ),
                    ),
                    _divider(),
                    _tile(
                      icon: Icons.description_outlined,
                      title: AppLocalizations.t(locale, 'settings_terms'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LegalContentScreen(
                            titleKey: 'terms_title',
                            bodyKey: 'terms_body',
                          ),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _buildCard([
                    _tile(
                      icon: Icons.logout,
                      title: AppLocalizations.t(locale, 'settings_logout'),
                      iconColor: Colors.redAccent,
                      titleColor: Colors.redAccent,
                      onTap: () => _handleLogout(locale),
                    ),
                  ]),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarHeader(Locale locale, UserModel? user) {
    final avatarUrl = ApiConstants.resolveImageUrl(user?.profilePicture);

    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.brand.withValues(alpha: 0.1),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              onBackgroundImageError: avatarUrl != null ? (_, _) {} : null,
              child: avatarUrl == null
                  ? const Icon(Icons.person_outline, size: 44, color: AppColors.brand)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _uploadingAvatar ? null : () => _pickAvatar(locale),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                  ),
                  child: _uploadingAvatar
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _uploadingAvatar ? null : () => _pickAvatar(locale),
          child: Text(AppLocalizations.t(locale, 'settings_change_avatar')),
        ),
        Text(
          user?.fullName ?? '',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (user != null) Text(user.email, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ],
    );
  }

  Widget _sectionLabel(Locale locale, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          AppLocalizations.t(locale, key).toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => Divider(height: 1, indent: 56, color: Theme.of(context).dividerColor);

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500]))
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
