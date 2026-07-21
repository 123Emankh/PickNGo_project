// lib/screens/admin/widgets/admin_simulation_tab.dart
//
// Delivery Simulation (توصية #6) - الأدمن يجرب سيناريو افتراضي (موقعي
// متجرين + عنوان زبون + فارق وقت بين الطلبين) ويشوف هل كانت الطلبات رح
// تنجمع، بنفس الإعدادات الحية الحالية (بدون ما يلمس بيانات حقيقية).
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_themes.dart';
import '../../../data/models/admin_models.dart';
import '../../../services/admin_service.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/location_picker_map.dart';

class AdminSimulationTab extends StatefulWidget {
  const AdminSimulationTab({super.key});

  @override
  State<AdminSimulationTab> createState() => _AdminSimulationTabState();
}

class _AdminSimulationTabState extends State<AdminSimulationTab> {
  static const Color brandColor = AppColors.brand;

  final _adminService = AdminService();
  final _timeCtrl = TextEditingController(text: '5');

  LatLng _storeA = const LatLng(31.9539, 35.9106);
  LatLng _storeB = const LatLng(31.9550, 35.9120);
  LatLng _customer = const LatLng(31.9600, 35.9150);

  bool _isRunning = false;
  GroupingSimulationResult? _result;
  String? _error;

  @override
  void dispose() {
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final minutes = double.tryParse(_timeCtrl.text.trim());
    if (minutes == null || minutes < 0) {
      setState(() {
        _error = 'أدخل فارق وقت صحيح (دقايق، رقم موجب)';
        _result = null;
      });
      return;
    }

    setState(() {
      _isRunning = true;
      _error = null;
    });

    final result = await _adminService.simulateGrouping(
      storeALat: _storeA.latitude,
      storeALng: _storeA.longitude,
      storeBLat: _storeB.latitude,
      storeBLng: _storeB.longitude,
      customerLat: _customer.latitude,
      customerLng: _customer.longitude,
      timeDifferenceMinutes: minutes,
    );

    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _result = result;
      _error = result == null ? 'تعذر تشغيل المحاكاة - تأكد من الاتصال بالسيرفر' : null;
    });
  }

  String _ruleLabel(String rule) {
    switch (rule) {
      case 'same_customer':
        return 'نفس الزبون';
      case 'store_distance':
        return 'المتاجر بمسافة مسموحة';
      case 'delivery_distance':
        return 'التوصيل بمسافة مسموحة';
      case 'time_window':
        return 'خلال الوقت المسموح';
      default:
        return rule;
    }
  }

  Widget _buildLocationPicker(String label, LatLng value, ValueChanged<LatLng> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        const SizedBox(height: 6),
        LocationPickerMap(initialCenter: value, onLocationSelected: onChanged),
      ],
    );
  }

  Widget _factRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildResultCard(GroupingSimulationResult result) {
    final ok = result.willGroup;
    final color = ok ? AppColors.success : AppColors.error;
    final allRules = {...result.rulesSatisfied, ...result.rulesFailed}.toList();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.cancel, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ok ? 'Orders will be grouped' : "Orders won't be grouped",
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _factRow(
            'مسافة المتاجر',
            result.storeDistanceKm != null ? '${(result.storeDistanceKm! * 1000).round()} م' : '-',
          ),
          _factRow(
            'مسافة التوصيل',
            result.deliveryDistanceKm != null ? '${(result.deliveryDistanceKm! * 1000).round()} م' : '-',
          ),
          _factRow('الفارق الزمني', '${result.timeDifferenceMinutes} د'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: allRules.map((rule) {
              final satisfied = result.rulesSatisfied.contains(rule);
              final ruleColor = satisfied ? AppColors.success : AppColors.error;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ruleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(satisfied ? Icons.check : Icons.close, size: 12, color: ruleColor),
                    const SizedBox(width: 4),
                    Text(_ruleLabel(rule), style: TextStyle(fontSize: 11, color: ruleColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'جرّب سيناريو افتراضي: حدد موقعي متجرين وعنوان الزبون والفارق الزمني بين الطلبين، وشوف هل كانت رح تنجمع بنفس إعدادات لوحة الأدمن الحالية.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          _buildLocationPicker('متجر A', _storeA, (p) => setState(() => _storeA = p)),
          const SizedBox(height: 14),
          _buildLocationPicker('متجر B', _storeB, (p) => setState(() => _storeB = p)),
          const SizedBox(height: 14),
          _buildLocationPicker('عنوان الزبون', _customer, (p) => setState(() => _customer = p)),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _timeCtrl,
            label: 'الفارق الزمني بين الطلبين (دقائق)',
            hint: '5',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isRunning ? null : _run,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isRunning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Run Simulation', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
            ),
          if (_result != null) _buildResultCard(_result!),
        ],
      ),
    );
  }
}
