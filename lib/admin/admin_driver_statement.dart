import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/common.dart';
import '../core/i18n.dart';
import '../core/ttext.dart';
import '../customer/order_details.dart';
import 'admin_txn_control.dart';

/// Opens a driver's statement, keeping the control buttons when opened from
/// inside «التحكم الإداري».
void openDriverStatement(BuildContext context, Map<String, dynamic> p) {
  final s = ControlScope.of(context);
  final page = DriverStatementPage(
      driverId: p['id'],
      name: '${p['full_name'] ?? ''}',
      phone: '${p['phone'] ?? ''}');
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => s == null
          ? page
          : ControlScope(
              act: s.act,
              can: s.can,
              isSuper: s.isSuper,
              storeOrders: s.storeOrders,
              child: page),
    ),
  );
}

/// Amount fields of an order. Returns the changed fields, or null if cancelled.
Future<Map<String, dynamic>?> orderMoneyDialog(
    BuildContext context, Map<String, dynamic> o) async {
  final keys = {
    'subtotal': 'قيمة الأصناف',
    'discount': 'الخصم',
    'delivery_fee': 'رسوم التوصيل',
    'customer_commission': 'عمولة العميل',
    'merchant_commission': 'عمولة التاجر',
  };
  final c = {
    for (final k in keys.keys)
      k: TextEditingController(text: toNum(o[k]).toStringAsFixed(3))
  };
  String pay = '${o['payment_method']}';
  num v(String k) => num.tryParse(c[k]!.text.trim()) ?? 0;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final total = v('subtotal') -
          v('discount') +
          v('customer_commission') +
          v('delivery_fee');
      final net = v('subtotal') - v('discount') - v('merchant_commission');
      return AlertDialog(
        title: Text('${tr('مبالغ الطلب')} #${o['code']}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final e in keys.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: c[e.key],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                    onChanged: (_) => set(() {}),
                    decoration: InputDecoration(
                        labelText: tr('${e.value} (د.ب)'),
                        border: const OutlineInputBorder()),
                  ),
                ),
              DropdownButtonFormField<String>(
                initialValue: paymentLabels.containsKey(pay) ? pay : null,
                decoration: InputDecoration(
                    labelText: tr('طريقة الدفع'),
                    border: const OutlineInputBorder()),
                items: [
                  for (final e in paymentLabels.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (x) => set(() => pay = x ?? pay),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: G.sapphire.first.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  _kv('إجمالي الطلب على العميل', bhd(total)),
                  _kv('صافي التاجر', bhd(net)),
                ]),
              ),
              const SizedBox(height: 8),
              const Text(
                  'إذا كان الطلب مسلَّماً تتعدل معه محفظة التاجر وعمولات المنصة والمبلغ الذي بحوزة المندوب ورسومه.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ المبالغ')),
        ],
      );
    }),
  );
  if (ok != true) return null;
  final out = <String, dynamic>{};
  for (final k in keys.keys) {
    final n = num.tryParse(c[k]!.text.trim());
    if (n != null && (n - toNum(o[k])).abs() > .0005) out[k] = n;
  }
  if (pay != '${o['payment_method']}') out['payment_method'] = pay;
  return out;
}

Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(
            child: Text(k,
                style: const TextStyle(color: Colors.black54, fontSize: 13))),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );

/// Minutes between two timestamps, or null.
int? _mins(dynamic a, dynamic b) {
  final x = DateTime.tryParse('${a ?? ''}');
  final y = DateTime.tryParse('${b ?? ''}');
  if (x == null || y == null) return null;
  return y.difference(x).inMinutes;
}

String durationText(int? m) {
  if (m == null) return '—';
  if (m < 60) return '$m ${tr('د')}';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h ${tr('س')}' : '$h ${tr('س')} $r ${tr('د')}';
}

const _ledgerKinds = <String, (String, IconData, List<Color>)>{
  'cash_collected': ('تحصيل نقدي من عميل', Icons.payments_outlined, G.amber),
  'cash_handover': ('تسليم نقد للإدارة', Icons.call_made, G.teal),
  'fee_earned': (
    'رسوم توصيل مستحقة',
    Icons.delivery_dining_outlined,
    G.emerald
  ),
  'fee_paid': ('استلام رسوم من الإدارة', Icons.call_received, G.violet),
};

typedef _StmtData = (
  Map<String, dynamic> bal,
  List<Map<String, dynamic>> orders,
  List<Map<String, dynamic>> ledger,
  List<Map<String, dynamic>> sets,
);

/// Everything on one driver's account: deliveries with their durations,
/// cash collected and handed over, fees earned and paid.
class DriverStatementPage extends StatefulWidget {
  const DriverStatementPage(
      {super.key,
      required this.driverId,
      required this.name,
      required this.phone});
  final String driverId;
  final String name;
  final String phone;
  @override
  State<DriverStatementPage> createState() => _DriverStatementPageState();
}

class _DriverStatementPageState extends State<DriverStatementPage> {
  String tab = 'deliveries';

  Future<_StmtData> load(bool ctl) async {
    final b = await sb.rpc('admin_driver_balances');
    final bal = List<Map<String, dynamic>>.from(b ?? []).firstWhere(
        (r) => r['driver_id'] == widget.driverId,
        orElse: () => <String, dynamic>{});
    final o = await sb
        .from('orders')
        .select('*, merchants(name)')
        .eq('driver_id', widget.driverId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .limit(400);
    final l = await sb
        .from('driver_ledger')
        .select('*, orders(code)')
        .eq('driver_id', widget.driverId)
        .eq('voided', false)
        .order('created_at', ascending: false)
        .limit(500);
    var q = sb
        .from('driver_settlements')
        .select('*, profiles(full_name)')
        .eq('driver_id', widget.driverId);
    if (!ctl) q = q.isFilter('deleted_at', null);
    final s = await q.order('created_at', ascending: false).limit(300);
    return (
      bal,
      List<Map<String, dynamic>>.from(o),
      List<Map<String, dynamic>>.from(l),
      List<Map<String, dynamic>>.from(s),
    );
  }

  Future<String?> reason(BuildContext context, String title) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (x) => AlertDialog(
        title: Text(title),
        content: SizedBox(
            width: 400, child: Field('السبب', c, maxLines: 2, required: true)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(x, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: G.ruby.first),
              onPressed: () => Navigator.pop(x, true),
              child: const Text('حذف')),
        ],
      ),
    );
    return ok == true && c.text.trim().isNotEmpty ? c.text.trim() : null;
  }

  // ------------------------------------------------------------ orders
  Future<void> editOrder(BuildContext context, ControlScope s, Map o,
      Future<void> Function() reload) async {
    final f = await orderMoneyDialog(context, Map<String, dynamic>.from(o));
    if (f == null || f.isEmpty || !context.mounted) return;
    if (await s.act(
        (t) => sb.rpc('oc_update_order',
            params: {'p_token': t, 'p_order': o['id'], 'p_fields': f}),
        ok: 'تم تعديل الطلب وكل حركاته')) {
      await reload();
    }
  }

  Future<void> deleteOrder(BuildContext context, ControlScope s, Map o,
      Future<void> Function() reload) async {
    final r = await reason(context, '${tr('حذف الطلب')} #${o['code']}');
    if (r == null || !context.mounted) return;
    if (await s.act(
        (t) => sb.rpc('oc_delete', params: {
              'p_token': t,
              'p_order': o['id'],
              'p_reason': r,
              'p_restore': false
            }),
        ok: 'تم حذف الطلب وكل حركاته')) {
      await reload();
    }
  }

  // ------------------------------------------------------------ ledger rows
  Future<void> viewEntry(BuildContext context, Map e) {
    final k = _ledgerKinds[e['kind']];
    return showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(k?.$1 ?? '${e['kind']}'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _kv('المبلغ', bhd(e['amount'])),
            _kv('التاريخ', dateTimeText(e['created_at'])),
            if (e['orders']?['code'] != null)
              _kv('الطلب', '#${e['orders']['code']}'),
            if ('${e['note'] ?? ''}'.isNotEmpty) _kv('ملاحظة', '${e['note']}'),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('إغلاق'))
        ],
      ),
    );
  }

  Future<void> editEntry(BuildContext context, ControlScope s, Map e,
      Future<void> Function() reload) async {
    final amount =
        TextEditingController(text: toNum(e['amount']).toStringAsFixed(3));
    final note = TextEditingController(text: '${e['note'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
            '${tr('تعديل')} ${tr(_ledgerKinds[e['kind']]?.$1 ?? '${e['kind']}')}'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Field('المبلغ (د.ب)', amount,
                ltr: true,
                keyboard: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 10),
            Field('ملاحظة', note, maxLines: 2),
            if (e['order_id'] != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'هذه الحركة من طلب. لتعديل الطلب مع محفظة التاجر والعمولات استخدم «تعديل الطلب» في قائمة التوصيلات.',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (await s.act(
        (t) => sb.rpc('ctl_driver_entry', params: {
              'p_token': t,
              'p_id': e['id'],
              'p_action': 'edit',
              'p_data': {'amount': amount.text.trim(), 'note': note.text.trim()}
            }),
        ok: 'تم تعديل الحركة')) {
      await reload();
    }
  }

  Future<void> deleteEntry(BuildContext context, ControlScope s, Map e,
      Future<void> Function() reload) async {
    final r = await reason(context, tr('حذف الحركة'));
    if (r == null || !context.mounted) return;
    if (await s.act(
        (t) => sb.rpc('ctl_driver_entry', params: {
              'p_token': t,
              'p_id': e['id'],
              'p_action': 'delete',
              'p_data': {'reason': r}
            }),
        ok: 'تم حذف الحركة')) {
      await reload();
    }
  }

  Widget actions(BuildContext context,
      {required VoidCallback onView,
      VoidCallback? onEdit,
      VoidCallback? onDelete}) {
    final s = ControlScope.of(context);
    Widget b(String t, IconData i, List<Color> c, VoidCallback? on) =>
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: c.first,
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: c.first.withValues(alpha: .35))),
          onPressed: on,
          icon: Icon(i, size: 16),
          label: Text(t),
        );
    return Wrap(spacing: 6, runSpacing: 6, children: [
      b('عرض', Icons.visibility_outlined, G.sapphire, onView),
      if (s != null && onEdit != null)
        b('تعديل', Icons.edit_outlined, G.amber,
            s.can['edit'] == false ? null : onEdit),
      if (s != null && onDelete != null)
        b('حذف', Icons.delete_outline, G.ruby,
            s.can['delete'] == false ? null : onDelete),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final ctl = ControlScope.of(context);
    return Scaffold(
      appBar: GradientAppBar(title: Text('${tr('كشف حساب')} ${widget.name}')),
      body: Loader<_StmtData>(
        key: ValueKey('stmt-${ctl != null}'),
        realtimeTables: const ['orders', 'driver_ledger', 'driver_settlements'],
        load: () => load(ctl != null),
        builder: (context, data, reload) {
          final (bal, orders, ledger, sets) = data;
          final done = orders.where((o) => o['status'] == 'delivered').toList();
          final ongoing = orders
              .where((o) => !['delivered', 'cancelled'].contains(o['status']))
              .length;
          final durs = [
            for (final o in done)
              _mins(o['driver_assigned_at'] ?? o['picked_up_at'],
                  o['delivered_at'])
          ].whereType<int>().where((m) => m >= 0).toList();
          final avg = durs.isEmpty
              ? null
              : (durs.reduce((a, b) => a + b) / durs.length).round();
          final tabs = <String, (String, IconData, List<Color>, int)>{
            'deliveries': (
              'التوصيلات الناجحة',
              Icons.task_alt,
              G.emerald,
              done.length
            ),
            'ledger': (
              'الاستلام والتسليم',
              Icons.swap_horiz,
              G.amber,
              ledger.length
            ),
            'sets': (
              'تسويات الإدارة',
              Icons.receipt_long_outlined,
              G.violet,
              sets.length
            ),
          };
          return ListView(padding: const EdgeInsets.all(16), children: [
            PageHero(
              icon: Icons.delivery_dining_outlined,
              title: widget.name,
              subtitle:
                  '${widget.phone} · ${tr('كل الحركات على حساب المندوب')}',
              stats: [
                ('بحوزته نقداً', bhd(bal['cash_held'] ?? 0)),
                ('رسوم مستحقة له', bhd(bal['fees_due'] ?? 0)),
                ('توصيلات ناجحة', '${done.length}'),
                ('جارية', '$ongoing'),
                ('متوسط مدة التوصيل', durationText(avg)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in tabs.entries)
                ChoiceChip(
                  selected: tab == e.key,
                  onSelected: (_) => setState(() => tab = e.key),
                  avatar: Icon(e.value.$2,
                      size: 18,
                      color: tab == e.key ? Colors.white : e.value.$3.first),
                  selectedColor: e.value.$3.first,
                  showCheckmark: false,
                  label: Text('${e.value.$1} (${e.value.$4})',
                      style: TextStyle(
                          color: tab == e.key ? Colors.white : null,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 14),
            if (tab == 'deliveries') ...[
              if (done.isEmpty)
                const Empty('لا توجد توصيلات ناجحة بعد',
                    icon: Icons.delivery_dining_outlined),
              for (final o in done) _orderCard(context, ctl, o, reload),
            ],
            if (tab == 'ledger') ...[
              if (ledger.isEmpty) const Empty('لا توجد حركات بعد'),
              for (final e in ledger) _entryCard(context, ctl, e, reload),
            ],
            if (tab == 'sets') ...[
              if (sets.isEmpty) const Empty('لا توجد تسويات بعد'),
              for (final s in sets) _setCard(context, s, reload),
            ],
          ]);
        },
      ),
    );
  }

  Widget _orderCard(BuildContext context, ControlScope? s, Map o,
      Future<void> Function() reload) {
    final total =
        _mins(o['driver_assigned_at'] ?? o['picked_up_at'], o['delivered_at']);
    final road = _mins(o['picked_up_at'], o['delivered_at']);
    Widget step(IconData i, String k, dynamic v) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Icon(i, size: 16, color: Colors.black45),
            const SizedBox(width: 6),
            Text('${tr(k)}: ',
                style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            Text(v == null ? '—' : dateTimeText(v),
                style: const TextStyle(fontSize: 12.5)),
          ]),
        );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const GradientBadge(
                colors: G.emerald, icon: Icons.task_alt, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${o['code']} · ${o['merchants']?['name'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                        '${o['customer_name'] ?? ''} · ${paymentLabels[o['payment_method']] ?? ''}',
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.black54)),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(bhd(o['total']),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${tr('رسوم')} ${bhd(o['delivery_fee'])}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _pill(Icons.timer_outlined,
                '${tr('مدة التوصيل')}: ${durationText(total)}', G.sapphire),
            if (road != null)
              _pill(Icons.route_outlined,
                  '${tr('من المحل للعميل')}: ${durationText(road)}', G.teal),
          ]),
          const SizedBox(height: 8),
          step(Icons.assignment_ind_outlined, 'استلم الطلب',
              o['driver_assigned_at']),
          step(Icons.storefront_outlined, 'خرج من المحل', o['picked_up_at']),
          step(Icons.home_outlined, 'سُلِّم للعميل', o['delivered_at']),
          const SizedBox(height: 6),
          actions(context,
              onView: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          OrderDetailsPage(orderId: o['id'], viewer: 'admin'))),
              onEdit: s == null ? null : () => editOrder(context, s, o, reload),
              onDelete:
                  s == null ? null : () => deleteOrder(context, s, o, reload)),
        ]),
      ),
    );
  }

  Widget _entryCard(BuildContext context, ControlScope? s, Map e,
      Future<void> Function() reload) {
    final k = _ledgerKinds[e['kind']] ??
        ('${e['kind']}', Icons.swap_horiz, G.midnight);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            GradientBadge(colors: k.$3, icon: k.$2, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                        [
                          dateTimeText(e['created_at']),
                          if (e['orders']?['code'] != null)
                            '${tr('طلب')} #${e['orders']['code']}',
                          if ('${e['note'] ?? ''}'.isNotEmpty) '${e['note']}',
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ]),
            ),
            Text(bhd(e['amount']),
                style:
                    TextStyle(fontWeight: FontWeight.w800, color: k.$3.first)),
          ]),
          const SizedBox(height: 8),
          actions(context,
              onView: () => viewEntry(context, e),
              onEdit: s == null ? null : () => editEntry(context, s, e, reload),
              onDelete:
                  s == null ? null : () => deleteEntry(context, s, e, reload)),
        ]),
      ),
    );
  }

  Widget _setCard(BuildContext context, Map<String, dynamic> s,
      Future<void> Function() reload) {
    final fees = s['kind'] == 'fee_payout';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ListTile(
            leading: GradientBadge(
                colors: fees ? G.emerald : G.amber,
                icon: fees ? Icons.south_west : Icons.call_received,
                size: 40),
            title: Text(
                '#${s['code']} · ${fees ? tr('تسليم رسوم للمندوب') : tr('استلام نقد من المندوب')}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text([
              dateTimeText(s['created_at']),
              if (s['status'] == 'pending') tr('بانتظار تأكيد المندوب'),
              if ('${s['note'] ?? ''}'.isNotEmpty) '${s['note']}',
            ].join(' · ')),
            trailing: Text(bhd(s['amount']),
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: txnActive(s) ? null : Colors.black38,
                    decoration:
                        txnDeleted(s) ? TextDecoration.lineThrough : null)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TxnActions(
              type: 'settlement',
              row: s,
              title:
                  '${fees ? tr('تسليم رسوم') : tr('استلام نقد')} #${s['code']}',
              party: widget.name,
              reload: reload,
              transfer: 'driver',
              fields: const [
                TxnField('amount', 'المبلغ (د.ب)', kind: 'amount'),
                TxnField('note', 'ملاحظة'),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pill(IconData i, String t, List<Color> c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: c.first.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 15, color: c.first),
          const SizedBox(width: 5),
          Text(t,
              style: TextStyle(
                  color: c.first, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      );
}
