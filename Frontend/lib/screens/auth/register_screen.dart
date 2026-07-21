// lib/screens/auth/register_screen.dart
//
// شاشة مخصصة موحدة: Login/Register toggle + اختيار نوع الحساب
// (Customer / Business / Driver) + فورم ديناميكي يتغير حسب النوع،
// مطابقة للتصميم المطلوب بالصور.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:email_validator/email_validator.dart';
import '../../providers/auth_provider.dart';
import '../../services/company_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_themes.dart';
import '../../core/i18n/app_localizations.dart';
import 'verify_otp_screen.dart';
import 'forgot_password_screen.dart';
import '../post_auth_router.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  // true = يفتح مباشرة على تاب Login، false = يفتح على تاب Register (الافتراضي)
  final bool startOnLogin;
  // نوع الحساب المفتوح افتراضيًا بتاب التسجيل (Customer | Business | Driver) -
  // بيسمح لأزرار زي "انضم كمطعم"/"انضم كسائق" إنها توديك مباشرة عالتاب الصح.
  final String initialRole;

  const RegisterScreen({
    super.key,
    this.startOnLogin = false,
    this.initialRole = 'Customer',
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final AnimationController _routeController;

  late bool _isLoginMode;
  late String _selectedRole; // Customer | Business | Driver
  String? _selectedVehicle; // لِـ Driver
  String? _selectedCompanyId; // لِـ Driver: انضمام اختياري لشركة توصيل معتمدة
  List<DeliveryCompanyModel> _companies = [];
  bool _loadingCompanies = false;

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // كل نوع مركبة إله لون مميز خاص فيه (بدل ما تكون كلها رمادية)
  final List<Map<String, dynamic>> _vehicleTypes = const [
    {
      'key': 'bicycle',
      'label': 'Bicycle',
      'icon': Icons.pedal_bike,
      'color': Color(0xFF1E88E5),
    },
    {
      'key': 'motorcycle',
      'label': 'Motorcycle',
      'icon': Icons.two_wheeler,
      'color': Color(0xFFE53935),
    },
    {
      'key': 'car',
      'label': 'Car',
      'icon': Icons.directions_car,
      'color': Color(0xFF43A047),
    },
    {
      'key': 'van',
      'label': 'Van',
      'icon': Icons.airport_shuttle,
      'color': Color(0xFFFB8C00),
    },
    {
      'key': 'company',
      'label': 'Company',
      'icon': Icons.business,
      'color': Color(0xFF6D4C41),
    },
  ];

  @override
  void initState() {
    super.initState();
    _isLoginMode = widget.startOnLogin;
    _selectedRole = widget.initialRole;
    _loadCompanies();
    _routeController = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  Future<void> _loadCompanies() async {
    setState(() => _loadingCompanies = true);
    final result = await CompanyService().getApprovedCompanies();
    if (!mounted) return;
    setState(() {
      _companies = result.companies;
      _loadingCompanies = false;
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    // التوجيه التلقائي بعد نجاح تسجيل الدخول الحقيقي (لما يتربط الباك إند)
    if (authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PostAuthRouter()),
          (route) => false,
        );
      });
    }

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth > 900;
          if (!isWeb) {
            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: _buildFormColumn(authNotifier, authState),
                  ),
                ),
              ),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _buildBrandPanel()),
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: _buildFormColumn(authNotifier, authState),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormColumn(dynamic authNotifier, dynamic authState) {
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        _buildLoginRegisterToggle(),
        const SizedBox(height: 20),
        if (!_isLoginMode) ...[
          _buildAccountTypeSelector(),
          const SizedBox(height: 20),
        ],
        _isLoginMode
            ? _buildLoginCard(authNotifier, authState.isLoading, authState.error)
            : _buildRegisterCard(authNotifier, authState.isLoading, authState.error),
      ],
    );
  }

  // ---------- لوحة البراند العريضة (ديسكتوب/ويب فقط) ----------
  Widget _buildBrandPanel() {
    final locale = Localizations.localeOf(context);
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandDark, AppColors.brand],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.t(locale, 'register_app_title'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _routeController,
                builder: (context, _) => CustomPaint(
                  size: const Size(double.infinity, 340),
                  painter: _BrandRoutePainter(progress: _routeController.value),
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t(locale, 'register_brand_headline'),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.t(locale, 'register_brand_subtitle'),
                  style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85), height: 1.5),
                ),
              ],
            ),
          ),
        ],
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
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.local_shipping_outlined,
            size: 40,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.t(Localizations.localeOf(context), 'register_app_title'),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F5132),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.t(Localizations.localeOf(context), 'register_tagline'),
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
          Expanded(
            child: _toggleTab(
              AppLocalizations.t(Localizations.localeOf(context), 'register_tab_login'),
              _isLoginMode,
              () => setState(() => _isLoginMode = true),
            ),
          ),
          Expanded(
            child: _toggleTab(
              AppLocalizations.t(Localizations.localeOf(context), 'register_tab_register'),
              !_isLoginMode,
              () => setState(() => _isLoginMode = false),
            ),
          ),
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
          color: active ? Theme.of(context).cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.t(Localizations.localeOf(context), 'register_choose_account_type'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _accountTypeCard(
                  role: 'Customer',
                  title: AppLocalizations.t(Localizations.localeOf(context), 'register_role_customer_title'),
                  subtitle: AppLocalizations.t(Localizations.localeOf(context), 'register_role_customer_sub'),
                  icon: Icons.shopping_cart_outlined,
                  color: const Color(0xFF2E7D32), // أخضر
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _accountTypeCard(
                  role: 'Business',
                  title: AppLocalizations.t(Localizations.localeOf(context), 'register_role_business_title'),
                  subtitle: AppLocalizations.t(Localizations.localeOf(context), 'register_role_business_sub'),
                  icon: Icons.storefront_outlined,
                  color: const Color(0xFFE65100), // برتقالي
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _accountTypeCard(
                  role: 'Driver',
                  title: AppLocalizations.t(Localizations.localeOf(context), 'register_role_driver_title'),
                  subtitle: AppLocalizations.t(Localizations.localeOf(context), 'register_role_driver_sub'),
                  icon: Icons.two_wheeler_outlined,
                  color: const Color(0xFF0288D1), // أزرق
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
    required Color color,
  }) {
    final isSelected = _selectedRole == role;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.16) : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey[600], size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
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
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.t(Localizations.localeOf(context), 'register_welcome_back'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (error != null) _errorBanner(error),
            CustomTextField(
              controller: _emailController,
              label: AppLocalizations.t(Localizations.localeOf(context), 'register_email_label'),
              hint: AppLocalizations.t(Localizations.localeOf(context), 'register_email_hint'),
              prefixIcon: const Icon(Icons.email_outlined),
              validator: (v) {
                if (v == null || v.isEmpty) return AppLocalizations.t(Localizations.localeOf(context), 'register_err_email_required');
                if (!EmailValidator.validate(v)) {
                  return AppLocalizations.t(Localizations.localeOf(context), 'register_err_email_invalid');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController,
              label: AppLocalizations.t(Localizations.localeOf(context), 'register_password_label'),
              hint: AppLocalizations.t(Localizations.localeOf(context), 'register_password_hint'),
              obscureText: _obscurePassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return AppLocalizations.t(Localizations.localeOf(context), 'register_err_password_required');
                return null;
              },
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: Text(
                  AppLocalizations.t(Localizations.localeOf(context), 'register_forgot_password'),
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            CustomButton(
              text: AppLocalizations.t(Localizations.localeOf(context), 'register_button_login'),
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
  Widget _buildRegisterCard(
    dynamic authNotifier,
    bool isLoading,
    String? error,
  ) {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${AppLocalizations.t(Localizations.localeOf(context), 'register_create_account')} (${_selectedRole.toUpperCase()})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (error != null) _errorBanner(error),

            CustomTextField(
              controller: _fullNameController,
              label: AppLocalizations.t(Localizations.localeOf(context), 'register_fullname_label'),
              hint: AppLocalizations.t(Localizations.localeOf(context), 'register_fullname_hint'),
              prefixIcon: const Icon(Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppLocalizations.t(Localizations.localeOf(context), 'register_err_name_required')
                  : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _phoneController,
              label: AppLocalizations.t(Localizations.localeOf(context), 'register_phone_label'),
              hint: AppLocalizations.t(Localizations.localeOf(context), 'register_phone_hint'),
              prefixIcon: const Icon(Icons.phone_outlined),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.isEmpty)
                  ? AppLocalizations.t(Localizations.localeOf(context), 'register_err_phone_required')
                  : null,
            ),

            // ملاحظة: تفاصيل المتجر (الفئة، العنوان، أسعار التوصيل...) صارت
            // بشاشة منفصلة (StoreSetupScreen) تظهر بعد نجاح التسجيل مباشرة،
            // مش هون - عشان نتجنب تكرار جمع نفس المعلومات مرتين.

            // ----- حقول خاصة بالـ Driver -----
            if (_selectedRole == 'Driver') ...[
              const SizedBox(height: 20),
              Text(
                AppLocalizations.t(Localizations.localeOf(context), 'register_driver_preferences'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.t(Localizations.localeOf(context), 'register_vehicle_type_label'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              _buildVehicleGrid(),
              if (_selectedVehicle != null && _selectedVehicle != 'company') ...[
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.t(Localizations.localeOf(context), 'register_join_company_label'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 10),
                _buildCompanyDropdown(),
              ],
            ],

            const SizedBox(height: 20),
            CustomTextField(
              controller: _emailController,
              label: AppLocalizations.t(Localizations.localeOf(context), 'register_email_label'),
              hint: AppLocalizations.t(Localizations.localeOf(context), 'register_email_hint'),
              prefixIcon: const Icon(Icons.email_outlined),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return AppLocalizations.t(Localizations.localeOf(context), 'register_err_email_required');
                if (!EmailValidator.validate(v)) {
                  return AppLocalizations.t(Localizations.localeOf(context), 'register_err_email_invalid');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController,
              label: AppLocalizations.t(Localizations.localeOf(context), 'register_password_label'),
              hint: AppLocalizations.t(Localizations.localeOf(context), 'register_password_create_hint'),
              obscureText: _obscurePassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return AppLocalizations.t(Localizations.localeOf(context), 'register_err_password_required_signup');
                if (v.length < 6) {
                  return AppLocalizations.t(Localizations.localeOf(context), 'register_err_password_length');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _confirmPasswordController,
              label: AppLocalizations.t(Localizations.localeOf(context), 'register_confirm_password_label'),
              hint: AppLocalizations.t(Localizations.localeOf(context), 'register_repeat_password_hint'),
              obscureText: _obscureConfirmPassword,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              validator: (v) => (v != _passwordController.text)
                  ? AppLocalizations.t(Localizations.localeOf(context), 'register_err_password_mismatch')
                  : null,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: AppLocalizations.t(Localizations.localeOf(context), 'register_button_signup'),
              isLoading: isLoading,
              onPressed: () => _handleSignUp(authNotifier),
            ),
          ],
        ),
      ),
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
        final Color vColor =
            item['color'] as Color; // اللون المميز لكل نوع مركبة

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedVehicle = item['key']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              // عند الاختيار: خلفية وبوردر بلون المركبة نفسه (مو أخضر عام) وأغمق شوي
              color: isSelected ? vColor.withValues(alpha: 0.16) : Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? vColor : Theme.of(context).dividerColor,
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
                  AppLocalizations.t(Localizations.localeOf(context), 'register_vehicle_${item['key']}'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? vColor : Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompanyDropdown() {
    if (_loadingCompanies) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_companies.isEmpty) return const SizedBox.shrink();

    return DropdownButtonFormField<String>(
      initialValue: _selectedCompanyId,
      decoration: InputDecoration(
        hintText: AppLocalizations.t(Localizations.localeOf(context), 'register_join_company_hint'),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(AppLocalizations.t(Localizations.localeOf(context), 'register_join_company_none')),
        ),
        ..._companies.map(
          (c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
        ),
      ],
      onChanged: (value) => setState(() => _selectedCompanyId = value),
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
            child: Text(
              error,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSignUp(dynamic authNotifier) {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == 'Driver' && _selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.t(Localizations.localeOf(context), 'register_err_select_vehicle'))),
      );
      return;
    }

    // الباك إند بيقبل بس Customer/Restaurant/Driver/Admin كـ role (شوفي
    // backend/src/models/User.js) - "Business" هو مجرد لايبل بالواجهة.
    final apiRole = _selectedRole == 'Business' ? 'Restaurant' : _selectedRole;

    // ملاحظة: business_type مزدوجة الاستخدام بالباك إند (شوفي User.js) -
    // فئة العمل للـ Restaurant، ونوع المركبة/الأسطول للـ Driver. القيمة
    // الحرفية 'Fleet / Company' هي اللي بتفعّل حالة Pending + تأهّل الحساب
    // يصير خيار شركة توصيل يقدر سائقين تانيين ينضموا إلها (authController.js).
    String? driverBusinessType;
    if (_selectedRole == 'Driver' && _selectedVehicle != null) {
      driverBusinessType = _selectedVehicle == 'company'
          ? 'Fleet / Company'
          : _vehicleTypes.firstWhere((v) => v['key'] == _selectedVehicle)['label'] as String;
    }

    authNotifier.signup(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      phone: _phoneController.text.trim(),
      role: apiRole,
      businessType: _selectedRole == 'Business' ? 'Restaurant' : driverBusinessType,
      companyId: _selectedRole == 'Driver' && _selectedVehicle != 'company'
          ? _selectedCompanyId
          : null,
    );
  }
}

// ---------- رسمة تجريدية للوحة البراند: مسار منقط + 3 نقاط + نقطة متحركة ----------
class _BrandRoutePainter extends CustomPainter {
  final double progress;
  _BrandRoutePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width * 0.12, size.height * 0.08);
    final mid = Offset(size.width * 0.55, size.height * 0.5);
    final end = Offset(size.width * 0.85, size.height * 0.94);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(size.width * 0.1, size.height * 0.55, mid.dx, mid.dy)
      ..quadraticBezierTo(size.width * 0.95, size.height * 0.45, end.dx, end.dy);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final metrics = path.computeMetrics().toList();
    for (final metric in metrics) {
      double distance = 0;
      const dashLength = 10.0;
      const gapLength = 8.0;
      while (distance < metric.length) {
        final next = (distance + dashLength).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next.toDouble()), linePaint);
        distance += dashLength + gapLength;
      }
    }

    _dot(canvas, start, 7, Colors.white.withValues(alpha: 0.8));
    _dot(canvas, mid, 9, AppColors.accent);
    _dot(canvas, end, 7, Colors.white.withValues(alpha: 0.8));

    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      final tangent = metric.getTangentForOffset(metric.length * progress);
      if (tangent != null) {
        _dot(canvas, tangent.position, 6, Colors.white);
      }
    }
  }

  void _dot(Canvas canvas, Offset point, double radius, Color color) {
    canvas.drawCircle(point, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BrandRoutePainter oldDelegate) => oldDelegate.progress != progress;
}
