// lib/screens/profile/profile_screen.dart
//
// شاشة عرض/تعديل بيانات المستخدم المسجل دخوله. بتستخدم authProvider.getProfile
// و authProvider.updateProfile الموجودين مسبقًا. مشتركة بين كل الأدوار
// (Customer/Restaurant/Driver/Admin) - نفس الفرع الشرطي القديم (role == 'Driver')
// بيتوسّع هون لعرض إحصائيات أداء حقيقية للسائق فقط، وباقي الشاشة (الأفاتار
// القابل للتغيير، زر إعدادات الأمان) صار متاح لكل الأدوار بالتساوي لأنه بيعتمد
// بالكامل على endpoints/شاشات موجودة أصلاً (uploadAvatar، ChangePasswordScreen)
// وما كانت متاحة إلا من CustomerSettingsScreen فقط.
//
// ✅ ما تمت إضافته: تقييم سائق أو "هدف شهري" - ما في نظام تقييم سائقين ولا
// أهداف/حصص مبنية بالمشروع (تحقّقت من الباك إند بالكامل) - أي رقم من هيك
// كان رح يكون مفبرك، فاستُبعد بالكامل بدل ما يُختلق.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/api_constants.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/analytics_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/driver_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/role_drawer.dart';
import '../favorites/favorites_screen.dart';
import '../settings/change_password_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _uploadingAvatar = false;

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();

  // ✅ إحصائيات أداء السائق - نفس DriverService.getMyPerformance() المستخدمة
  // أصلاً بشاشة "أدائي" ولوحة السائق، بس تُحمَّل هون بس لما الدور Driver
  final _driverService = DriverService();
  DriverPerformanceModel? _driverPerformance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).getProfile();
      if (ref.read(authProvider).user?.role == 'Driver') {
        _loadDriverPerformance();
      }
    });
  }

  Future<void> _loadDriverPerformance() async {
    final performance = await _driverService.getMyPerformance();
    if (!mounted) return;
    setState(() => _driverPerformance = performance);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  void _startEditing(dynamic user) {
    _fullNameController.text = user.fullName;
    _phoneController.text = user.phone ?? '';
    _addressController.text = user.locationAddress ?? '';
    _cityController.text = user.city ?? '';
    _regionController.text = user.region ?? '';
    setState(() => _isEditing = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final locale = Localizations.localeOf(context);
    await ref.read(authProvider.notifier).updateProfile(
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
          locationAddress: _addressController.text.trim(),
          city: _cityController.text.trim(),
          region: _regionController.text.trim(),
        );
    if (!mounted) return;
    final error = ref.read(authProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? AppLocalizations.t(locale, 'profile_update_success')
              : AppLocalizations.t(locale, 'profile_update_failed'),
        ),
      ),
    );
    if (error == null) setState(() => _isEditing = false);
  }

  // ✅ نفس تدفق CustomerSettingsScreen._pickAvatar بالضبط (image_picker →
  // authProvider.uploadAvatar → نفس /api/auth/profile/avatar) - هون بس صار
  // متاح لكل الأدوار (كان محصور بشاشة إعدادات الزبون بس).
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
          AppLocalizations.t(locale, success ? 'settings_avatar_updated' : 'settings_avatar_update_failed'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // ✅ شاشة مشتركة بين كل الأدوار - الهيدر الموحّد الجديد (MainLayout/
    // AppHeader) مبني خصيصًا للزبون، فما لازم يظهر لغير الأدوار التانية.
    // لوحات Admin/Driver/Business لازم تضل بنفس AppBar+Drawer الحالي تمامًا.
    if (user?.role == 'Customer') {
      return MainLayout(
        builder: (context, isWeb, padding, width) =>
            _buildBody(context, user, showTitle: true),
      );
    }

    final locale = Localizations.localeOf(context);
    final drawer = roleDrawerFor(user?.role);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: drawer,
      appBar: AppBar(
        title: Text(AppLocalizations.t(locale, 'profile_title')),
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        elevation: 0,
        actions: [
          if (user != null && !_isEditing)
            TextButton(
              onPressed: () => _startEditing(user),
              child: Text(AppLocalizations.t(locale, 'profile_edit')),
            ),
          if (drawer != null)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
        ],
      ),
      body: _buildBody(context, user),
    );
  }

  Widget _buildBody(BuildContext context, dynamic user, {bool showTitle = false}) {
    final locale = Localizations.localeOf(context);
    if (user == null) return const Center(child: CircularProgressIndicator());

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                if (showTitle) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      AppLocalizations.t(locale, 'profile_title'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildAvatarHeader(locale, user),
                const SizedBox(height: 14),
                Text(
                  user.fullName,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(user.email, style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                if (!_isEditing) _buildActionButtons(locale, user),
                if (!_isEditing && user.role == 'Driver' && _driverPerformance != null) ...[
                  const SizedBox(height: 18),
                  _buildDriverStats(locale, _driverPerformance!),
                ],
                if (!_isEditing) const SizedBox(height: 18),
                if (!_isEditing) _buildMenuSection(locale),
                if (!_isEditing) const SizedBox(height: 16),
                _isEditing ? _buildEditForm(locale) : _buildReadOnlyView(locale, user),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarHeader(Locale locale, dynamic user) {
    final avatarUrl = ApiConstants.resolveImageUrl(user.profilePicture);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.brand, width: 2.5),
          ),
          child: CircleAvatar(
            radius: 46,
            backgroundColor: AppColors.brand.withValues(alpha: 0.1),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            onBackgroundImageError: avatarUrl != null ? (_, _) {} : null,
            child: avatarUrl == null
                ? Icon(Icons.person_outline, size: 44, color: AppColors.brand)
                : null,
          ),
        ),
        // ✅ شارة "تم التحقق" - user.isVerified حقيقي، مش عنصر ديكور
        if (user.isVerified)
          Positioned(
            bottom: 2,
            left: 2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
              ),
              child: const Icon(Icons.check, size: 12, color: Colors.white),
            ),
          ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Material(
            color: AppColors.brand,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _uploadingAvatar ? null : () => _pickAvatar(locale),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: _uploadingAvatar
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Locale locale, dynamic user) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.security_outlined, size: 17),
            label: Text(AppLocalizations.t(locale, 'settings_change_password')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brand,
              side: BorderSide(color: AppColors.brand),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: Text(AppLocalizations.t(locale, 'profile_edit')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            onPressed: () => _startEditing(user),
          ),
        ),
      ],
    );
  }

  // ✅ الرقمين الاتنين هون حقيقيين 100% (completed_orders و
  // avg_delivery_time_min من نفس رد /api/drivers/performance) - avgDeliveryTimeMin
  // ممكن يرجع null لو مافي عيّنة كافية بعد (avgDeliveryTimeSampleSize == 0)،
  // فبنخفي الكارت التاني كليًا بهالحالة بدل ما نعرض قيمة فاضية/صفر مضلِّلة.
  Widget _buildDriverStats(Locale locale, DriverPerformanceModel performance) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.local_shipping_rounded,
            value: '${performance.completedOrders}',
            label: AppLocalizations.t(locale, 'profile_total_deliveries'),
          ),
        ),
        if (performance.avgDeliveryTimeMin != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              icon: Icons.schedule_rounded,
              value: '${performance.avgDeliveryTimeMin}${AppLocalizations.t(locale, 'profile_min_short')}',
              label: AppLocalizations.t(locale, 'profile_avg_delivery_time'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _statCard({required IconData icon, required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, AppColors.brandDark],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 20),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildMenuSection(Locale locale) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        leading: Icon(Icons.favorite_border, color: AppColors.brand),
        title: Text(AppLocalizations.t(locale, 'profile_my_favorites')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FavoritesScreen()),
        ),
      ),
    );
  }

  Widget _buildReadOnlyView(Locale locale, dynamic user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.t(locale, 'profile_role'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              if (user.isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 13, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.t(locale, 'profile_verified'),
                        style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          _infoRow(Icons.phone_outlined, AppLocalizations.t(locale, 'profile_phone'), user.phone ?? '-'),
          _infoRow(Icons.location_on_outlined, AppLocalizations.t(locale, 'profile_address'), user.locationAddress ?? '-'),
          _infoRow(Icons.location_city_outlined, AppLocalizations.t(locale, 'profile_city'), user.city ?? '-'),
          _infoRow(Icons.map_outlined, AppLocalizations.t(locale, 'profile_region'), user.region ?? '-'),
          _infoRow(Icons.badge_outlined, AppLocalizations.t(locale, 'profile_role'), user.role),
          _infoRow(Icons.info_outline, AppLocalizations.t(locale, 'profile_status'), user.status),
          if (user.role == 'Driver' && user.businessType != null)
            _infoRow(
              Icons.two_wheeler_outlined,
              AppLocalizations.t(locale, 'profile_vehicle_type'),
              user.businessType == 'Fleet / Company'
                  ? AppLocalizations.t(locale, 'profile_vehicle_company')
                  : user.businessType,
              isLast: true,
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Colors.grey[500]),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12.5)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(Locale locale) {
    final authState = ref.watch(authProvider);
    return Form(
      key: _formKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _fullNameController,
              label: AppLocalizations.t(locale, 'profile_full_name'),
              hint: '',
              prefixIcon: const Icon(Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? AppLocalizations.t(locale, 'profile_err_name_required')
                  : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _phoneController,
              label: AppLocalizations.t(locale, 'profile_phone'),
              hint: '',
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _addressController,
              label: AppLocalizations.t(locale, 'profile_address'),
              hint: '',
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _cityController,
              label: AppLocalizations.t(locale, 'profile_city'),
              hint: '',
              prefixIcon: const Icon(Icons.location_city_outlined),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _regionController,
              label: AppLocalizations.t(locale, 'profile_region'),
              hint: '',
              prefixIcon: const Icon(Icons.map_outlined),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: AppLocalizations.t(locale, 'profile_save'),
              isLoading: authState.isLoading,
              onPressed: _save,
            ),
            const SizedBox(height: 10),
            CustomButton(
              text: AppLocalizations.t(locale, 'profile_cancel'),
              isOutlined: true,
              onPressed: () => setState(() => _isEditing = false),
            ),
          ],
        ),
      ),
    );
  }
}
