// lib/screens/business/store_setup_screen.dart
//
// تحويل StoreOnboarding.jsx لفلاتر - فورم إنشاء متجر جديد لصاحب البزنس.
// بعد الإنشاء، المفروض ينتقل المستخدم لـ Store Dashboard (لسا رح نبنيها).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/location_picker_map.dart';
import '../../data/models/category_model.dart';
import '../../data/palestine_areas.dart';
import '../../providers/store_provider.dart';
import '../../services/store_service.dart';

class StoreSetupScreen extends ConsumerStatefulWidget {
  const StoreSetupScreen({super.key});

  @override
  ConsumerState<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends ConsumerState<StoreSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _openingTimeController = TextEditingController(text: '09:00');
  final _closingTimeController = TextEditingController(text: '22:00');
  final _logoUrlController = TextEditingController();
  final _feeInsideCityController = TextEditingController(text: '10');
  final _feeOutsideCityController = TextEditingController(text: '20');
  final _feeOccupiedController = TextEditingController(text: '70');
  final _minOrderController = TextEditingController();
  final _prepTimeController = TextEditingController(text: '30');

  String? _selectedCategoryId;
  String? _selectedCity;
  LatLng? _pickedLocation;
  bool _supportsDelivery = true;
  bool _supportsPickup = true;
  bool _saving = false;

  final _storeService = StoreService();
  List<CategoryModel> _categories = [];
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await _storeService.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _loadingCategories = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    _logoUrlController.dispose();
    _feeInsideCityController.dispose();
    _feeOutsideCityController.dispose();
    _feeOccupiedController.dispose();
    _minOrderController.dispose();
    _prepTimeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final locale = Localizations.localeOf(context);
    if (_selectedCategoryId == null ||
        _selectedCity == null ||
        !_formKey.currentState!.validate()) {
      if (_selectedCategoryId == null || _selectedCity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.t(locale, 'storesetup_required_fields'),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _saving = true);

    // city مش موجودة كـ region بالفورم، فبنشتقها من cityInfo. أما الموقع
    // (lat/lng) فبناخده من الدبوس يلي صاحب المتجر حطه بالخارطة، ولو ما لمسها
    // منرجع لمركز المدينة الافتراضي كـ fallback.
    final info = cityInfo[_selectedCity]!;
    final location = _pickedLocation ?? LatLng(info.$2, info.$3);

    final success = await ref.read(storeProvider.notifier).createStore(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      categoryId: _selectedCategoryId!,
      imageUrl: _logoUrlController.text.trim().isEmpty
          ? null
          : _logoUrlController.text.trim(),
      address: _addressController.text.trim(),
      locationLat: location.latitude,
      locationLng: location.longitude,
      city: _selectedCity!,
      region: info.$1,
      phone: _phoneController.text.trim(),
      openingTime: _openingTimeController.text.trim().isEmpty
          ? null
          : _openingTimeController.text.trim(),
      closingTime: _closingTimeController.text.trim().isEmpty
          ? null
          : _closingTimeController.text.trim(),
      minimumOrder: double.tryParse(_minOrderController.text.trim()),
      deliveryFeeInsideCity: double.tryParse(_feeInsideCityController.text.trim()),
      deliveryFeeOutsideCity: double.tryParse(_feeOutsideCityController.text.trim()),
      deliveryFeeOccupiedAreas: double.tryParse(_feeOccupiedController.text.trim()),
      prepTimeMinutes: int.tryParse(_prepTimeController.text.trim()),
      supportsDelivery: _supportsDelivery,
      supportsPickup: _supportsPickup,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.t(locale, 'storesetup_created_success'),
          ),
        ),
      );
      Navigator.pop(context);
    } else {
      final error = ref.read(storeProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? AppLocalizations.t(locale, 'storesetup_create_failed'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildFormCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final locale = Localizations.localeOf(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.storefront_outlined,
            size: 28,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppLocalizations.t(locale, 'storesetup_title'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.t(locale, 'storesetup_subtitle'),
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    final locale = Localizations.localeOf(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            controller: _nameController,
            label: AppLocalizations.t(locale, 'storesetup_field_name'),
            hint: AppLocalizations.t(locale, 'storesetup_hint_name'),
            prefixIcon: const Icon(Icons.storefront_outlined),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? AppLocalizations.t(locale, 'storesetup_error_name_required')
                : null,
          ),
          const SizedBox(height: 16),

          _fieldLabel(AppLocalizations.t(locale, 'storesetup_field_category')),
          const SizedBox(height: 6),
          _buildCategoryDropdown(),
          const SizedBox(height: 16),

          _fieldLabel(AppLocalizations.t(locale, 'storesetup_field_description')),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: _inputDecoration(
              hint: AppLocalizations.t(locale, 'storesetup_hint_description'),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _addressController,
                  label: AppLocalizations.t(locale, 'storesetup_field_address'),
                  hint: AppLocalizations.t(locale, 'storesetup_hint_address'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? AppLocalizations.t(
                          locale,
                          'storesetup_error_address_required',
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: _phoneController,
                  label: AppLocalizations.t(locale, 'storesetup_field_phone'),
                  hint: '+970…',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? AppLocalizations.t(
                          locale,
                          'storesetup_error_phone_required',
                        )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _openingTimeController,
                  label: AppLocalizations.t(
                    locale,
                    'storesetup_field_opening_hours',
                  ),
                  hint: AppLocalizations.t(
                    locale,
                    'storesetup_hint_opening_hours',
                  ),
                  prefixIcon: const Icon(Icons.access_time),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: _closingTimeController,
                  label: AppLocalizations.t(locale, 'bizdash_field_closing_time'),
                  hint: '22:00',
                  prefixIcon: const Icon(Icons.access_time_filled),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          CustomTextField(
            controller: _logoUrlController,
            label: AppLocalizations.t(locale, 'storesetup_field_logo_url'),
            hint: 'https://…',
            prefixIcon: const Icon(Icons.image_outlined),
          ),
          const SizedBox(height: 16),

          _fieldLabel(AppLocalizations.t(locale, 'storesetup_field_city')),
          const SizedBox(height: 6),
          _buildCityDropdown(),
          const SizedBox(height: 16),

          if (_selectedCity != null) ...[
            _fieldLabel(AppLocalizations.t(locale, 'storesetup_field_map_location')),
            const SizedBox(height: 6),
            LocationPickerMap(
              key: ValueKey(_selectedCity),
              initialCenter: _mapCenter,
              onLocationSelected: (point) =>
                  setState(() => _pickedLocation = point),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              Expanded(
                child: _numberField(
                  controller: _feeInsideCityController,
                  label: AppLocalizations.t(
                    locale,
                    'storesetup_fee_inside_city',
                  ),
                  hint: '10',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberField(
                  controller: _feeOutsideCityController,
                  label: AppLocalizations.t(
                    locale,
                    'storesetup_fee_outside_city',
                  ),
                  hint: '20',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberField(
                  controller: _feeOccupiedController,
                  label: AppLocalizations.t(locale, 'storesetup_fee_occupied'),
                  hint: '70',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _numberField(
                  controller: _minOrderController,
                  label: AppLocalizations.t(
                    locale,
                    'storesetup_field_min_order',
                  ),
                  hint: '0',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  controller: _prepTimeController,
                  label: AppLocalizations.t(
                    locale,
                    'storesetup_field_prep_time',
                  ),
                  hint: '30',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _switchTile(
                label: AppLocalizations.t(locale, 'storesetup_delivery'),
                value: _supportsDelivery,
                onChanged: (v) => setState(() => _supportsDelivery = v),
              ),
              const SizedBox(width: 24),
              _switchTile(
                label: AppLocalizations.t(locale, 'storesetup_pickup'),
                value: _supportsPickup,
                onChanged: (v) => setState(() => _supportsPickup = v),
              ),
            ],
          ),
          const SizedBox(height: 24),

          CustomButton(
            text: _saving
                ? AppLocalizations.t(locale, 'storesetup_creating')
                : AppLocalizations.t(locale, 'storesetup_create_store_btn'),
            isLoading: _saving,
            onPressed: _saving ? null : _submit,
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.t(locale, 'storesetup_review_note'),
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[400]
            : Colors.grey[600],
        fontSize: 13,
      ),
      filled: true,
      fillColor: Theme.of(context).scaffoldBackgroundColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration(hint: hint),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    if (_loadingCategories) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.centerLeft,
        child: const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final locale = Localizations.localeOf(context);
    final selectCategoryHint = AppLocalizations.t(
      locale,
      'storesetup_select_category',
    );
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      isExpanded: true,
      decoration: _inputDecoration(hint: selectCategoryHint),
      hint: Text(
        selectCategoryHint,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[400]
              : Colors.grey[600],
          fontSize: 13,
        ),
      ),
      items: _categories
          .map((cat) => DropdownMenuItem(value: cat.id, child: Text(cat.name)))
          .toList(),
      onChanged: (value) => setState(() => _selectedCategoryId = value),
    );
  }

  Widget _buildCityDropdown() {
    final locale = Localizations.localeOf(context);
    final selectCityHint = AppLocalizations.t(locale, 'storesetup_select_city');
    return DropdownButtonFormField<String>(
      initialValue: _selectedCity,
      isExpanded: true,
      decoration: _inputDecoration(hint: selectCityHint),
      hint: Text(
        selectCityHint,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[400]
              : Colors.grey[600],
          fontSize: 13,
        ),
      ),
      items: palestineAreas
          .map((city) => DropdownMenuItem(value: city, child: Text(city)))
          .toList(),
      onChanged: (value) => setState(() {
        _selectedCity = value;
        _pickedLocation = null; // نرجع لمركز المدينة الجديدة لحد ما يحدد دبوس جديد
      }),
    );
  }

  LatLng get _mapCenter {
    if (_pickedLocation != null) return _pickedLocation!;
    final info = _selectedCity != null ? cityInfo[_selectedCity] : null;
    return info != null ? LatLng(info.$2, info.$3) : const LatLng(31.95, 35.2);
  }

  Widget _switchTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.primaryColor,
        ),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
