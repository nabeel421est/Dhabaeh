import 'package:flutter/material.dart' hide Text;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/address_map.dart';
import '../core/brand.dart';
import '../core/common.dart';
import '../core/driver_chat.dart';
import '../core/i18n.dart';
import '../core/ttext.dart';

LatLng? _at(Map? m) {
  if (m == null || m['lat'] == null || m['lng'] == null) return null;
  return LatLng(toNum(m['lat']).toDouble(), toNum(m['lng']).toDouble());
}

double kmBetween(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b) / 1000;

String kmText(double km) => km < 1
    ? '${(km * 1000).round()} ${tr('م')}'
    : '${km.toStringAsFixed(km < 10 ? 1 : 0)} ${tr('كم')}';

/// Nearest available driver to each store that has a location.
typedef StoreLink = ({
  Map<String, dynamic> store,
  Map<String, dynamic> driver,
  double km
});

List<StoreLink> nearestLinks(List<Map<String, dynamic>> stores,
    List<Map<String, dynamic>> live, Set busy) {
  final out = <StoreLink>[];
  for (final s in stores) {
    final sp = _at(s);
    if (sp == null) continue;
    // Prefer a free driver; fall back to a busy one.
    for (final pool in [
      live.where((d) => !busy.contains(d['id'])).toList(),
      live,
    ]) {
      StoreLink? best;
      for (final d in pool) {
        final dp = _at(d['loc']);
        if (dp == null) continue;
        final km = kmBetween(sp, dp);
        if (best == null || km < best.km) {
          best = (store: s, driver: d, km: km);
        }
      }
      if (best != null) {
        out.add(best);
        break;
      }
    }
  }
  return out;
}

/// The admin's live drivers map: zoom controls, available drivers, a line
/// from every store to its nearest driver with the distance, and a tap on a
/// driver opens nudge and chat.
class DriversLiveMap extends StatefulWidget {
  const DriversLiveMap(
      {super.key,
      required this.drivers,
      required this.stores,
      required this.busy,
      required this.isLive,
      required this.unread});
  final List<Map<String, dynamic>> drivers;
  final List<Map<String, dynamic>> stores;
  final Set busy;
  final bool Function(Map? loc) isLive;
  final Map<String, int> unread;
  @override
  State<DriversLiveMap> createState() => _DriversLiveMapState();
}

class _DriversLiveMapState extends State<DriversLiveMap> {
  final map = MapController();
  bool onlyLive = true;
  bool lines = true;
  bool ready = false;

  List<Map<String, dynamic>> get live =>
      widget.drivers.where((d) => widget.isLive(d['loc'])).toList();

  List<LatLng> allPoints(List<Map<String, dynamic>> shown) => [
        for (final d in shown)
          if (_at(d['loc']) != null) _at(d['loc'])!,
        for (final s in widget.stores)
          if (_at(s) != null) _at(s)!,
      ];

  void fit(List<LatLng> pts) {
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      map.move(pts.first, 14);
      return;
    }
    map.fitCamera(CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.fromLTRB(60, 70, 60, 50),
        maxZoom: 15));
  }

  void zoom(double by) {
    final c = map.camera;
    map.move(c.center, (c.zoom + by).clamp(3, 19).toDouble());
  }

  Color colorOf(Map d) => !widget.isLive(d['loc'])
      ? Colors.blueGrey
      : widget.busy.contains(d['id'])
          ? G.amber.first
          : G.emerald.first;

  Future<void> nudge(BuildContext context, Map d) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.notifications_active_outlined,
            color: G.ruby.first, size: 40),
        title: Text('${tr('نكز')} ${d['name']}'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'يرن جوال المندوب بصوت عالٍ ويظهر له تنبيه حتى يضغط «تم».',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            Field('رسالة قصيرة (اختياري)', note),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: G.ruby.first),
              onPressed: () => Navigator.pop(c, true),
              icon: const Icon(Icons.notifications_active, size: 18),
              label: const Text('نكز الآن')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await guard(
        context,
        () => sb.rpc('admin_nudge_driver',
            params: {'p_driver': d['id'], 'p_note': note.text.trim()}),
        ok: 'تم نكز المندوب');
  }

  Future<void> openDriver(BuildContext context, Map<String, dynamic> d) async {
    final p = _at(d['loc']);
    final near = <(String, double)>[
      if (p != null)
        for (final s in widget.stores)
          if (_at(s) != null) ('${s['name']}', kmBetween(p, _at(s)!)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final seen = DateTime.tryParse('${d['loc']?['updated_at'] ?? ''}');
    final unread = widget.unread['${d['id']}'] ?? 0;
    final c = colorOf(d);
    await showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c, c.withValues(alpha: .75)]),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22))),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.delivery_dining, color: c)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${d['name']}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
                    Text(
                        '${d['phone']} · ${!widget.isLive(d['loc']) ? tr('غير متاح') : widget.busy.contains(d['id']) ? tr('في طلب') : tr('متاح')}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12.5)),
                  ]),
            ),
          ]),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (seen != null)
                  Text('${tr('آخر تحديث للموقع')}: ${dateTimeText(seen)}',
                      style: const TextStyle(
                          fontSize: 12.5, color: Colors.black54)),
                const SizedBox(height: 8),
                if (near.isNotEmpty) ...[
                  const Text('المسافة إلى المتاجر',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  for (final n in near.take(5))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Icon(Icons.storefront, size: 16, color: G.ruby.first),
                        const SizedBox(width: 6),
                        Expanded(child: Text(n.$1)),
                        Text(kmText(n.$2),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ] else
                  const Text('لا يوجد موقع حالي لهذا المندوب',
                      style: TextStyle(color: Colors.black54)),
              ]),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(dc);
              nudge(context, d);
            },
            style: OutlinedButton.styleFrom(foregroundColor: G.ruby.first),
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('نكز'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dc);
              openDriverChat(context, '${d['id']}', '${d['name']}');
            },
            icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.forum_outlined, size: 18)),
            label: const Text('دردشة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = onlyLive ? live : widget.drivers;
    final links = nearestLinks(widget.stores, live, widget.busy);
    final pts = allPoints(shown);
    final b = brandOf(context);
    Widget ctl(IconData i, String tip, VoidCallback f) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: Colors.white,
            elevation: 3,
            shape: const CircleBorder(),
            child: IconButton(
                tooltip: tr(tip),
                onPressed: f,
                icon: Icon(i, color: b.primary)),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilterChip(
          avatar: const Icon(Icons.wifi_tethering, size: 16),
          label: Text(
              '${tr('المتاحون فقط')} (${live.length}/${widget.drivers.length})'),
          selected: onlyLive,
          onSelected: (v) => setState(() => onlyLive = v),
        ),
        FilterChip(
          avatar: const Icon(Icons.timeline, size: 16),
          label: const Text('أقرب مندوب لكل متجر'),
          selected: lines,
          onSelected: (v) => setState(() => lines = v),
        ),
      ]),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 460,
          child: Stack(children: [
            FlutterMap(
              mapController: map,
              options: MapOptions(
                initialCenter: pts.length == 1 ? pts.first : bahrainCenter,
                initialZoom: pts.length == 1 ? 14 : 10.5,
                initialCameraFit: pts.length > 1
                    ? CameraFit.coordinates(
                        coordinates: pts,
                        padding: const EdgeInsets.fromLTRB(60, 70, 60, 50),
                        maxZoom: 15)
                    : null,
                minZoom: 3,
                maxZoom: 19,
                onMapReady: () => ready = true,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'app.dhabaeh.bahrain',
                ),
                if (lines)
                  PolylineLayer(polylines: [
                    for (final l in links)
                      Polyline(
                        points: [_at(l.store)!, _at(l.driver['loc'])!],
                        color: G.violet.first,
                        strokeWidth: 3,
                        pattern: StrokePattern.dashed(segments: const [10, 7]),
                      ),
                  ]),
                MarkerLayer(markers: [
                  for (final s in widget.stores)
                    if (_at(s) != null)
                      Marker(
                        point: _at(s)!,
                        width: 150,
                        height: 90,
                        alignment: const Alignment(0, .45),
                        child: _Pin(
                            label: '${s['name']}',
                            icon: Icons.storefront,
                            color: G.ruby.first,
                            below: lines
                                ? links
                                    .where((l) => l.store['id'] == s['id'])
                                    .map((l) =>
                                        '${tr('أقرب مندوب')} ${kmText(l.km)}')
                                    .firstOrNull
                                : null),
                      ),
                  for (final d in shown)
                    if (_at(d['loc']) != null)
                      Marker(
                        point: _at(d['loc'])!,
                        width: 130,
                        height: 64,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => openDriver(context, d),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: _Pin(
                                label: '${d['name']}',
                                icon: Icons.delivery_dining,
                                color: colorOf(d),
                                badge: widget.unread['${d['id']}'] ?? 0),
                          ),
                        ),
                      ),
                ]),
              ],
            ),
            PositionedDirectional(
              top: 10,
              start: 10,
              child: Column(children: [
                ctl(Icons.add, 'تكبير', () => zoom(1)),
                ctl(Icons.remove, 'تصغير', () => zoom(-1)),
                ctl(Icons.fit_screen_outlined, 'عرض الكل', () => fit(pts)),
              ]),
            ),
            if (shown.where((d) => _at(d['loc']) != null).isEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 30,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text(
                        'لا يوجد مندوب متاح الآن. يظهر المندوب عندما يفعّل «متاح لاستلام الطلبات» في تطبيقه.',
                        style: TextStyle(color: Colors.black54)),
                  ),
                ),
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
      ),
      const SizedBox(height: 12),
      if (links.isNotEmpty) ...[
        const Text('أقرب مندوب لكل متجر',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in links)
            ActionChip(
              avatar: Icon(Icons.storefront, size: 16, color: G.ruby.first),
              label: Text(
                  '${l.store['name']} ← ${l.driver['name']} · ${kmText(l.km)}'),
              onPressed: () {
                fit([_at(l.store)!, _at(l.driver['loc'])!]);
              },
            ),
        ]),
        const SizedBox(height: 12),
      ],
      const Text('المناديب: اضغط للنكز أو الدردشة',
          style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final d in widget.drivers)
          ActionChip(
            avatar: Badge(
              isLabelVisible: (widget.unread['${d['id']}'] ?? 0) > 0,
              label: Text('${widget.unread['${d['id']}'] ?? 0}'),
              child: Icon(Icons.circle, size: 12, color: colorOf(d)),
            ),
            label: Text('${d['name']}'),
            onPressed: () {
              final p = _at(d['loc']);
              if (p != null && widget.isLive(d['loc'])) map.move(p, 15);
              openDriver(context, d);
            },
          ),
      ]),
    ]);
  }
}

class _Pin extends StatelessWidget {
  const _Pin(
      {required this.label,
      required this.icon,
      required this.color,
      this.badge = 0,
      this.below});
  final String? below;
  final String label;
  final IconData icon;
  final Color color;
  final int badge;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4)
              ]),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
        Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3)),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
        if (below != null)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: G.violet),
                borderRadius: BorderRadius.circular(99),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4)
                ]),
            child: Text(below!,
                maxLines: 1,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800)),
          ),
      ]);
}
