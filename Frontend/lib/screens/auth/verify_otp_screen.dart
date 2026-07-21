// lib/screens/auth/verify_otp_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../core/i18n/app_localizations.dart';
import '../post_auth_router.dart';
import 'register_screen.dart'; // 👈 بدّلنا login_screen.dart القديمة بهاي

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;
  final String tempToken;
  final bool isVerification;

  const VerifyOtpScreen({
    super.key,
    required this.email,
    required this.tempToken,
    this.isVerification = true,
  });

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    // ✅ نستمع لتغيّرات الحالة بدل ما نفحصها مباشرة بعد الاستدعاء (كانت هاي البق الأساسي)
    ref.listen<AuthState>(authProvider, (previous, next) {
      // نجاح تسجيل الدخول/التحقق (Signup verification)
      if (widget.isVerification && next.isAuthenticated) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const PostAuthRouter()),
          (route) => false,
        );
      }

      // نجاح إعادة تعيين كلمة السر (Reset password)
      if (!widget.isVerification &&
          next.authResponse?.success == true &&
          previous?.authResponse?.success != true) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context); // إغلاق الـ Dialog إذا مفتوح
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const RegisterScreen(startOnLogin: true),
          ),
          (route) => false,
        );
      }
    });

    // ✅ التحقق من التهيئة
    if (!authState.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isVerification
            ? AppLocalizations.t(Localizations.localeOf(context), 'otp_title_verify_email')
            : AppLocalizations.t(Localizations.localeOf(context), 'otp_title_verify_otp')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.verified_outlined,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                widget.isVerification
                    ? AppLocalizations.t(Localizations.localeOf(context), 'otp_heading_verify')
                    : AppLocalizations.t(Localizations.localeOf(context), 'otp_heading_reset'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isVerification
                    ? AppLocalizations.t(Localizations.localeOf(context), 'otp_desc_verify')
                    : AppLocalizations.t(Localizations.localeOf(context), 'otp_desc_reset'),
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (widget.isVerification) ...[
                Text(
                  widget.email,
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 40),
              Pinput(
                controller: _otpController,
                length: AppConstants.otpLength,
                defaultPinTheme: PinTheme(
                  width: 56,
                  height: 56,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                focusedPinTheme: PinTheme(
                  width: 56,
                  height: 56,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                submittedPinTheme: PinTheme(
                  width: 56,
                  height: 56,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                errorPinTheme: PinTheme(
                  width: 56,
                  height: 56,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) => setState(() => _error = ''),
              ),
              const SizedBox(height: 12),
              if (authState.error != null || _error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authState.error ?? _error,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              CustomButton(
                text: widget.isVerification
                    ? AppLocalizations.t(Localizations.localeOf(context), 'otp_button_verify')
                    : AppLocalizations.t(Localizations.localeOf(context), 'otp_button_reset'),
                isLoading: authState.isLoading,
                onPressed: () {
                  final otp = _otpController.text.trim();
                  if (otp.length != AppConstants.otpLength) {
                    setState(() => _error = AppLocalizations.t(Localizations.localeOf(context), 'otp_err_incomplete'));
                    return;
                  }

                  if (widget.isVerification) {
                    authNotifier.verifySignup(email: widget.email, otp: otp);
                  } else {
                    _showResetPasswordDialog(context, otp);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.t(Localizations.localeOf(context), 'otp_didnt_receive'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () {
                            if (widget.isVerification) {
                              authNotifier.resendOTP(email: widget.email);
                            } else {
                              authNotifier.forgotPassword(email: widget.email);
                            }
                          },
                    child: Text(
                      AppLocalizations.t(Localizations.localeOf(context), 'otp_resend'),
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (authState.authResponse?.expiresIn != null)
                Text(
                  '${AppLocalizations.t(Localizations.localeOf(context), 'otp_expires_in')} ${authState.authResponse!.expiresIn}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ عرض حوار لإدخال كلمة المرور الجديدة
  void _showResetPasswordDialog(BuildContext context, String otp) {
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.t(Localizations.localeOf(context), 'otp_heading_reset')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t(Localizations.localeOf(context), 'otp_new_password_label'),
                  hintText: AppLocalizations.t(Localizations.localeOf(context), 'otp_new_password_hint'),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.t(Localizations.localeOf(context), 'otp_err_password_required');
                  }
                  if (value.length < 6) {
                    return AppLocalizations.t(Localizations.localeOf(context), 'otp_err_password_length');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.t(Localizations.localeOf(context), 'otp_confirm_password_label'),
                  hintText: AppLocalizations.t(Localizations.localeOf(context), 'otp_confirm_password_hint'),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.t(Localizations.localeOf(context), 'otp_err_confirm_required');
                  }
                  if (value != newPasswordController.text) {
                    return AppLocalizations.t(Localizations.localeOf(context), 'otp_err_password_mismatch');
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.t(Localizations.localeOf(context), 'otp_cancel')),
          ),
          Consumer(
            builder: (context, ref, child) {
              final authState = ref.watch(authProvider);
              return ElevatedButton(
                onPressed: authState.isLoading
                    ? null
                    : () {
                        if (!formKey.currentState!.validate()) return;

                        // الـ ref.listen فوق بالشاشة الرئيسية هو يلي رح يسكر
                        // الـ Dialog وينقل لـ Login تلقائيًا لما ينجح فعليًا.
                        final authNotifier = ref.read(authProvider.notifier);
                        authNotifier.resetPassword(
                          email: widget.email,
                          otp: otp,
                          newPassword: newPasswordController.text.trim(),
                        );
                      },
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(AppLocalizations.t(Localizations.localeOf(context), 'otp_button_reset')),
              );
            },
          ),
        ],
      ),
    );
  }
}
