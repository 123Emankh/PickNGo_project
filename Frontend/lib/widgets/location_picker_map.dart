// lib/widgets/location_picker_map.dart
//
// خارطة تفاعلية بسيطة: اضغط على أي نقطة عشان تحط دبوس فيها (تُستخدم بفورم
// إنشاء المتجر لاختيار الموقع الفعلي بدل الاعتماد على مركز المدينة الثابت).
// نفس نمط FlutterMap/TileLayer المستخدم أصلاً بـ order_tracking_screen.dart.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/i18n/app_localizations.dart';

class LocationPickerMap extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final ValueChanged<LatLng> onLocationSelected;

  const LocationPickerMap({
    super.key,
    required this.initialCenter,
    this.initialZoom = 13,
    required this.onLocationSelected,
  });

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  late LatLng _picked = widget.initialCenter;

  // حدود تقريبية لفلسطين (الضفة الغربية + قطاع غزة) عشان الخارطة تضل بمنطقتنا
  static final _palestineBounds = LatLngBounds(
    const LatLng(29.4, 34.2),
    const LatLng(33.4, 35.7),
  );

  @override
  void didUpdateWidget(covariant LocationPickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCenter != widget.initialCenter) {
      setState(() => _picked = widget.initialCenter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: widget.initialCenter,
                initialZoom: widget.initialZoom,
                cameraConstraint: CameraConstraint.containCenter(
                  bounds: _palestineBounds,
                ),
                onTap: (tapPosition, point) {
                  setState(() => _picked = point);
                  widget.onLocationSelected(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.pickngo.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.redAccent,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.t(locale, 'locationpicker_hint'),
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
