import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:latlong2/latlong.dart';

import '../core/brand.dart';
import '../core/common.dart';
import '../core/i18n.dart';
import '../core/ttext.dart';
import '../customer/order_details.dart';
import 'admin_driver_map.dart';
import 'admin_people.dart' show AdminUsers;

/// Drivers section: live map, delivery orders with timers and assignment, and accounts.
class AdminDriversHub extends StatelessWidget {
  const AdminDriversHub({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Material(
          color: Colors.white,
          child: TabBar(
            labelColor: G.sapphire.first,
            indicatorColor: G.sapphire.first,
            tabs: [
              Tab(
                  icon: const Icon(Icons.map_outlined),
                  text: tr('الخريطة والطلبات')),
              Tab(
                  icon: const Icon(Icons.badge_outlined),
                  text: tr('حسابات المناديب')),
            ],
          ),
        ),
        const Expanded(
          child: TabBarView(children: [
            AdminDispatch(),
            AdminUsers(onlyRole: 'driver'),
          ]),
        ),
      ]),
    );
  }
}

typedef _DispatchData = (
  List<Map<String, dynamic>> drivers,
  List<Map<String, dynamic>> orders,
  List<Map<String, dynamic>> stores,
  Map<String, int> unread
);

/// Is the driver sharing location and recently seen?
bool driverLive(Map? loc) {
  if (loc == null || loc['online'] != true) return false;
  final t = DateTime.tryParse('${loc['updated_at']}');
  return t != null &&
      DateTime.now().toUtc().difference(t.toUtc()).inMinutes < 15;
}

double _km(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b) / 1000;

class AdminDispatch extends StatelessWidget {
  const AdminDispatch({super.key});

  Future<_DispatchData> load() async {
    final roles = await sb
        .from('user_roles')
        .select('user_id, profiles(full_name, phone, is_active, deleted_at)')
        .eq('role', 'driver');
    final locs = await sb.from('driver_locations').select();
    final byId = {for (final l in locs) l['driver_id']: l};
    final drivers = [
      for (final r in roles)
        if (r['profiles']?['deleted_at'] == null)
          {
            'id': r['user_id'],
            'name': r['profiles']?['full_name'] ?? '',
            'phone': r['profiles']?['phone'] ?? '',
            'loc': byId[r['user_id']],
          }
    ];
    final orders = List<Map<String, dynamic>>.from(await sb
        .from('orders')
        .select(
            'id, code, status, driver_id, driver_name, driver_assigned_at, dispatch_at, dispatch_queue, delivery_date, delivery_slot, address, merchant_id, merchants(name, area, lat, lng)')
        .eq('fulfillment', 'delivery')
        .inFilter('status', [
      'accepted',
      'slaughtering',
      'ready',
      'out_for_delivery'
    ]).order('created_at'));
    final stores = List<Map<String, dynamic>>.from(await sb
        .from('merchants')
        .select('id, name, lat, lng')
        .not('lat', 'is', null));
    final unread = <String, int>{};
    try {
      for (final r in await sb.rpc('admin_chat_overview') as List) {
        unread['${r['driver_id']}'] = toNum(r['unread']).toInt();
      }
    } catch (_) {}
    return (drivers, orders, stores, unread);
  }

  @override
  Widget build(BuildContext context) {
    return Loader<_DispatchData>(
      realtimeTables: const ['driver_locations', 'orders', 'driver_chat'],
      refreshEvery: const Duration(seconds: 30),
      load: load,
      builder: (context, data, reload) {
        final (drivers, orders, stores, unread) = data;
        final live = drivers.where((d) => driverLive(d['loc'])).toList();
        final busy = {
          for (final o in orders)
            if (o['driver_id'] != null) o['driver_id']
        };
        final waiting = orders.where((o) => o['driver_id'] == null).toList();
        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon: Icons.delivery_dining_outlined,
            title: 'المناديب',
            subtitle:
                'مواقع المناديب مباشرة، والطلب يُعرض على الأقرب للمحل ثم التالي كل 3 دقائق',
            stats: [
              ('متاحون الآن', '${live.length}'),
              ('في طلب', '${busy.length}'),
              ('بانتظار مندوب', '${waiting.length}'),
              ('كل المناديب', '${drivers.length}'),
            ],
          ),
          const SizedBox(height: 16),
          GradientHeaderCard(
            title: 'خريطة المناديب',
            subtitle:
                'تتحدث تلقائياً · كبّر وصغّر واضغط على المندوب للنكز أو الدردشة',
            icon: Icons.map_outlined,
            colors: G.sapphire,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DriversLiveMap(
                    drivers: drivers,
                    stores: stores,
                    busy: busy,
                    isLive: driverLive,
                    unread: unread,
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 14, runSpacing: 6, children: [
                    _legend(G.emerald.first, 'متاح'),
                    _legend(G.amber.first, 'في طلب'),
                    _legend(Colors.blueGrey, 'غير متاح'),
                    _legend(G.ruby.first, 'متجر'),
                    _legend(G.violet.first, 'المسافة لأقرب مندوب'),
                  ]),
                ]),
          ),
          const SizedBox(height: 18),
          Text('طلبات التوصيل الجارية',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (orders.isEmpty)
            const Empty('لا توجد طلبات توصيل جارية',
                icon: Icons.local_shipping_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 380).floor().clamp(1, 3);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final o in orders)
                SizedBox(
                  width: w,
                  child: _DispatchCard(
                      o: o, drivers: drivers, busy: busy, reload: reload),
                ),
            ]);
          }),
        ]);
      },
    );
  }

  Widget _legend(Color c, String t) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 12.5)),
      ]);
}

class _DispatchCard extends StatelessWidget {
  const _DispatchCard(
      {required this.o,
      required this.drivers,
      required this.busy,
      required this.reload});
  final Map<String, dynamic> o;
  final List<Map<String, dynamic>> drivers;
  final Set busy;
  final Future<void> Function() reload;

  String? _offeredTo() {
    final q = (o['dispatch_queue'] as List?) ?? const [];
    final at = DateTime.tryParse('${o['dispatch_at']}');
    if (q.isEmpty || at == null) return null;
    final idx = DateTime.now().toUtc().difference(at.toUtc()).inSeconds ~/ 180;
    if (idx >= q.length) return null;
    return drivers
        .where((d) => d['id'] == q[idx])
        .map((d) => '${d['name']}')
        .firstOrNull;
  }

  Future<void> pick(BuildContext context) async {
    final m = o['merchants'];
    final store = m?['lat'] == null
        ? null
        : LatLng(toNum(m['lat']).toDouble(), toNum(m['lng']).toDouble());
    double? dist(Map d) => store == null || d['loc'] == null
        ? null
        : _km(
            store,
            LatLng(toNum(d['loc']['lat']).toDouble(),
                toNum(d['loc']['lng']).toDouble()));
    final list = [...drivers]..sort((a, b) {
        final la = driverLive(a['loc']) ? 0 : 1,
            lb = driverLive(b['loc']) ? 0 : 1;
        if (la != lb) return la - lb;
        return (dist(a) ?? 1e9).compareTo(dist(b) ?? 1e9);
      });
    final chosen = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(o['driver_id'] == null
            ? '${tr('إسناد الطلب')} #${o['code']}'
            : '${tr('تحويل الطلب')} #${o['code']}'),
        content: SizedBox(
          width: 420,
          child: ListView(shrinkWrap: true, children: [
            for (final d in list)
              ListTile(
                enabled: d['id'] != o['driver_id'],
                leading: CircleAvatar(
                  backgroundColor: (driverLive(d['loc'])
                          ? busy.contains(d['id'])
                              ? G.amber.first
                              : G.emerald.first
                          : Colors.blueGrey)
                      .withValues(alpha: .15),
                  child: Icon(Icons.delivery_dining,
                      color: driverLive(d['loc'])
                          ? busy.contains(d['id'])
                              ? G.amber.first
                              : G.emerald.first
                          : Colors.blueGrey),
                ),
                title: Text('${d['name']}'),
                subtitle: Text([
                  '${d['phone']}',
                  driverLive(d['loc'])
                      ? (busy.contains(d['id']) ? tr('في طلب') : tr('متاح'))
                      : tr('غير متاح'),
                  if (dist(d) != null)
                    '${dist(d)!.toStringAsFixed(math.max(0, dist(d)! < 10 ? 1 : 0))} ${tr('كم من المحل')}',
                ].join(' · ')),
                trailing: d['id'] == o['driver_id']
                    ? const Text('الحالي')
                    : const Icon(Icons.chevron_left),
                onTap: () => Navigator.pop(c, d['id']),
              ),
          ]),
        ),
        actions: [
          if (o['driver_id'] != null)
            TextButton(
                onPressed: () => Navigator.pop(c, ''),
                style: TextButton.styleFrom(foregroundColor: G.ruby.first),
                child: const Text('إلغاء الإسناد وإعادة العرض')),
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    await guard(
        context,
        () => sb.rpc('admin_assign_driver', params: {
              'p_order': o['id'],
              'p_driver': chosen.isEmpty ? null : chosen
            }),
        ok: chosen.isEmpty
            ? 'أُلغي الإسناد وعاد الطلب للمناديب'
            : o['driver_id'] == null
                ? 'تم إسناد الطلب'
                : 'تم تحويل الطلب');
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = statusColor('${o['status']}');
    final has = o['driver_id'] != null;
    final offered = has ? null : _offeredTo();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      OrderDetailsPage(orderId: o['id'], viewer: 'admin'))),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: toneOf(c))),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${o['code']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      Text(
                          '${o['merchants']?['name'] ?? ''} · ${o['merchants']?['area'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(999)),
                child: Text(statusOf(o),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.place_outlined, size: 16, color: G.ruby.first),
              const SizedBox(width: 6),
              Expanded(
                  child: Text('${o['address'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13))),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color:
                      (has ? G.sapphire : G.amber).first.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(has ? Icons.delivery_dining : Icons.hourglass_top_outlined,
                    color: (has ? G.sapphire : G.amber).first),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            has ? '${o['driver_name'] ?? ''}' : 'بانتظار مندوب',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                            has
                                ? 'منذ قبول الطلب'
                                : offered == null
                                    ? 'معروض على كل المناديب'
                                    : '${tr('معروض الآن على')} $offered',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ]),
                ),
                if (has && o['driver_assigned_at'] != null)
                  ElapsedTimer(o['driver_assigned_at'],
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: G.sapphire.first)),
              ]),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: has ? G.violet.first : G.emerald.first),
              onPressed: () => pick(context),
              icon: Icon(has ? Icons.swap_horiz : Icons.person_add_alt),
              label: Text(has ? 'تحويل لمندوب آخر' : 'إسناد لمندوب'),
            ),
          ]),
        ),
      ]),
    );
  }
}
