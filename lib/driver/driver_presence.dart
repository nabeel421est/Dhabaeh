import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:latlong2/latlong.dart';

import '../core/address_map.dart';
import '../core/brand.dart';
import '../core/common.dart';
import '../core/i18n.dart';
import '../core/ttext.dart';

/// "Available for orders" switch. While on, the driver's position is sent every
/// 30 seconds so new orders are offered to the driver closest to the store.
class DriverPresence extends StatefulWidget {
  const DriverPresence({super.key});
  @override
  State<DriverPresence> createState() => _DriverPresenceState();
}

class _DriverPresenceState extends State<DriverPresence> {
  bool online = false;
  bool busy = false;
  bool showMap = false;
  LatLng? me;
  DateTime? sentAt;
  String? problem;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final r = await sb
          .from('driver_locations')
          .select()
          .eq('driver_id', myId!)
          .maybeSingle();
      if (r == null || !mounted) return;
      setState(() {
        me = LatLng(toNum(r['lat']).toDouble(), toNum(r['lng']).toDouble());
        sentAt = DateTime.tryParse('${r['updated_at']}')?.toLocal();
      });
      if (r['online'] == true) await _setOnline(true, quiet: true);
    } catch (_) {}
  }

  Future<void> _send() async {
    try {
      final p = await currentLocation();
      await sb.rpc('driver_set_location', params: {
        'p_lat': p.latitude,
        'p_lng': p.longitude,
        'p_online': true
      });
      if (mounted) {
        setState(() {
          me = p;
          sentAt = DateTime.now();
          problem = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => problem = errText(e));
    }
  }

  Future<void> _setOnline(bool v, {bool quiet = false}) async {
    setState(() => busy = true);
    timer?.cancel();
    if (v) {
      await _send();
      if (problem == null) {
        online = true;
        timer = Timer.periodic(const Duration(seconds: 30), (_) => _send());
        if (!quiet && mounted) toast(context, 'أنت الآن متاح لاستلام الطلبات');
      } else {
        online = false;
        if (!quiet && mounted) toast(context, problem!, error: true);
      }
    } else {
      online = false;
      try {
        await sb.rpc('driver_set_location', params: {
          'p_lat': me?.latitude ?? bahrainCenter.latitude,
          'p_lng': me?.longitude ?? bahrainCenter.longitude,
          'p_online': false
        });
      } catch (_) {}
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        online ? G.emerald : [Colors.blueGrey, Colors.blueGrey.shade300];
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: colors)),
          child: Row(children: [
            Icon(online ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(online ? 'متاح لاستلام الطلبات' : 'غير متاح',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Text(
                        online
                            ? 'موقعك يُحدّث كل 30 ثانية، والطلبات تُعرض على الأقرب للمحل أولاً'
                            : 'فعّل التوفر ليصلك الطلب حسب قربك من المحل',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ]),
            ),
            busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white)))
                : Switch(
                    value: online,
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.white38,
                    onChanged: (v) => _setOnline(v)),
          ]),
        ),
        if (problem != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(problem!,
                style: TextStyle(color: G.ruby.first, fontSize: 13)),
          ),
        InkWell(
          onTap: () => setState(() => showMap = !showMap),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Icon(Icons.map_outlined, size: 18, color: colors.first),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    sentAt == null
                        ? 'موقعك على الخريطة'
                        : '${tr('آخر تحديث للموقع')} ${dateTimeText(sentAt!.toIso8601String())}',
                    style: const TextStyle(fontSize: 13)),
              ),
              Icon(showMap ? Icons.expand_less : Icons.expand_more,
                  color: Colors.black45),
            ]),
          ),
        ),
        if (showMap)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: me == null
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('فعّل التوفر لعرض موقعك',
                        style: TextStyle(color: Colors.black54)))
                : PinsMap(height: 220, pins: [
                    (
                      at: me!,
                      color: colors.first,
                      icon: Icons.delivery_dining,
                      label: tr('موقعي')
                    )
                  ]),
          ),
      ]),
    );
  }
}

/// Seconds a driver has before the offer moves to the next nearest driver.
Future<int> dispatchSeconds() async {
  try {
    final s = await sb
        .from('platform_settings')
        .select('dispatch_seconds')
        .eq('id', 1)
        .single();
    return toNum(s['dispatch_seconds'] ?? 180).toInt().clamp(30, 3600);
  } catch (_) {
    return 180;
  }
}

/// Seconds left in my turn, or null when the order is open to everyone.
int? myTurnLeft(Map o, int secs) {
  final q = (o['dispatch_queue'] as List?) ?? const [];
  final at = DateTime.tryParse('${o['dispatch_at']}');
  if (q.isEmpty || at == null) return null;
  final elapsed = DateTime.now().toUtc().difference(at.toUtc()).inSeconds;
  final idx = elapsed ~/ secs;
  if (idx >= q.length || q[idx] != myId) return null;
  return secs * (idx + 1) - elapsed;
}

/// A ticking "your turn" bar with a pass button.
class TurnBar extends StatefulWidget {
  const TurnBar(
      {super.key, required this.o, required this.secs, required this.onPass});
  final Map o;
  final int secs;
  final VoidCallback onPass;
  @override
  State<TurnBar> createState() => _TurnBarState();
}

class _TurnBarState extends State<TurnBar> {
  Timer? t;
  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = myTurnLeft(widget.o, widget.secs);
    if (left == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: G.sky.first.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.groups_outlined, size: 18, color: G.sky.first),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('متاح لكل المناديب، الأسرع يقبله',
                  style: TextStyle(fontSize: 13))),
        ]),
      );
    }
    final frac = left / widget.secs;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
          gradient: const LinearGradient(colors: G.gold),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.near_me, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('معروض عليك أولاً لأنك الأقرب',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          Text(durationText(Duration(seconds: left)),
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          TextButton(
              onPressed: widget.onPass,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('تمرير')),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: frac,
              minHeight: 5,
              color: Colors.white,
              backgroundColor: Colors.white24),
        ),
      ]),
    );
  }
}
