import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'alert_bridge_stub.dart'
    if (dart.library.js_interop) 'alert_bridge_web.dart';
import 'common.dart';
import 'push.dart';
import 'i18n.dart';
import 'ttext.dart';

/// One order that should ring: id, code and a short line.
typedef AlertItem = ({String id, String code, String line});

/// Watches for new orders and rings loudly: a looping sound, vibration, a
/// system notification and a full-screen card that stays until dismissed.
/// [fetch] returns the orders that should ring right now; each rings once.
class OrderAlertWatcher extends StatefulWidget {
  const OrderAlertWatcher(
      {super.key,
      required this.child,
      required this.fetch,
      required this.title,
      required this.onOpen,
      this.enabled = true,
      this.every = const Duration(seconds: 15)});
  final bool enabled;
  final Widget child;
  final Future<List<AlertItem>> Function() fetch;
  final String title;
  final void Function(BuildContext context, String orderId) onOpen;
  final Duration every;
  @override
  State<OrderAlertWatcher> createState() => _OrderAlertWatcherState();
}

class _OrderAlertWatcherState extends State<OrderAlertWatcher> {
  final seen = <String>{};
  Timer? timer;
  RealtimeChannel? ch;
  bool showing = false;
  bool checking = false;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
    timer = Timer.periodic(widget.every, (_) => check());
    ch = sb
        .channel('alerts-${identityHashCode(this)}')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (_) => check())
        .subscribe();
  }

  @override
  void dispose() {
    timer?.cancel();
    if (ch != null) sb.removeChannel(ch!);
    alertStop();
    super.dispose();
  }

  Future<void> check() async {
    if (checking || showing || !mounted) return;
    checking = true;
    try {
      final items = await widget.fetch();
      final fresh = items.where((i) => !seen.contains(i.id)).toList();
      seen.addAll(items.map((i) => i.id));
      if (fresh.isNotEmpty && mounted) await ring(fresh);
    } catch (_) {
    } finally {
      checking = false;
    }
  }

  Future<void> ring(List<AlertItem> fresh) async {
    showing = true;
    final first = fresh.first;
    final title = fresh.length == 1
        ? '${tr(widget.title)} #${first.code}'
        : '${tr(widget.title)} (${fresh.length})';
    alertPlay();
    if (!pushOn.value) alertNotify(title, tr(first.line));
    final open = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: .65),
      pageBuilder: (c, _, __) => _AlertCard(
          title: title,
          lines: [for (final f in fresh) '#${f.code} · ${f.line}']),
    );
    alertStop();
    showing = false;
    if (open == true && mounted) widget.onOpen(context, first.id);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Column(children: [
      const PushBanner(),
      Expanded(child: widget.child),
    ]);
  }
}

class _AlertCard extends StatefulWidget {
  const _AlertCard({required this.title, required this.lines});
  final String title;
  final List<String> lines;
  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard>
    with SingleTickerProviderStateMixin {
  late final pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB3123C), Color(0xFF6E0B2A)]),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black45, blurRadius: 30, offset: Offset(0, 12))
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ScaleTransition(
              scale: Tween(begin: .88, end: 1.12).animate(pulse),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .16),
                  border: Border.all(color: const Color(0xFFE2B866), width: 3),
                ),
                child: const Icon(Icons.notifications_active,
                    size: 52, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final l in widget.lines.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE2B866),
                    foregroundColor: const Color(0xFF4A0618),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('عرض الطلب',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إيقاف التنبيه',
                  style: TextStyle(color: Colors.white)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// New orders for the admin (all stores) or one store's owner and staff.
Future<List<AlertItem>> newOrderAlerts({String? merchantId}) async {
  final since = DateTime.now()
      .toUtc()
      .subtract(const Duration(minutes: 30))
      .toIso8601String();
  var q = sb
      .from('orders')
      .select('id, code, customer_name, fulfillment, merchants(name)')
      .eq('status', 'new')
      .gte('created_at', since);
  if (merchantId != null) q = q.eq('merchant_id', merchantId);
  final rows = await q.order('created_at');
  return [
    for (final o in rows)
      (
        id: '${o['id']}',
        code: '${o['code']}',
        line:
            '${o['merchants']?['name'] ?? ''} · ${o['customer_name'] ?? ''} · ${o['fulfillment'] == 'pickup' ? 'استلام من المحل' : 'توصيل'}'
      )
  ];
}
