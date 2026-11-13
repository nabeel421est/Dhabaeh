import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/common.dart';
import '../core/ttext.dart';
import '../core/i18n.dart';
import '../core/tap_pay.dart';

/// Order details shared by every role. [viewer] decides which actions show:
/// customer, merchant, driver or admin.
class OrderDetailsPage extends StatelessWidget {
  const OrderDetailsPage(
      {super.key,
      required this.orderId,
      required this.viewer,
      this.justPlaced = false});
  final String orderId;
  final String viewer;
  final bool justPlaced;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: const Text('تفاصيل الطلب')),
      body: Loader<Map<String, dynamic>>(
        realtimeTables: const ['orders', 'order_events'],
        load: () async => await sb
            .from('orders')
            .select(
                '*, merchants(name, store_phone), order_items(*), order_events(status, created_at), delivery_zones(name)')
            .eq('id', orderId)
            .single(),
        builder: (context, o, reload) => OrderView(
            order: o, viewer: viewer, justPlaced: justPlaced, reload: reload),
      ),
    );
  }
}

class OrderView extends StatelessWidget {
  const OrderView(
      {super.key,
      required this.order,
      required this.viewer,
      required this.reload,
      this.justPlaced = false});
  final Map<String, dynamic> order;
  final String viewer;
  final bool justPlaced;
  final Future<void> Function() reload;

  Future<void> setStatus(BuildContext context, String s) async {
    await guard(
        context,
        () => sb.rpc('set_order_status',
            params: {'p_order': order['id'], 'p_status': s}),
        ok: 'تم تحديث الحالة');
    await reload();
  }

  List<(String, String)> actions() {
    final s = order['status'];
    final pickup = order['fulfillment'] == 'pickup';
    if (s == 'delivered' || s == 'cancelled') return [];
    return switch (viewer) {
      'merchant' => [
          if (s == 'new') ('accepted', 'قبول الطلب'),
          if (s == 'accepted') ('slaughtering', 'بدء الذبح'),
          if (s == 'slaughtering')
            ('ready', pickup ? 'جاهز للاستلام' : 'جاهز للتوصيل'),
          // Pickup orders are handed over by the store, not a driver.
          if (pickup && s == 'ready') ('delivered', 'تم تسليم الطلب للعميل'),
          if (s == 'new' || s == 'accepted') ('cancelled', 'إلغاء الطلب'),
        ],
      'driver' => [
          if (s == 'ready') ('out_for_delivery', 'استلمت الطلب، في الطريق'),
          if (s == 'out_for_delivery') ('delivered', 'تم التسليم للعميل'),
        ],
      'customer' => [if (s == 'new') ('cancelled', 'إلغاء الطلب')],
      'admin' => [
          for (final n in statusFlow)
            if (statusFlow.indexOf(n) > statusFlow.indexOf(s))
              (n, statusLabels[n]!),
          ('cancelled', 'إلغاء'),
        ],
      _ => [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final status = '${o['status']}';
    final events = {
      for (final e in (o['order_events'] as List)) e['status']: e['created_at']
    };
    final cancelled = status == 'cancelled';
    final tone = cancelled
        ? G.ruby
        : status == 'delivered'
            ? G.emerald
            : toneOf(statusColor(status));
    final items = List<Map<String, dynamic>>.from(o['order_items']);
    final pickupFlow = o['fulfillment'] == 'pickup';
    // Pickup orders skip "on the way": the store hands them over directly.
    final flow = [
      for (final f in statusFlow)
        if (!(pickupFlow && f == 'out_for_delivery')) f
    ];
    final flowIcons = pickupFlow ? _pickupIcons : _flowIcons;
    String flowLabel(String f) => statusOf({...o, 'status': f});
    final step = flow.indexOf(status);
    final staff = viewer == 'merchant' || viewer == 'admin';
    final pickup = o['fulfillment'] == 'pickup';

    Widget info(IconData icon, String k, String v, List<Color> c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: c.first.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: c.first),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                    Text(v.isEmpty ? '-' : v,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                  ]),
            ),
          ]),
        );
    Widget money(String k, String v,
            {bool bold = false, Color? color, bool big = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
                child: Text(k,
                    style: TextStyle(
                        color: bold ? Colors.black87 : Colors.black54,
                        fontWeight: bold ? FontWeight.w700 : null))),
            Text(v,
                style: TextStyle(
                    fontSize: big ? 18 : 14.5,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    color: color)),
          ]),
        );

    // ---------------------------------------------------------------- hero
    final hero = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [tone.first, tone.last]),
        boxShadow: [
          BoxShadow(
              color: tone.first.withValues(alpha: .35),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: .4))),
            child:
                const Icon(Icons.receipt_long, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('طلب #${o['code']}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              Text(
                  '${o['merchants']?['name'] ?? ''} · ${dateTimeText(o['created_at'])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _pill(statusOf(o), .28),
            const SizedBox(height: 5),
            _pill(orderKindLabels[orderKind(o)] ?? '', .15),
          ]),
        ]),
        if (step >= 0) ...[
          const SizedBox(height: 16),
          Row(children: [
            for (var i = 0; i < flow.length; i++) ...[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= step
                      ? Colors.white
                      : Colors.white.withValues(alpha: .18),
                ),
                child: Icon(flowIcons[i],
                    size: 16, color: i <= step ? tone.first : Colors.white),
              ),
              if (i < flow.length - 1)
                Expanded(
                  child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i < step
                              ? Colors.white
                              : Colors.white.withValues(alpha: .25))),
                ),
            ],
          ]),
          const SizedBox(height: 6),
          Text(
              step == flow.length - 1
                  ? 'تم تسليم الطلب'
                  : 'المرحلة التالية: ${flowLabel(flow[step + 1])}',
              style: const TextStyle(color: Colors.white, fontSize: 12.5)),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: .25))),
          child: Row(children: [
            const Icon(Icons.payments_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${payLabel(o)} · ${payStatusText(o)}',
                  style: const TextStyle(color: Colors.white)),
            ),
            Text(bhd(o['total']),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );

    // ---------------------------------------------------------------- cards
    final people = GradientHeaderCard(
      title: 'الأطراف',
      subtitle: 'الملحمة والعميل والمندوب',
      icon: Icons.groups_2_outlined,
      colors: G.sapphire,
      child: Column(children: [
        info(Icons.storefront_outlined, 'الملحمة',
            '${o['merchants']?['name'] ?? ''}', G.sapphire),
        if (viewer != 'customer')
          info(
              Icons.person_outline,
              'العميل',
              '${o['customer_name'] ?? ''} · ${o['customer_phone'] ?? ''}',
              G.sapphire),
        if (pickup)
          info(Icons.storefront_outlined, 'طريقة الاستلام',
              'استلام من المحل، يسلّمه المحل للعميل', G.sapphire)
        else
          info(
              Icons.delivery_dining_outlined,
              'المندوب',
              o['driver_name'] == null
                  ? 'لم يُعيّن بعد'
                  : '${o['driver_name']} · ${o['driver_phone'] ?? ''}',
              G.sapphire),
        if (!pickup && o['driver_assigned_at'] != null && viewer != 'customer')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(Icons.timer_outlined, size: 18, color: G.sapphire.first),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    status == 'delivered'
                        ? 'مدة التوصيل من قبول المندوب'
                        : 'الوقت منذ قبول المندوب للطلب',
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black54)),
              ),
              ElapsedTimer(o['driver_assigned_at'],
                  end: status == 'delivered'
                      ? (o['delivered_at'] ?? o['updated_at'])
                      : null,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: G.sapphire.first)),
            ]),
          ),
      ]),
    );
    final timing = GradientHeaderCard(
      title: 'المواعيد والعنوان',
      icon: Icons.event_available_outlined,
      colors: G.amber,
      child: Column(children: [
        info(
            Icons.content_cut,
            'موعد الذبح',
            '${dateText(o['slaughter_date'])} · ${o['slaughter_time'] ?? ''}',
            G.amber),
        info(
            pickup ? Icons.storefront_outlined : Icons.local_shipping_outlined,
            pickup ? 'موعد الاستلام من المحل' : 'موعد التوصيل',
            '${dateText(o['delivery_date'])} · ${o['delivery_slot'] ?? ''}',
            G.amber),
        info(
            Icons.location_on_outlined,
            'العنوان${o['delivery_zones']?['name'] == null ? '' : ' · ${o['delivery_zones']['name']}'}',
            '${o['address'] ?? ''}',
            G.amber),
      ]),
    );
    final bill = GradientHeaderCard(
      title: 'المنتجات والفاتورة',
      subtitle: '${items.length} صنف',
      icon: Icons.set_meal_outlined,
      colors: G.emerald,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final it in items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: [
                  G.emerald.first.withValues(alpha: .07),
                  G.emerald.last.withValues(alpha: .12)
                ])),
            child: Row(children: [
              GradientBadge(colors: G.emerald, text: '${it['qty']}×', size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${it['name']}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (it['options'] is Map &&
                          (it['options'] as Map)['cutting'] != null)
                        Text(
                          [
                            it['options']['cutting'],
                            it['options']['packing'],
                            if (it['options']['keep_head'] == true)
                              'مع الرأس والكوارع'
                          ].whereType<String>().join(' · '),
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12.5),
                        ),
                    ]),
              ),
              Text(bhd(toNum(it['unit_price']) * toNum(it['qty'])),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        const SizedBox(height: 4),
        if (toNum(o['discount']) > 0)
          money('الخصم', '- ${bhd(o['discount'])}', color: G.ruby.first),
        if (toNum(o['customer_commission']) > 0)
          money('رسوم الخدمة', bhd(o['customer_commission'])),
        money('التوصيل', bhd(o['delivery_fee'])),
        const Divider(height: 14),
        money('إجمالي العميل', bhd(o['total']),
            bold: true, big: true, color: G.emerald.first),
        if (staff) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: G.gold.first.withValues(alpha: .08),
                border: Border.all(color: G.gold.first.withValues(alpha: .25))),
            child: Column(children: [
              money('عمولة المنصة على التاجر',
                  '- ${bhd(o['merchant_commission'])}'),
              money('صافي التاجر', bhd(o['merchant_net']),
                  bold: true, color: G.gold.first),
            ]),
          ),
        ],
      ]),
    );
    final track = GradientHeaderCard(
      title: 'تتبع الطلب',
      icon: Icons.timeline,
      colors: G.violet,
      child: Column(children: [
        for (final (i, s) in [...flow, if (cancelled) 'cancelled'].indexed)
          _TimelineRow(
            label: flowLabel(s),
            time: events.containsKey(s) ? dateTimeText(events[s]) : '',
            done: events.containsKey(s),
            color: s == 'cancelled' ? G.ruby.first : statusColor(s),
            last: i == flow.length - (cancelled ? 0 : 1),
          ),
      ]),
    );

    final acts = actions();
    final buttons =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (s, label) in acts)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: s == 'cancelled'
              ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: G.ruby.first,
                      side: BorderSide(
                          color: G.ruby.first.withValues(alpha: .5))),
                  onPressed: () => setStatus(context, s),
                  icon: const Icon(Icons.block, size: 18),
                  label: Text(label))
              : DecoratedBox(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                          colors: toneOf(statusColor(s)).reversed.toList())),
                  child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: () => setStatus(context, s),
                      icon: const Icon(Icons.arrow_circle_left_outlined,
                          size: 20),
                      label: Text(label,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                ),
        ),
    ]);

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      const gap = SizedBox(height: 14);
      final left = <Widget>[
        people,
        gap,
        timing,
        gap,
        track,
      ];
      final right = <Widget>[
        bill,
        if (viewer == 'admin') ...[
          gap,
          AdminOrderTools(order: o, reload: reload)
        ],
        if (acts.isNotEmpty) ...[
          gap,
          GradientHeaderCard(
              title: viewer == 'admin' ? 'تغيير الحالة' : 'الإجراءات',
              icon: Icons.bolt_outlined,
              colors: tone,
              child: buttons),
        ],
      ];
      return ListView(padding: const EdgeInsets.all(16), children: [
        if (justPlaced) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: G.emerald.first.withValues(alpha: .1),
                border:
                    Border.all(color: G.emerald.first.withValues(alpha: .3))),
            child: Row(children: [
              Icon(Icons.check_circle, color: G.emerald.first),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    'تم استلام طلبك #${o['code']}، وبنبلغك مع كل تحديث عليه',
                    style: TextStyle(
                        color: G.emerald.first, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          gap,
        ],
        if (viewer == 'customer') TapPayButton(order: o),
        hero,
        gap,
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(children: left)),
            const SizedBox(width: 14),
            Expanded(child: Column(children: right)),
          ])
        else ...[
          ...left,
          gap,
          ...right,
        ],
      ]);
    });
  }

  Widget _pill(String t, double a) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: a),
            borderRadius: BorderRadius.circular(999)),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );
}

const _pickupIcons = [
  Icons.receipt_outlined,
  Icons.thumb_up_alt_outlined,
  Icons.content_cut,
  Icons.inventory_2_outlined,
  Icons.storefront_outlined,
];
const _flowIcons = [
  Icons.receipt_outlined,
  Icons.thumb_up_alt_outlined,
  Icons.content_cut,
  Icons.inventory_2_outlined,
  Icons.local_shipping_outlined,
  Icons.home_outlined,
];

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(
      {required this.label,
      required this.time,
      required this.done,
      required this.color,
      required this.last});
  final String label;
  final String time;
  final bool done;
  final Color color;
  final bool last;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 30,
            child: Column(children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: done ? LinearGradient(colors: toneOf(color)) : null,
                  color: done ? null : Colors.black.withValues(alpha: .06),
                ),
                child: Icon(done ? Icons.check : Icons.circle,
                    size: done ? 15 : 7,
                    color: done ? Colors.white : Colors.black26),
              ),
              if (!last)
                Expanded(
                  child: Container(
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: done
                          ? color.withValues(alpha: .5)
                          : Colors.black.withValues(alpha: .08)),
                ),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 14),
              child: Row(children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                          color: done ? color : Colors.black45)),
                ),
                Text(time,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            ),
          ),
        ]),
      );
}

class AdminOrderTools extends StatelessWidget {
  const AdminOrderTools({super.key, required this.order, required this.reload});
  final Map<String, dynamic> order;
  final Future<void> Function() reload;

  static const _payTones = {
    'paid': G.emerald,
    'pending': G.amber,
    'refunded': G.ruby,
  };

  @override
  Widget build(BuildContext context) {
    return GradientHeaderCard(
      title: 'إجراءات الإدارة',
      subtitle: 'المندوب وحالة الدفع والإيصال',
      icon: Icons.admin_panel_settings_outlined,
      colors: G.teal,
      child: FutureBuilder(
        future: sb
            .from('user_roles')
            .select('user_id, profiles(full_name, phone)')
            .eq('role', 'driver'),
        builder: (context, snap) {
          final drivers = List<Map<String, dynamic>>.from(snap.data ?? []);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (order['fulfillment'] == 'pickup')
                  const Text('استلام من المحل: لا يحتاج مندوباً',
                      style: TextStyle(color: Colors.black54))
                else
                  DropdownButtonFormField<String?>(
                    initialValue: order['driver_id'],
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: tr('تعيين أو تحويل المندوب'),
                        prefixIcon: Icon(Icons.delivery_dining_outlined)),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('بدون مندوب')),
                      for (final d in drivers)
                        DropdownMenuItem<String?>(
                            value: d['user_id'],
                            child: Text(
                                '${d['profiles']?['full_name'] ?? ''} · ${d['profiles']?['phone'] ?? ''}')),
                    ],
                    onChanged: (v) async {
                      await guard(
                          context,
                          () => sb.rpc('admin_assign_driver',
                              params: {'p_order': order['id'], 'p_driver': v}),
                          ok: 'تم تعيين المندوب');
                      await reload();
                    },
                  ),
                const SizedBox(height: 14),
                const Text('حالة الدفع',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(runSpacing: 8, children: [
                  for (final ps in ['paid', 'pending', 'refunded'])
                    TonePill(
                      label: paymentStatusLabels[ps]!,
                      colors: _payTones[ps]!,
                      selected: order['payment_status'] == ps,
                      icon: ps == 'paid'
                          ? Icons.verified_outlined
                          : ps == 'pending'
                              ? Icons.hourglass_bottom
                              : Icons.undo,
                      onTap: () async {
                        await guard(
                            context,
                            () => sb.rpc('admin_set_payment', params: {
                                  'p_order': order['id'],
                                  'p_status': ps
                                }),
                            ok: 'تم تحديث حالة الدفع');
                        await reload();
                      },
                    ),
                ]),
                if (order['receipt_path'] != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        foregroundColor: G.teal.first),
                    icon: const Icon(Icons.receipt_outlined),
                    label: const Text('عرض إيصال التحويل'),
                    onPressed: () async {
                      final url = await guard(
                          context,
                          () => sb.storage
                              .from('docs')
                              .createSignedUrl(order['receipt_path'], 600));
                      if (url != null && context.mounted) {
                        showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('إيصال التحويل'),
                            content: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxWidth: 520, maxHeight: 620),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(url,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        SelectableText(url)),
                              ),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('إغلاق'))
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ],
              ]);
        },
      ),
    );
  }
}
