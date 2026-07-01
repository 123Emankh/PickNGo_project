// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:email_validator/email_validator.dart';
import 'package:frontend/screens/home/home_screen.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../core/theme/app_theme.dart';
import 'verify_otp_screen.dart';
import 'business_category_screen.dart';
import 'driver_vehicle_screen.dart'; // شاشة اختيار نوع المركبة للسائق
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedRole = 'Customer'; // 'Customer', 'Vendor', 'Driver'
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    if (!authState.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // التوجيه التلقائي عند نجاح تسجيل الدخول
    if (authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      });
    }

    // التحقق من كود الـ OTP
    if (authState.authResponse?.requireVerification == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyOtpScreen(
              email: _emailController.text.trim(),
              tempToken: authState.authResponse!.tempToken!,
              isVerification: true,
            ),
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Form(
                key: _formKey,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      
                      // 🟢 شعار التطبيق (Logo)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          size: 54,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      const Text(
                        'PickNGo',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F5132),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Cairo's Modern Multi-Vendor Delivery System",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 📊 نظام الـ Tabs (Login / Register)
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          labelColor: const Color(0xFF0F5132),
                          unselectedLabelColor: Colors.grey[500],
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          tabs: const [
                            Tab(text: 'Login'),
                            Tab(text: 'Register'),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 👤 قسم اختيار نوع الحساب (Role Selection) الملون الجديد
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Choose Your Account Type',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          _buildRoleCard(
                            role: 'Customer',
                            title: 'Customer',
                            subtitle: 'Buy & Order',
                            icon: Icons.shopping_basket_outlined,
                            activeColor: const Color(0xFF2E7D32), // أخضر
                          ),
                          const SizedBox(width: 8),
                          _buildRoleCard(
                            role: 'Vendor',
                            title: 'Business',
                            subtitle: 'Store Owner',
                            icon: Icons.storefront_rounded,
                            activeColor: const Color(0xFFE65100), // برتقالي
                          ),
                          const SizedBox(width: 8),
                          _buildRoleCard(
                            role: 'Driver',
                            title: 'Delivery',
                            subtitle: 'Rider / Driver',
                            icon: Icons.delivery_dining_rounded,
                            activeColor: const Color(0xFF0288D1), // أزرق
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),

                      // عرض رسائل الخطأ من الـ Provider إن وجدت
                      if (authState.error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade400),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  authState.error!,
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // الحقول الديناميكية بناءً على التاب المختار
                      AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, child) {
                          return _tabController.index == 0 
                              ? _buildLoginForm(authNotifier, authState.isLoading) 
                              : _buildRegisterForm(authNotifier, authState.isLoading);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 👤 ويدجت بطاقة اختيار نوع الحساب بتصميم تفاعلي ملون ومميز
  Widget _buildRoleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedRole == role;
    
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedRole = role),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? activeColor : Colors.grey.shade200,
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected 
                    ? activeColor.withOpacity(0.15) 
                    : Colors.black.withOpacity(0.02),
                blurRadius: isSelected ? 12 : 6,
                offset: Offset(0, isSelected ? 6 : 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // دائرة الأيقونة الخلفية التفاعلية
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey[600],
                  size: 24,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeColor : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? activeColor.withOpacity(0.8) : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // نموذج تسجيل الدخول
  Widget _buildLoginForm(dynamic authNotifier, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'Enter your email',
          prefixIcon: const Icon(Icons.email_outlined),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your email';
            if (!EmailValidator.validate(value)) return 'Please enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          obscureText: _obscurePassword,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your password';
            if (value.length < 6) return 'Password must be at least 6 characters';
            return null;
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
              );
            },
            child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFF0F5132), fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 16),
        CustomButton(
          text: 'Login',
          isLoading: isLoading,
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              authNotifier.login(
                email: _emailController.text.trim(),
                password: _passwordController.text.trim(),
              );
            }
          },
        ),
      ],
    );
  }

  // نموذج إنشاء حساب
  Widget _buildRegisterForm(dynamic authNotifier, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _nameController,
          label: 'Full Name',
          hint: 'Enter your full name',
          prefixIcon: const Icon(Icons.person_outline),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your name';
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _phoneController,
          label: 'Phone Number',
          hint: 'Enter your phone number',
          prefixIcon: const Icon(Icons.phone_outlined),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your phone number';
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'Enter your email',
          prefixIcon: const Icon(Icons.email_outlined),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your email';
            if (!EmailValidator.validate(value)) return 'Please enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Create a password',
          obscureText: _obscurePassword,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter a password';
            if (value.length < 6) return 'Password must be at least 6 characters';
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          hint: 'Repeat your password',
          obscureText: _obscureConfirmPassword,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
          validator: (value) {
            if (value != _passwordController.text) return 'Passwords do not match';
            return null;
          },
        ),
        const SizedBox(height: 24),
        CustomButton(
          text: 'Sign Up',
          isLoading: isLoading,
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              if (_selectedRole == 'Vendor') {
                // الانتقال لشاشة فئات الأعمال التجارية
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BusinessCategoryScreen()),
                );
              } else if (_selectedRole == 'Driver') {
                // الانتقال لشاشة نوع مركبة التوصيل
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DriverVehicleScreen()),
                );
              } else {
                // التسجيل المباشر كزبون
                authNotifier.signup(
                  fullName: _nameController.text.trim(),
                  email: _emailController.text.trim(),
                  password: _passwordController.text.trim(),
                  phone: _phoneController.text.trim(),
                  role: _selectedRole,
                );
              }
            }
          },
        ),
      ],
    );
  }
}