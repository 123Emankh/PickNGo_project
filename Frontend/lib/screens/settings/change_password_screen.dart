// lib/screens/settings/change_password_screen.dart
//
// تغيير كلمة مرور المستخدم المسجل دخوله - يحتاج كلمة السر الحالية للتحقق
// (بعكس مسار "نسيت كلمة المرور" الموجود مسبقًا واللي بيعتمد على OTP بالإيميل).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/main_layout.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit(Locale locale) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).changePassword(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );
    if (!mounted) return;

    final error = ref.read(authProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? AppLocalizations.t(locale, 'change_password_success') : (error ?? ''),
        ),
      ),
    );
    if (success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ شاشة مشتركة بين كل الأدوار (توصلها من ProfileScreen لأي دور، وكمان
    // من CustomerSettingsScreen للزبون) - الهيدر الموحّد الجديد (MainLayout/
    // AppHeader) مبني خصيصًا للزبون فما لازم يظهر لغير الأدوار التانية.
    final role = ref.watch(authProvider).user?.role;
    if (role == 'Customer') {
      return MainLayout(
        builder: (context, isWeb, padding, width) => _buildBody(context, showTitle: true),
      );
    }

    final locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(locale, 'change_password_title')),
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        elevation: 0,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context, {bool showTitle = false}) {
    final locale = Localizations.localeOf(context);
    final isLoading = ref.watch(authProvider).isLoading;

    return SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showTitle) ...[
                    Text(
                      AppLocalizations.t(locale, 'change_password_title'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                      controller: _currentController,
                      label: AppLocalizations.t(locale, 'change_password_current'),
                      hint: '',
                      obscureText: _obscureCurrent,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? AppLocalizations.t(locale, 'change_password_err_required')
                          : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _newController,
                      label: AppLocalizations.t(locale, 'change_password_new'),
                      hint: '',
                      obscureText: _obscureNew,
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return AppLocalizations.t(locale, 'change_password_err_required');
                        }
                        if (v.length < 6) {
                          return AppLocalizations.t(locale, 'change_password_err_too_short');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _confirmController,
                      label: AppLocalizations.t(locale, 'change_password_confirm'),
                      hint: '',
                      obscureText: _obscureConfirm,
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return AppLocalizations.t(locale, 'change_password_err_required');
                        }
                        if (v != _newController.text) {
                          return AppLocalizations.t(locale, 'change_password_err_mismatch');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: AppLocalizations.t(locale, 'change_password_submit'),
                      isLoading: isLoading,
                      onPressed: () => _submit(locale),
                    ),
                  ],
                ),
              ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}
