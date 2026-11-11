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

/// Bahrain's four governorates and the main cities in each, with an approximate
/// centre point used to drop the first pin before the admin adjusts it.
const bahrainGovernorates = <String, Map<String, LatLng>>{
  'محافظة العاصمة': {
    'المنامة': LatLng(26.2235, 50.5876),
    'الجفير': LatLng(26.2110, 50.6050),
    'السيف': LatLng(26.2340, 50.5330),
    'العدلية': LatLng(26.2130, 50.5900),
    'توبلي': LatLng(26.1950, 50.5630),
    'سترة': LatLng(26.1540, 50.6200),
  },
  'محافظة المحرق': {
    'المحرق': LatLng(26.2572, 50.6119),
    'الحد': LatLng(26.2460, 50.6540),
    'عراد': LatLng(26.2550, 50.6350),
    'قلالي': LatLng(26.2730, 50.6510),
    'البسيتين': LatLng(26.2700, 50.6050),
    'ديار المحرق': LatLng(26.2900, 50.6300),
    'جزر أمواج': LatLng(26.2930, 50.6630),
  },
  'المحافظة الشمالية': {
    'البديع': LatLng(26.2170, 50.4480),
    'مدينة حمد': LatLng(26.1150, 50.5070),
    'جدحفص': LatLng(26.2180, 50.5480),
    'سار': LatLng(26.1880, 50.4870),
    'الدراز': LatLng(26.2190, 50.4760),
    'مدينة سلمان': LatLng(26.2400, 50.4800),
    'سلماباد': LatLng(26.1840, 50.5300),
    'عالي': LatLng(26.1550, 50.5300),
    'مدينة زايد': LatLng(26.1600, 50.5100),
  },
  'المحافظة الجنوبية': {
    'الرفاع': LatLng(26.1300, 50.5550),
    'مدينة عيسى': LatLng(26.1736, 50.5478),
    'عوالي': LatLng(26.0870, 50.5480),
    'الزلاق': LatLng(26.0480, 50.4840),
    'عسكر': LatLng(26.0560, 50.6150),
  },
};

/// Looks up a known Bahrain city: (governorate, centre) or null.
(String, LatLng)? bahrainPlace(String city) {
  for (final g in bahrainGovernorates.entries) {
    final p = g.value[city.trim()];
    if (p != null) return (g.key, p);
  }
  return null;
}
