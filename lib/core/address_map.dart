import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'common.dart';

/// Bahrain cities offered on the address forms.
const bahrainCities = [
  'المنامة',
  'المحرق',
  'الرفاع',
  'مدينة عيسى',
  'مدينة حمد',
  'سترة',
  'عالي',
  'البديع',
  'الحد',
  'جدحفص',
  'مدينة زايد',
  'سلماباد',
  'توبلي',
  'الزلاق',
  'عوالي',
  'سار',
  'الجفير',
  'جزر أمواج',
  'ديار المحرق',
  'مدينة سلمان',
];

const bahrainCenter = LatLng(26.0667, 50.5577);

/// The device's current position (GPS on phones, browser location on the web).
/// Throws an Arabic message when location is off or not allowed.
Future<LatLng> currentLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('خدمة الموقع مقفلة في جهازك، فعّلها وحاول مرة ثانية');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    throw Exception('اسمح للتطبيق باستخدام موقعك من إعدادات الجهاز');
  }
  final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 20)));
  return LatLng(p.latitude, p.longitude);
}

/// Locates a Bahrain address. Tries the server geocoder first (Google Maps, when a
/// key is configured), then OpenStreetMap from the most precise wording to the broadest.
Future<LatLng?> geocodeBahrain(
    {String? building,
    String? block,
    String? road,
    String? area,
    String? city}) async {
  try {
    final r = await sb.functions.invoke('geocode', body: {
      'building': building,
      'road': road,
      'block': block,
      'area': area,
      'city': city,
    });
    final d = r.data;
    if (d is Map && d['ok'] == true && d['lat'] is num && d['lng'] is num) {
      return LatLng((d['lat'] as num).toDouble(), (d['lng'] as num).toDouble());
    }
  } catch (_) {}
  String j(List<String?> p) =>
      p.where((x) => (x ?? '').trim().isNotEmpty).join(', ');
  final hasRoad = (road ?? '').isNotEmpty, hasBlock = (block ?? '').isNotEmpty;
  final tries = <String>{
    if (hasRoad && hasBlock) j(['Road $road', 'Block $block', area, 'Bahrain']),
    if (hasRoad) j(['Road $road', area, 'Bahrain']),
    if (hasBlock) j(['Block $block', 'Bahrain']),
    if (hasBlock) j(['مجمع $block', area]),
    j([area, city]),
    j([city]),
  }..removeWhere((q) => q.isEmpty);
  for (final q in tries) {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'countrycodes': 'bh',
        'limit': '1',
        'accept-language': 'ar',
        'q': q,
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) continue;
      final list = jsonDecode(r.body);
      if (list is List && list.isNotEmpty) {
        final lat = double.tryParse('${list.first['lat']}');
        final lon = double.tryParse('${list.first['lon']}');
        if (lat != null && lon != null) return LatLng(lat, lon);
      }
    } catch (_) {}
  }
  return null;
}

/// A map with one pin. Tapping the map moves the pin when [onPick] is set.
class AddressMap extends StatefulWidget {
  const AddressMap(
      {super.key,
      required this.point,
      this.onPick,
      this.height = 240,
      this.color = const Color(0xFF8E2442)});
  final LatLng? point;
  final ValueChanged<LatLng>? onPick;
  final double height;
  final Color color;
  @override
  State<AddressMap> createState() => _AddressMapState();
}

class _AddressMapState extends State<AddressMap> {
  final ctrl = MapController();
  bool ready = false;

  @override
  void didUpdateWidget(covariant AddressMap old) {
    super.didUpdateWidget(old);
    final p = widget.point;
    if (ready && p != null && p != old.point) {
      ctrl.move(p, ctrl.camera.zoom < 15 ? 16 : ctrl.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.point;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: widget.height,
        child: Stack(children: [
          FlutterMap(
            mapController: ctrl,
            options: MapOptions(
              initialCenter: p ?? bahrainCenter,
              initialZoom: p == null ? 10.5 : 16,
              onMapReady: () => ready = true,
              onTap: widget.onPick == null
                  ? null
                  : (_, latlng) => widget.onPick!(latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'app.dhabaeh.bahrain',
              ),
              if (p != null)
                MarkerLayer(markers: [
                  Marker(
                    point: p,
                    width: 46,
                    height: 46,
                    alignment: Alignment.topCenter,
                    child: Icon(Icons.location_on,
                        size: 46,
                        color: widget.color,
                        shadows: const [
                          Shadow(color: Colors.black38, blurRadius: 6)
                        ]),
                  ),
                ]),
            ],
          ),
          PositionedDirectional(
            bottom: 6,
            end: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .8),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('© OpenStreetMap',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(fontSize: 10, color: Colors.black54)),
            ),
          ),
        ]),
      ),
    );
  }
}
