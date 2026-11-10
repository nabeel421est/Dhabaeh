import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/common.dart';

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
    if (s == 'delivered' || s == 'cancelled') return [];
    return switch (viewer) {
      'merchant' => [
          if (s == 'new') ('accepted', 'قبول الطلب'),
          if (s == 'accepted') ('slaughtering', 'بدء الذبح'),
          if (s == 'slaughtering') ('ready', 'جاهز للتوصيل'),
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
    final events = {
      for (final e in (o['order_events'] as List)) e['status']: e['created_at']
    };
    final cancelled = o['status'] == 'cancelled';
    final items = List<Map<String, dynamic>>.from(o['order_items']);
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (justPlaced)
        Card(
          color: const Color(0xFFE6EFEB),
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: Color(0xFF2F5D50)),
            title: Text('تم استلام طلبك #${o['code']}'),
            subtitle: const Text('بنبلغك مع كل تحديث على الطلب'),
          ),
        ),
      SectionCard(
        title: 'طلب #${o['code']}',
        trailing: StatusChip(o['status']),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KeyVal('المسلخ', o['merchants']?['name'] ?? ''),
          if (viewer != 'customer')
            KeyVal('العميل',
                '${o['customer_name'] ?? ''} · ${o['customer_phone'] ?? ''}'),
          KeyVal('الذبح',
              '${dateText(o['slaughter_date'])} · ${o['slaughter_time']}'),
          KeyVal('التوصيل',
              '${dateText(o['delivery_date'])} · ${o['delivery_slot']}'),
          const SizedBox(height: 4),
          Text(o['address'] ?? '',
              style: const TextStyle(color: Colors.black54)),
          if (o['driver_name'] != null)
            KeyVal(
                'المندوب', '${o['driver_name']} · ${o['driver_phone'] ?? ''}'),
          KeyVal('الدفع',
              '${paymentLabels[o['payment_method']]} · ${paymentStatusLabels[o['payment_status']]}'),
        ]),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'المنتجات',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final it in items) ...[
            KeyVal('${it['name']} × ${it['qty']}',
                bhd(toNum(it['unit_price']) * toNum(it['qty']))),
            if ((it['options'] as Map).isNotEmpty)
              Text(
                [
                  it['options']['cutting'],
                  it['options']['packing'],
                  if (it['options']['keep_head'] == true) 'مع الرأس والكوارع'
                ].whereType<String>().join(' · '),
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
          ],
          const Divider(),
          if (toNum(o['discount']) > 0)
            KeyVal('الخصم', '- ${bhd(o['discount'])}'),
          if (toNum(o['customer_commission']) > 0)
            KeyVal('رسوم الخدمة', bhd(o['customer_commission'])),
          KeyVal('التوصيل', bhd(o['delivery_fee'])),
          KeyVal('إجمالي العميل', bhd(o['total']), bold: true),
          if (viewer == 'merchant' || viewer == 'admin') ...[
            const Divider(),
            KeyVal('عمولة المنصة على التاجر',
                '- ${bhd(o['merchant_commission'])}'),
            KeyVal('صافي التاجر', bhd(o['merchant_net']), bold: true),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'تتبع الطلب',
        child: Column(children: [
          for (final s in statusFlow)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                  events.containsKey(s)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: events.containsKey(s)
                      ? const Color(0xFF2F5D50)
                      : Colors.black26),
              title: Text(statusLabels[s]!),
              trailing: Text(
                  events.containsKey(s) ? dateTimeText(events[s]) : '',
                  style: const TextStyle(fontSize: 12)),
            ),
          if (cancelled)
            ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cancel, color: Color(0xFF8F1D13)),
                title: const Text('ملغي'),
                trailing: Text(dateTimeText(events['cancelled']),
                    style: const TextStyle(fontSize: 12))),
        ]),
      ),
      if (viewer == 'admin') ...[
        const SizedBox(height: 12),
        AdminOrderTools(order: o, reload: reload)
      ],
      const SizedBox(height: 16),
      for (final (s, label) in actions())
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: s == 'cancelled'
              ? OutlinedButton(
                  onPressed: () => setStatus(context, s), child: Text(label))
              : FilledButton(
                  onPressed: () => setStatus(context, s), child: Text(label)),
        ),
    ]);
  }
}

class AdminOrderTools extends StatelessWidget {
  const AdminOrderTools({super.key, required this.order, required this.reload});
  final Map<String, dynamic> order;
  final Future<void> Function() reload;
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'إجراءات الإدارة',
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
                DropdownButtonFormField<String?>(
                  initialValue: order['driver_id'],
                  decoration: const InputDecoration(labelText: 'تعيين مندوب'),
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
                const SizedBox(height: 12),
                if (order['receipt_path'] != null)
                  OutlinedButton.icon(
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
                            builder: (_) =>
                                AlertDialog(content: SelectableText(url)));
                      }
                    },
                  ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final ps in ['paid', 'pending', 'refunded'])
                    ChoiceChip(
                      label: Text(paymentStatusLabels[ps]!),
                      selected: order['payment_status'] == ps,
                      onSelected: (_) async {
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
              ]);
        },
      ),
    );
  }
}
