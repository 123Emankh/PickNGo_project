// lib/screens/admin/widgets/admin_live_map_tab.dart
//
// خريطة تفاعلية حية للوحة الأدمن (توصية #2) - متاجر معتمدة + سائقين أونلاين
// + خطوط سير الرحلات المجمّعة النشطة. نفس نمط FlutterMap المستخدم بـ
// order_tracking_screen.dart/location_picker_map.dart، بس بتحدّث نفسها كل
// فترة (polling) بدل ما تكون خريطة نقطة واحدة ثابتة.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_themes.dart';
import '../../../data/models/admin_models.dart';
import '../../../services/admin_service.dart';

class AdminLiveMapTab extends StatefulWidget {
  const AdminLiveMapTab({super.key});

  @override
  State<AdminLiveMapTab> createState() => _AdminLiveMapTabState();
}

class _AdminLiveMapTabState extends State<AdminLiveMapTab> {
  static const Color brandColor = AppColors.brand;

  final _adminService = AdminService();
  Timer? _pollTimer;
  AdminLiveMapData _data = AdminLiveMapData.empty();
  bool _isLoading = true;

  static const List<Color> _categoryPalette = [
    Color(0xFFE94E3C), // أحمر - بيتزا مثلاً
    Color(0xFF17A398), // أخضر مزرق - صيدليات
    Color(0xFFF5A623), // برتقالي - برجر
    Color(0xFF7C4DFF), // بنفسجي
    Color(0xFF2196F3), // أزرق
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final data = await _adminService.getLiveMapData();
    if (!mounted) return;
    setState(() {
      _data = data;
      _isLoading = false;
    });
  }

  Color _colorForCategory(String? category) {
    if (category == null || category.isEmpty) return _categoryPalette.last;
    return _categoryPalette[category.hashCode.abs() % _categoryPalette.length];
  }

  IconData _iconForCategory(String? category) {
    final c = (category ?? '').toLowerCase();
    if (c.contains('pharma') || c.contains('صيدل')) return Icons.local_pharmacy;
    if (c.contains('pizza') || c.contains('بيتزا')) return Icons.local_pizza;
    if (c.contains('burger') || c.contains('برجر')) return Icons.lunch_dining;
    if (c.contains('grocery') || c.contains('سوبر') || c.contains('بقال')) return Icons.local_grocery_store;
    if (c.contains('cafe') || c.contains('قهوة') || c.contains('كوفي')) return Icons.local_cafe;
    return Icons.storefront;
  }

  LatLng _initialCenter() {
    if (_data.stores.isNotEmpty) {
      return LatLng(_data.stores.first.lat, _data.stores.first.lng);
    }
    if (_data.drivers.isNotEmpty) {
      return LatLng(_data.drivers.first.lat, _data.drivers.first.lng);
    }
    return const LatLng(31.9, 35.2); // مركز افتراضي (عمّان تقريبًا)
  }

  Marker _pin(LatLng point, Color color, IconData icon, {double size = 30}) {
    return Marker(
      point: point,
      width: size + 8,
      height: size + 8,
      child: Icon(icon, color: color, size: size),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    for (final s in _data.stores) {
      markers.add(_pin(LatLng(s.lat, s.lng), _colorForCategory(s.category), _iconForCategory(s.category)));
    }
    for (final d in _data.drivers) {
      final color = d.status == 'Available' ? brandColor : Colors.grey;
      markers.add(_pin(LatLng(d.lat, d.lng), color, Icons.delivery_dining, size: 28));
    }
    return markers;
  }

  List<Polyline> _buildRoutes() {
    final polylines = <Polyline>[];
    for (final g in _data.activeGroups) {
      final points = <LatLng>[];
      if (g.driver != null) points.add(LatLng(g.driver!.lat, g.driver!.lng));
      final stops = [...g.stops]..sort((a, b) => a.pickupSequence.compareTo(b.pickupSequence));
      points.addAll(stops.map((s) => LatLng(s.lat, s.lng)));
      if (points.length >= 2) {
        polylines.add(Polyline(points: points, color: brandColor.withValues(alpha: 0.55), strokeWidth: 3));
      }
    }
    return polylines;
  }

  Widget _legendChip(Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final categories = _data.stores.map((s) => s.category).whereType<String>().toSet().toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in categories) _legendChip(_colorForCategory(category), _iconForCategory(category), category),
        _legendChip(brandColor, Icons.delivery_dining, 'سائق متاح (${_data.drivers.where((d) => d.status == 'Available').length})'),
        _legendChip(Colors.grey, Icons.delivery_dining, 'سائق مشغول/غير متصل'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(60),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildLegend()),
              IconButton(
                tooltip: 'تحديث',
                icon: const Icon(Icons.refresh),
                onPressed: () => _load(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_data.stores.length} متجر · ${_data.drivers.length} سائق أونلاين · ${_data.activeGroups.length} رحلة مجمّعة نشطة',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 460,
              child: FlutterMap(
                options: MapOptions(initialCenter: _initialCenter(), initialZoom: 12),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.pickngo.app',
                  ),
                  PolylineLayer(polylines: _buildRoutes()),
                  MarkerLayer(markers: _buildMarkers()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
