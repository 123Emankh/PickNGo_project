// lib/screens/auth/verify_otp_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

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

    // ✅ التحقق من التهيئة
    if (!authState.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Handle verification success
    if (authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isVerification ? 'Verify Email' : 'Verify OTP'),
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
                widget.isVerification ? 'Enter Verification Code' : 'Reset Password',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isVerification 
                    ? 'We have sent a verification code to'
                    : 'Enter the code sent to your email to reset your password',
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
                onChanged: (value) {
                  setState(() {
                    _error = '';
                  });
                },
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
                text: widget.isVerification ? 'Verify' : 'Reset Password',
                isLoading: authState.isLoading,
                onPressed: () {
                  final otp = _otpController.text.trim();
                  if (otp.length != AppConstants.otpLength) {
                    setState(() {
                      _error = 'Please enter all 6 digits';
                    });
                    return;
                  }

                  if (widget.isVerification) {
                    // ✅ للتسجيل
                    authNotifier.verifySignup(
                      email: widget.email,
                      otp: otp,
                    );
                  } else {
                    // ✅ لإعادة تعيين كلمة المرور
                    _showResetPasswordDialog(context, otp);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code?",
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
                      'Resend',
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
                  'Code expires in ${authState.authResponse!.expiresIn}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
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
    final TextEditingController confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ TextFormField مع validator
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  hintText: 'Enter new password (min 6 characters)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // ✅ TextFormField مع validator
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Confirm new password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          Consumer(
            builder: (context, ref, child) {
              final authState = ref.watch(authProvider);
              return ElevatedButton(
                onPressed: authState.isLoading
                    ? null
                    : () {
                        if (formKey.currentState!.validate()) {
                          final authNotifier = ref.read(authProvider.notifier);
                          authNotifier.resetPassword(
                            email: widget.email,
                            otp: otp,
                            newPassword: newPasswordController.text.trim(),
                          );
                          
                          // إذا نجحت، أغلق الحوار واذهب إلى Login
                          if (authState.authResponse?.success == true) {
                            Navigator.pop(context);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          }
                        }
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
                    : const Text('Reset Password'),
              );
            },
          ),
        ],
      ),
    );
  }
}