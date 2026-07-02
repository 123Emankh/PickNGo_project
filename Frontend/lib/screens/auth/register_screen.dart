// lib/screens/auth/register_screen.dart
//
// شاشة مخصصة موحدة: Login/Register toggle + اختيار نوع الحساب
// (Customer / Business / Driver) + فورم ديناميكي يتغير حسب النوع،
// مطابقة للتصميم المطلوب بالصور.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:email_validator/email_validator.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../core/theme/app_theme.dart';
import 'verify_otp_screen.dart';
import 'forgot_password_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  // true = يفتح مباشرة على تاب Login، false = يفتح على تاب Register (الافتراضي)
  final bool startOnLogin;

  const RegisterScreen({super.key, this.startOnLogin = false});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  late bool _isLoginMode;
  String _selectedRole = 'Customer'; // Customer | Business | Driver
  String? _selectedActivity; // لِـ Business
  String? _selectedVehicle; // لِـ Driver

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<Map<String, String>> _activityTypes = const [
    {'key': 'restaurant', 'label': 'مطعم', 'emoji': '🍽️'},
    {'key': 'pharmacy', 'label': 'صيدلية', 'emoji': '💊'},
    {'key': 'clothes', 'label': 'ملابس', 'emoji': '👕'},
    {'key': 'supermarket', 'label': 'سوبرماركت', 'emoji': '🛒'},
    {'key': 'electronics', 'label': 'إلكترونيات', 'emoji': '📱'},
    {'key': 'other', 'label': 'أخرى', 'emoji': '📦'},
  ];

  // كل نوع مركبة إله لون مميز خاص فيه (بدل ما تكون كلها رمادية)
  final List<Map<String, dynamic>> _vehicleTypes = const [
    {'key': 'bicycle', 'label': 'Bicycle', 'icon': Icons.pedal_bike, 'color': Color(0xFF1E88E5)},
    {'key': 'motorcycle', 'label': 'Motorcycle', 'icon': Icons.two_wheeler, 'color': Color(0xFFE53935)},
    {'key': 'car', 'label': 'Car', 'icon': Icons.directions_car, 'color': Color(0xFF43A047)},
    {'key': 'van', 'label': 'Van', 'icon': Icons.airport_shuttle, 'color': Color(0xFFFB8C00)},
    {'key': 'company', 'label': 'Company', 'icon': Icons.business, 'color': Color(0xFF6D4C41)},
  ];

  @override
  void initState() {
    super.initState();
    _isLoginMode = widget.startOnLogin;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _storeNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    // التوجيه التلقائي بعد نجاح العملية (OTP)
    if (authState.authResponse?.tempToken != null &&
        authState.authResponse?.success == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
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
      backgroundColor: const Color(0xFFF6F8F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildLoginRegisterToggle(),
                  const SizedBox(height: 20),
                  _buildAccountTypeSelector(),
                  const SizedBox(height: 20),
                  _isLoginMode
                      ? _buildLoginCard(authNotifier, authState.isLoading, authState.error)
                      : _buildRegisterCard(authNotifier, authState.isLoading, authState.error),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- الهيدر (اللوجو + الاسم) ----------
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.local_shipping_outlined, size: 40, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 12),
        const Text(
          'PickNGo',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F5132)),
        ),
        const SizedBox(height: 4),
        Text(
          "Cairo's Modern Multi-Vendor Delivery System",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  // ---------- تبديل Login / Register (Segmented control) ----------
  Widget _buildLoginRegisterToggle() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _toggleTab('Login', _isLoginMode, () => setState(() => _isLoginMode = true))),
          Expanded(child: _toggleTab('Register', !_isLoginMode, () => setState(() => _isLoginMode = false))),
        ],
      ),
    );
  }

  Widget _toggleTab(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: active ? const Color(0xFF0F5132) : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  // ---------- اختيار نوع الحساب ----------
  Widget _buildAccountTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose Your Account Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _accountTypeCard(
                  role: 'Customer',
                  title: 'Customer',
                  subtitle: 'يشتري او يطلب',
                  icon: Icons.shopping_cart_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _accountTypeCard(
                  role: 'Business',
                  title: 'Business',
                  subtitle: 'مالك متجر',
                  icon: Icons.storefront_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _accountTypeCard(
                  role: 'Driver',
                  title: 'Driver',
                  subtitle: 'مندوب توصيل',
                  icon: Icons.two_wheeler_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accountTypeCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.16) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.grey[600], size: 22),
            const SizedBox(height: 6),
            Text(title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.primaryColor : Colors.black87,
                )),
            Text(subtitle,
                style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ---------- كارد تسجيل الدخول ----------
  Widget _buildLoginCard(dynamic authNotifier, bool isLoading, String? error) {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome Back!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (error != null) _errorBanner(error),
            CustomTextField(
              controller: _emailController,
              label: 'Email Address / البريد الإلكتروني',
              hint: 'Enter your email',
              prefixIcon: const Icon(Icons.email_outlined),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter your email';
                if (!EmailValidator.validate(v)) return 'Please enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController,
              label: 'Password / كلمة المرور',
              hint: 'Enter your password',
              obscureText: _obscurePassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter your password';
                return null;
              },
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                  );
                },
                child: Text(
                  'Forgot Password? / نسيت كلمة السر؟',
                  style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            CustomButton(
              text: 'Log In',
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
        ),
      ),
    );
  }

  // ---------- كارد التسجيل (يتغير حسب النوع) ----------
  Widget _buildRegisterCard(dynamic authNotifier, bool isLoading, String? error) {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create Account (${_selectedRole.toUpperCase()})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (error != null) _errorBanner(error),

            CustomTextField(
              controller: _fullNameController,
              label: 'Full Name / الاسم الكامل',
              hint: 'Enter your full name',
              prefixIcon: const Icon(Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _phoneController,
              label: 'Phone Number / رقم الهاتف',
              hint: 'Enter your phone number',
              prefixIcon: const Icon(Icons.phone_outlined),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your phone number' : null,
            ),

            // ----- حقول خاصة بالـ Business -----
            if (_selectedRole == 'Business') ...[
              const SizedBox(height: 20),
              Text('Store Setup / إعدادات المتجر',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13)),
              const SizedBox(height: 10),
              CustomTextField(
                controller: _storeNameController,
                label: 'Store Name / اسم النشاط التجاري',
                hint: 'Enter your store name',
                prefixIcon: const Icon(Icons.storefront_outlined),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your store name' : null,
              ),
              const SizedBox(height: 14),
              const Text('نوع النشاط (Activity Type):',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 10),
              _buildActivityGrid(),
            ],

            // ----- حقول خاصة بالـ Driver -----
            if (_selectedRole == 'Driver') ...[
              const SizedBox(height: 20),
              Text('Driver Preferences / تفضيلات التوصيل',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13)),
              const SizedBox(height: 10),
              const Text('نوع المركبة (Vehicle Type):',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 10),
              _buildVehicleGrid(),
            ],

            const SizedBox(height: 20),
            CustomTextField(
              controller: _emailController,
              label: 'Email Address / البريد الإلكتروني',
              hint: 'Enter your email',
              prefixIcon: const Icon(Icons.email_outlined),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter your email';
                if (!EmailValidator.validate(v)) return 'Please enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController,
              label: 'Password / كلمة المرور',
              hint: 'Create a password',
              obscureText: _obscurePassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter a password';
                if (v.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password / تأكيد كلمة المرور',
              hint: 'Repeat your password',
              obscureText: _obscureConfirmPassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              validator: (v) => (v != _passwordController.text) ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Sign Up',
              isLoading: isLoading,
              onPressed: () => _handleSignUp(authNotifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: _activityTypes.length,
      itemBuilder: (context, index) {
        final item = _activityTypes[index];
        final isSelected = _selectedActivity == item['key'];
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedActivity = item['key']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              // الإيموجي أصلًا ملون بطبيعته، فبس بنغمق الخلفية والبوردر عند الاختيار
              color: isSelected ? AppTheme.primaryColor.withOpacity(0.16) : Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${item['emoji']} ${item['label']}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected ? AppTheme.primaryColor : Colors.black87,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.6,
      ),
      itemCount: _vehicleTypes.length,
      itemBuilder: (context, index) {
        final item = _vehicleTypes[index];
        final isSelected = _selectedVehicle == item['key'];
        final Color vColor = item['color'] as Color; // اللون المميز لكل نوع مركبة

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedVehicle = item['key']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              // عند الاختيار: خلفية وبوردر بلون المركبة نفسه (مو أخضر عام) وأغمق شوي
              color: isSelected ? vColor.withOpacity(0.16) : Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? vColor : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // الأيقونة ملونة بلونها المميز دايمًا (مو رمادية)
                Icon(item['icon'] as IconData, size: 18, color: vColor),
                const SizedBox(width: 6),
                Text(
                  item['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? vColor : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _errorBanner(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            child: Text(error, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _handleSignUp(dynamic authNotifier) {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == 'Business' && _selectedActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your activity type')),
      );
      return;
    }
    if (_selectedRole == 'Driver' && _selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your vehicle type')),
      );
      return;
    }

    // ملاحظة: عدّل أسماء الباراميترات هون لتتوافق تمامًا مع authNotifier.signup
    // الموجودة عندك بمشروعك (businessType / storeName / vehicleType إلخ).
    authNotifier.signup(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      phone: _phoneController.text.trim(),
      role: _selectedRole,
      businessType: _selectedRole == 'Business' ? _selectedActivity : null,
      // storeName: _selectedRole == 'Business' ? _storeNameController.text.trim() : null,
      // vehicleType: _selectedRole == 'Driver' ? _selectedVehicle : null,
    );
  }
}