import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';

import '../auth/gate.dart';
import '../core/address_map.dart';
import '../core/brand.dart';
import '../core/common.dart';

const driverKindLabels = {
  'cash_collected': 'تحصيل نقدي',
  'cash_handover': 'تسليم نقد للإدارة',
  'fee_earned': 'رسوم توصيل',
  'fee_paid': 'استلام رسوم من الإدارة',
};

class DriverShell extends StatefulWidget {
  const DriverShell({super.key, required this.profile, this.switcher});
  final Map<String, dynamic> profile;
  final Widget? switcher;
  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tab == 0 ? 'الطلبات المتاحة' : 'طلباتي'),
          Text(widget.profile['full_name'] ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: commonActions(context, widget.switcher),
      ),
      body: IndexedStack(index: tab, children: [
        DriverList(available: true, onClaimed: () => setState(() => tab = 1)),
        const DriverList(available: false)
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.inbox_outlined), label: 'المتاحة'),
          NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined), label: 'طلباتي'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- wallet at the top

/// Two balances: cash the driver collected (owed to the platform) and delivery fees owed to the driver.
/// A pending fee hand-over from the admin pops up until the driver confirms receipt.
class DriverWallet extends StatefulWidget {
  const DriverWallet({super.key});
  @override
  State<DriverWallet> createState() => _DriverWalletState();
}

class _DriverWalletState extends State<DriverWallet> {
  static final shown = <String>{};

  Future<void> confirmPopup(Map<String, dynamic> s) async {
    if (shown.contains(s['id'])) return;
    shown.add(s['id']);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: Dialog(
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: [Color(0xFF0D6152), Color(0xFF3CC4A0)])),
                child: Column(children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54, width: 2)),
                    child: const Icon(Icons.payments_outlined,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 14),
                  const Text('سلّمتك الإدارة رسوم التوصيل',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(bhd(s['amount']),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w800)),
                  Text('تسليم #${s['code']} · ${dateTimeText(s['created_at'])}',
                      style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if ('${s['note'] ?? ''}'.isNotEmpty) ...[
                        Text('ملاحظة الإدارة: ${s['note']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 10),
                      ],
                      const Text(
                          'تأكد إن المبلغ وصلك، بعدها اضغط تم الاستلام لتحديث محفظتك.',
                          textAlign: TextAlign.center,
                          style: TextStyle(height: 1.5)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0D6152),
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () async {
                          final r = await guard(
                              c,
                              () => sb.rpc('driver_confirm_payout',
                                  params: {'p_settlement': s['id']}),
                              ok: 'تم تأكيد الاستلام');
                          if (r != null && c.mounted) Navigator.pop(c);
                        },
                        icon: const Icon(Icons.task_alt),
                        label: const Text('تم الاستلام',
                            style: TextStyle(fontSize: 17)),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Loader<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
      realtimeTables: const ['driver_ledger', 'driver_settlements', 'orders'],
      load: () async {
        final b = await sb.rpc('driver_balance', params: {'p_driver': myId});
        final pending = await sb
            .from('driver_settlements')
            .select()
            .eq('driver_id', myId!)
            .eq('status', 'pending')
            .order('created_at');
        final row = (b is List && b.isNotEmpty)
            ? Map<String, dynamic>.from(b.first)
            : <String, dynamic>{};
        return (row, List<Map<String, dynamic>>.from(pending));
      },
      builder: (context, data, _) {
        final (bal, pending) = data;
        if (pending.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) confirmPopup(pending.first);
          });
        }
        final b = brandOf(context);
        Widget box(String k, String v, IconData i, Color c, String hint) =>
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .2))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(i, size: 18, color: c),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(k,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(v,
                          style: TextStyle(
                              color: c,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      Text(hint,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11)),
                    ]),
              ),
            );
        return InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DriverWalletPage())),
          borderRadius: BorderRadius.circular(22),
          child: GradientCard(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        color: b.accent),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('محفظتي',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                    ),
                    const Text('الحركات',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const Icon(Icons.chevron_left, color: Colors.white70),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    box('مبالغ محصّلة نقداً', bhd(bal['cash_held']),
                        Icons.payments_outlined, b.accent, 'تُسلَّم للإدارة'),
                    const SizedBox(width: 10),
                    box('رسوم توصيل مستحقة', bhd(bal['fees_due']),
                        Icons.local_shipping_outlined, const Color(0xFF7FE3C4),
                        toNum(bal['pending_payout']) > 0
                            ? 'بانتظار تأكيدك ${bhd(bal['pending_payout'])}'
                            : 'تستلمها من الإدارة'),
                  ]),
                ]),
          ),
        );
      },
    );
  }
}

class DriverWalletPage extends StatelessWidget {
  const DriverWalletPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: Text('محفظتي')),
      body: Loader<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
        realtimeTables: const ['driver_ledger', 'driver_settlements'],
        load: () async {
          final l = await sb
              .from('driver_ledger')
              .select()
              .eq('driver_id', myId!)
              .order('created_at', ascending: false);
          final s = await sb
              .from('driver_settlements')
              .select()
              .eq('driver_id', myId!)
              .order('created_at', ascending: false);
          return (
            List<Map<String, dynamic>>.from(l),
            List<Map<String, dynamic>>.from(s)
          );
        },
        builder: (context, data, _) {
          final (rows, sets) = data;
          return ListView(padding: const EdgeInsets.all(16), children: [
            const DriverWallet(),
            const SizedBox(height: 16),
            if (sets.isNotEmpty) ...[
              const Text('التسويات مع الإدارة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final s in sets)
                Card(
                  child: ListTile(
                    leading: GradientBadge(
                        colors: s['kind'] == 'fee_payout' ? G.emerald : G.amber,
                        icon: s['kind'] == 'fee_payout'
                            ? Icons.south_west
                            : Icons.north_east,
                        size: 40),
                    title: Text(s['kind'] == 'fee_payout'
                        ? 'استلام رسوم التوصيل #${s['code']}'
                        : 'تسليم نقد للإدارة #${s['code']}'),
                    subtitle: Text(
                        '${dateTimeText(s['created_at'])}${s['status'] == 'pending' ? ' · بانتظار تأكيدك' : ''}'),
                    trailing: Text(bhd(s['amount']),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            const Text('الحركات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (rows.isEmpty) const Empty('لا توجد حركات بعد'),
            for (final r in rows)
              Card(
                child: ListTile(
                  leading: GradientBadge(
                      colors: switch ('${r['kind']}') {
                        'cash_collected' => G.amber,
                        'cash_handover' => G.ruby,
                        'fee_earned' => G.emerald,
                        _ => G.sapphire,
                      },
                      icon: r['kind'].toString().startsWith('cash')
                          ? Icons.payments_outlined
                          : Icons.local_shipping_outlined,
                      size: 40),
                  title: Text(r['note'] ?? driverKindLabels[r['kind']] ?? ''),
                  subtitle: Text(
                      '${driverKindLabels[r['kind']] ?? ''} · ${dateTimeText(r['created_at'])}'),
                  trailing: Text(bhd(r['amount']),
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: toNum(r['amount']) >= 0
                              ? G.emerald.first
                              : G.ruby.first)),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- orders

class DriverList extends StatelessWidget {
  const DriverList({super.key, required this.available, this.onClaimed});
  final bool available;
  final VoidCallback? onClaimed;

  static Future<bool> claim(BuildContext context, String id) async {
    final r = await guard(
        context, () => sb.rpc('driver_claim', params: {'p_order': id}),
        ok: 'تم قبول الطلب');
    return r != null;
  }

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['orders'],
      load: () async {
        var q = sb.from('orders').select(
            'id, code, status, address, delivery_date, delivery_slot, slaughter_date, payment_method, total, driver_id, merchants(name, area), order_items(name, qty), delivery_zones(name)');
        q = available
            ? q
                .isFilter('driver_id', null)
                .inFilter('status', ['accepted', 'slaughtering', 'ready'])
            : q
                .eq('driver_id', myId!)
                .not('status', 'in', '(delivered,cancelled)');
        return List<Map<String, dynamic>>.from(await q.order('delivery_date'));
      },
      builder: (context, orders, reload) {
        final b = brandOf(context);
        final cash = orders.where((o) => o['payment_method'] == 'cash');
        return ListView(padding: const EdgeInsets.all(16), children: [
          const DriverWallet(),
          const SizedBox(height: 14),
          Row(children: [
            GradientBadge(
                colors: b.stops.sublist(1),
                icon: available
                    ? Icons.inbox_outlined
                    : Icons.local_shipping_outlined,
                size: 34),
            const SizedBox(width: 8),
            Text(available ? 'الطلبات المتاحة' : 'طلباتي الحالية',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Text('${orders.length}',
                style: const TextStyle(color: Colors.black45)),
            const Spacer(),
            if (cash.isNotEmpty)
              Text('${cash.length} تحصيل نقدي',
                  style: TextStyle(
                      color: G.amber.first, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          if (orders.isEmpty)
            Empty(
                available ? 'لا توجد طلبات متاحة الآن' : 'ما عندك طلبات حالية',
                icon: Icons.local_shipping_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 340).floor().clamp(1, 4);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final o in orders)
                SizedBox(
                  width: w,
                  child: _DriverOrderCard(
                    o: o,
                    available: available,
                    onDetails: () async {
                      final claimed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => DriverOrderPage(
                                  orderId: o['id'], available: available)));
                      await reload();
                      if (claimed == true) onClaimed?.call();
                    },
                    onClaim: () async {
                      final ok = await claim(context, o['id']);
                      await reload();
                      if (ok) onClaimed?.call();
                    },
                  ),
                ),
            ]);
          }),
        ]);
      },
    );
  }
}

class _DriverOrderCard extends StatelessWidget {
  const _DriverOrderCard(
      {required this.o,
      required this.available,
      required this.onDetails,
      required this.onClaim});
  final Map<String, dynamic> o;
  final bool available;
  final VoidCallback onDetails;
  final VoidCallback onClaim;
  @override
  Widget build(BuildContext context) {
    final c = statusColor('${o['status']}');
    final cash = o['payment_method'] == 'cash';
    final items = (o['order_items'] as List? ?? [])
        .map((x) => '${x['name']} × ${x['qty']}')
        .join('، ');
    Widget stop(IconData i, Color col, String k, String v) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: col.withValues(alpha: .12), shape: BoxShape.circle),
                child: Icon(i, size: 16, color: col),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k,
                          style: const TextStyle(
                              fontSize: 11.5, color: Colors.black45)),
                      Text(v,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ]),
              ),
            ]);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
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
                        'التوصيل ${dateText(o['delivery_date'])} · ${o['delivery_slot']}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(999)),
              child: Text(statusLabels[o['status']] ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            stop(Icons.storefront_outlined, G.sapphire.first, 'الاستلام من',
                '${o['merchants']?['name'] ?? ''} · ${o['merchants']?['area'] ?? ''}'),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14),
                child: Container(width: 2, height: 10, color: Colors.black12),
              ),
            ),
            stop(Icons.place_outlined, G.ruby.first, 'التسليم إلى',
                '${o['address'] ?? ''}'),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.set_meal_outlined,
                  size: 16, color: Colors.black45),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(items,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13))),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: cash ? const LinearGradient(colors: G.amber) : null,
                color: cash ? null : G.emerald.first.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(cash ? Icons.payments_outlined : Icons.verified_outlined,
                    size: 18, color: cash ? Colors.white : G.emerald.first),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      cash ? 'تحصيل عند الاستلام' : 'مدفوع، لا تحصّل شيئاً',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cash ? Colors.white : G.emerald.first)),
                ),
                if (cash)
                  Text(bhd(o['total']),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
              ]),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('التفاصيل'),
                ),
              ),
              if (available) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onClaim,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('قبول الطلب'),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Order details for the driver: route, times and products, without prices.
/// The amount to collect shows only for cash-on-delivery orders.
class DriverOrderPage extends StatelessWidget {
  const DriverOrderPage(
      {super.key, required this.orderId, this.available = false});
  final String orderId;
  final bool available;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: Text('تفاصيل الطلب')),
      body: Loader<Map<String, dynamic>>(
        realtimeTables: const ['orders'],
        load: () async => await sb
            .from('orders')
            .select(
                'id, code, status, address, notes, delivery_date, delivery_slot, slaughter_date, slaughter_time, payment_method, payment_status, total, driver_id, customer_name, customer_phone, merchants(name, area, store_phone), order_items(name, qty, options), delivery_zones(name, governorate, city, lat, lng)')
            .eq('id', orderId)
            .single(),
        builder: (context, o, reload) {
          final c = statusColor('${o['status']}');
          final mine = o['driver_id'] == myId;
          final cash = o['payment_method'] == 'cash';
          final s = '${o['status']}';
          final items = List<Map<String, dynamic>>.from(o['order_items'] ?? []);
          Future<void> set(String st) async {
            await guard(
                context,
                () => sb.rpc('set_order_status',
                    params: {'p_order': o['id'], 'p_status': st}),
                ok: 'تم تحديث الحالة');
            await reload();
          }

          Widget section(IconData i, String t, List<Color> cs, Widget child) =>
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          GradientBadge(colors: cs, icon: i, size: 34),
                          const SizedBox(width: 10),
                          Text(t,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 12),
                        child,
                      ]),
                ),
              );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: toneOf(c)),
                    boxShadow: [
                      BoxShadow(
                          color: c.withValues(alpha: .3),
                          blurRadius: 16,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.local_shipping_outlined,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('طلب #${o['code']}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            Text(
                                '${statusLabels[s] ?? s} · ${orderKindLabels[orderKind(o)]}',
                                style: const TextStyle(color: Colors.white70)),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                section(
                  Icons.route_outlined,
                  'المسار',
                  G.sapphire,
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _kv('الاستلام من', '${o['merchants']?['name'] ?? ''}'),
                        _kv('منطقة الملحمة', '${o['merchants']?['area'] ?? ''}'),
                        if (mine)
                          _kv('هاتف الملحمة',
                              '${o['merchants']?['store_phone'] ?? ''}'),
                        const Divider(height: 18),
                        _kv('التسليم إلى', '${o['address'] ?? ''}'),
                        if (o['delivery_zones'] != null)
                          _kv(
                              'منطقة التوصيل',
                              [
                                o['delivery_zones']['name'],
                                o['delivery_zones']['city'],
                                o['delivery_zones']['governorate']
                              ]
                                  .where((x) => '${x ?? ''}'.isNotEmpty)
                                  .toSet()
                                  .join(' · ')),
                        if (o['delivery_zones']?['lat'] != null) ...[
                          const SizedBox(height: 8),
                          AddressMap(
                            point: LatLng(
                                toNum(o['delivery_zones']['lat']).toDouble(),
                                toNum(o['delivery_zones']['lng']).toDouble()),
                            height: 200,
                            color: G.sapphire.first,
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (mine)
                          _kv('العميل',
                              '${o['customer_name'] ?? ''} · ${o['customer_phone'] ?? ''}'),
                        if ('${o['notes'] ?? ''}'.isNotEmpty)
                          _kv('ملاحظات', '${o['notes']}'),
                      ]),
                ),
                const SizedBox(height: 12),
                section(
                  Icons.schedule,
                  'المواعيد',
                  G.violet,
                  Column(children: [
                    _kv('الذبح',
                        '${dateText(o['slaughter_date'])} · ${o['slaughter_time']}'),
                    _kv('التوصيل',
                        '${dateText(o['delivery_date'])} · ${o['delivery_slot']}'),
                  ]),
                ),
                const SizedBox(height: 12),
                section(
                  Icons.set_meal_outlined,
                  'المنتجات',
                  G.ruby,
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final it in items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: G.ruby.first.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text('× ${it['qty']}',
                                    style: TextStyle(
                                        color: G.ruby.first,
                                        fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${it['name']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      if (it['options'] is Map &&
                                          it['options']['cutting'] != null)
                                        Text(
                                            [
                                              it['options']['cutting'],
                                              it['options']['packing'],
                                              if (it['options']['keep_head'] ==
                                                  true)
                                                'مع الرأس والكوارع'
                                            ].whereType<String>().join(' · '),
                                            style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Colors.black54)),
                                    ]),
                              ),
                            ]),
                          ),
                      ]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: cash
                        ? const LinearGradient(
                            begin: AlignmentDirectional.topStart,
                            end: AlignmentDirectional.bottomEnd,
                            colors: G.amber)
                        : null,
                    color: cash ? null : G.emerald.first.withValues(alpha: .08),
                  ),
                  child: Row(children: [
                    Icon(
                        cash ? Icons.payments_outlined : Icons.verified_outlined,
                        size: 32,
                        color: cash ? Colors.white : G.emerald.first),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                cash
                                    ? 'الدفع عند الاستلام'
                                    : 'الطلب مدفوع مسبقاً',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: cash
                                        ? Colors.white
                                        : G.emerald.first)),
                            Text(
                                cash
                                    ? 'حصّل هذا المبلغ من العميل عند التسليم'
                                    : 'لا تحصّل أي مبلغ من العميل',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: cash
                                        ? Colors.white70
                                        : Colors.black54)),
                          ]),
                    ),
                    if (cash)
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('الإجمالي',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            Text(bhd(o['total']),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800)),
                          ]),
                  ]),
                ),
                const SizedBox(height: 16),
                if (available && o['driver_id'] == null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () async {
                      final ok = await DriverList.claim(context, o['id']);
                      if (ok && context.mounted) Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('قبول الطلب'),
                  ),
                if (mine && s == 'ready')
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () => set('out_for_delivery'),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('استلمت الطلب، في الطريق'),
                  ),
                if (mine && s == 'out_for_delivery')
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: G.emerald.first,
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () => set('delivered'),
                    icon: const Icon(Icons.task_alt),
                    label: Text(cash
                        ? 'تم التسليم وحصّلت ${bhd(o['total'])}'
                        : 'تم التسليم للعميل'),
                  ),
                if (mine && ['accepted', 'slaughtering'].contains(s))
                  const Text('الطلب يتجهز في الملحمة، تقدر تستلمه لما يصير جاهز.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 110,
              child: Text(k,
                  style: const TextStyle(color: Colors.black54, fontSize: 13))),
          Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13.5))),
        ]),
      );
}
