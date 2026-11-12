import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/common.dart';
import '../core/i18n.dart';
import '../core/ttext.dart';

typedef ControlAct = Future<bool>
    Function(Future<dynamic> Function(String token) fn, {required String ok});

/// Present only inside the unlocked «التحكم الإداري». Pages opened there show
/// the control buttons (view, edit, transfer, freeze, delete) on every movement;
/// the same pages opened from the sidebar stay as they were.
class ControlScope extends InheritedWidget {
  const ControlScope(
      {super.key,
      required this.act,
      required this.can,
      required this.isSuper,
      required this.storeOrders,
      required super.child});
  final ControlAct act;
  final Map<String, bool> can;
  final bool isSuper;

  /// The order-control cards for one store, used by the merchant reports.
  final Widget Function(String merchantId) storeOrders;

  static ControlScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ControlScope>();

  @override
  bool updateShouldNotify(ControlScope old) =>
      old.can != can || old.isSuper != isSuper;
}

bool txnDeleted(Map r) => r['deleted_at'] != null;
bool txnFrozen(Map r) => r['frozen'] == true && !txnDeleted(r);
bool txnActive(Map r) => !txnDeleted(r) && r['frozen'] != true;

/// Rows that count in totals: not frozen and not deleted.
Iterable<Map<String, dynamic>> activeOnly(Iterable<Map<String, dynamic>> rs) =>
    rs.where(txnActive);

const txnStates = <String, (String, IconData, List<Color>)>{
  'all': ('الكل', Icons.apps_outlined, G.midnight),
  'active': ('سارية', Icons.check_circle_outline, G.emerald),
  'frozen': ('مجمّدة', Icons.ac_unit, G.sky),
  'deleted': ('محذوفة', Icons.delete_outline, G.ruby),
};

bool txnMatch(Map r, String state) => switch (state) {
      'active' => txnActive(r),
      'frozen' => txnFrozen(r),
      'deleted' => txnDeleted(r),
      _ => !txnDeleted(r),
    };

/// One editable field of a movement.
class TxnField {
  const TxnField(this.key, this.label, {this.kind = 'text', this.src});
  final String key;

  /// Row column used to prefill the field, when it differs from [key].
  final String? src;
  String get from => src ?? key;
  final String label;

  /// text, amount, date or plan.
  final String kind;
}

const _labels = <String, String>{
  'code': 'الرقم',
  'amount': 'المبلغ',
  'status': 'الحالة',
  'note': 'ملاحظة',
  'admin_note': 'ملاحظة الإدارة',
  'transfer_ref': 'رقم الحوالة',
  'scheduled_date': 'موعد التحويل',
  'iban': 'IBAN',
  'account_name': 'اسم الحساب',
  'bank_name': 'البنك',
  'plan': 'الباقة',
  'starts': 'من',
  'ends': 'إلى',
  'kind': 'النوع',
  'created_at': 'التاريخ',
  'confirmed_at': 'تاريخ التأكيد',
  'frozen_reason': 'سبب التجميد',
  'ctl_note': 'ملاحظة التحكم',
  'deleted_at': 'تاريخ الحذف',
  'orig_amount': 'المبلغ الأصلي',
};

const _kindLabels = <String, String>{
  'cash_receipt': 'استلام نقد من مندوب',
  'fee_payout': 'تسليم رسوم لمندوب',
  'merchant_commission': 'عمولة تاجر',
  'customer_commission': 'عمولة عميل',
  'subscription': 'اشتراك',
  'delivery_fee': 'رسوم توصيل',
  'pending': 'بانتظار التأكيد',
  'confirmed': 'مؤكدة',
  'requested': 'جديد',
  'under_review': 'قيد المراجعة',
  'approved': 'موافق عليه',
  'transferred': 'تم التحويل',
  'rejected': 'مرفوض',
};

String _show(String k, dynamic v) {
  if (v == null || '$v'.isEmpty) return '';
  if (k == 'amount' || k == 'orig_amount') return bhd(v);
  if (k == 'plan') return planLabels['$v'] ?? '$v';
  if (k == 'created_at' || k == 'confirmed_at' || k == 'deleted_at') {
    return dateTimeText(v);
  }
  if (k == 'starts' || k == 'ends' || k == 'scheduled_date') {
    return dateText(v);
  }
  return _kindLabels['$v'] ?? '$v';
}

/// The control buttons for one movement, plus a strip that says when it is
/// frozen or deleted. Renders nothing outside «التحكم الإداري».
class TxnActions extends StatelessWidget {
  const TxnActions(
      {super.key,
      required this.type,
      required this.row,
      required this.title,
      required this.reload,
      this.fields = const [],
      this.transfer,
      this.party = ''});

  /// settlement, payout, subscription or platform.
  final String type;
  final Map<String, dynamic> row;
  final String title;
  final Future<void> Function() reload;
  final List<TxnField> fields;

  /// driver or merchant; null when the movement cannot be moved.
  final String? transfer;

  /// Current driver / store name, shown in the view.
  final String party;

  String get id => '${row['id']}';

  Future<void> run(BuildContext context, ControlScope s, String action,
      Map<String, dynamic> data, String ok) async {
    if (await s.act(
        (t) => sb.rpc('ctl_txn', params: {
              'p_token': t,
              'p_type': type,
              'p_id': id,
              'p_action': action,
              'p_data': data,
            }),
        ok: ok)) {
      await reload();
    }
  }

  Future<void> view(BuildContext context) => showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (party.isNotEmpty) _kv('الطرف', party),
                    for (final e in _labels.entries)
                      if (_show(e.key, row[e.key]).isNotEmpty)
                        _kv(e.value, _show(e.key, row[e.key])),
                    if (txnFrozen(row)) _kv('الوضع', tr('مجمّدة')),
                  ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
          ],
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 130,
              child: Text(k,
                  style: const TextStyle(
                      color: Colors.black54, fontWeight: FontWeight.w600))),
          Expanded(
              child:
                  Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );

  Future<void> edit(BuildContext context, ControlScope s) async {
    final ctrls = {
      for (final f in fields)
        f.key: TextEditingController(
            text: row[f.from] == null
                ? ''
                : f.kind == 'date'
                    ? '${row[f.from]}'.split('T').first
                    : '${row[f.from]}'),
    };
    String plan = '${row['plan'] ?? 'monthly'}';
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('${tr('تعديل')} · $title'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final f in fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: switch (f.kind) {
                        'plan' => DropdownButtonFormField<String>(
                            initialValue: plan,
                            decoration: InputDecoration(labelText: tr(f.label)),
                            items: [
                              for (final p in planLabels.entries)
                                DropdownMenuItem(
                                    value: p.key, child: Text(p.value)),
                            ],
                            onChanged: (v) => set(() => plan = v ?? plan),
                          ),
                        'date' => TextFormField(
                            controller: ctrls[f.key],
                            readOnly: true,
                            decoration: InputDecoration(
                                labelText: tr(f.label),
                                suffixIcon: const Icon(Icons.event_outlined)),
                            onTap: () async {
                              final d = await showDatePicker(
                                  context: c,
                                  initialDate:
                                      DateTime.tryParse(ctrls[f.key]!.text) ??
                                          DateTime.now(),
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime(2035));
                              if (d != null) ctrls[f.key]!.text = isoDate(d);
                            },
                          ),
                        'amount' => Field(f.label, ctrls[f.key]!,
                            required: true,
                            ltr: true,
                            keyboard: const TextInputType.numberWithOptions(
                                decimal: true)),
                        _ => Field(f.label, ctrls[f.key]!, maxLines: 2),
                      },
                    ),
                  const Text(
                      'تُصحَّح الأرصدة المرتبطة بهذه الحركة تلقائياً، ويُسجَّل التعديل في سجل الأنشطة.',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton.icon(
                onPressed: () {
                  if (form.currentState!.validate()) Navigator.pop(c, true);
                },
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final data = <String, dynamic>{};
    for (final f in fields) {
      if (f.kind == 'plan') {
        data[f.key] = plan;
        continue;
      }
      final t = ctrls[f.key]!.text.trim();
      if (f.kind == 'amount') {
        final n = num.tryParse(t);
        if (n == null) {
          toast(context, 'المبلغ غير صحيح', error: true);
          return;
        }
        data[f.key] = n;
      } else {
        data[f.key] = t;
      }
    }
    await run(context, s, 'edit', data, 'تم حفظ التعديل');
  }

  Future<void> move(BuildContext context, ControlScope s) async {
    final drivers = transfer == 'driver';
    final opts = await guard(context, () async {
      if (drivers) {
        final r = await sb
            .from('user_roles')
            .select('user_id, profiles(full_name, phone, deleted_at)')
            .eq('role', 'driver');
        return [
          for (final d in r)
            if (d['profiles']?['deleted_at'] == null)
              (
                '${d['user_id']}',
                '${d['profiles']?['full_name'] ?? ''} · ${d['profiles']?['phone'] ?? ''}'
              )
        ];
      }
      final m = await sb.from('merchants').select('id, name').order('name');
      return [for (final x in m) ('${x['id']}', '${x['name']}')];
    });
    if (opts == null || !context.mounted) return;
    final cur = '${row[drivers ? 'driver_id' : 'merchant_id']}';
    String? to;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('${tr('نقل الحركة')} · $title'),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: to,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: tr(drivers ? 'إلى المندوب' : 'إلى المتجر')),
                items: [
                  for (final o in opts)
                    if (o.$1 != cur)
                      DropdownMenuItem(value: o.$1, child: Text(o.$2)),
                ],
                onChanged: (v) => set(() => to = v),
              ),
              const SizedBox(height: 10),
              Field('السبب (اختياري)', reason, maxLines: 2),
              const SizedBox(height: 6),
              Text(
                  drivers
                      ? 'ينتقل المبلغ من رصيد المندوب الحالي إلى المندوب الجديد.'
                      : 'ينتقل أثر المبلغ من محفظة المتجر الحالي إلى المتجر الجديد.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton.icon(
                onPressed: to == null ? null : () => Navigator.pop(c, true),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('نقل')),
          ],
        ),
      ),
    );
    if (ok != true || to == null || !context.mounted) return;
    await run(context, s, 'transfer', {'to': to, 'reason': reason.text.trim()},
        'تم نقل الحركة');
  }

  Future<void> toggle(BuildContext context, ControlScope s, String action,
      bool on, String verb) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${tr(verb)} · $title'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                switch ((action, on)) {
                  ('freeze', true) =>
                    'تتوقف الحركة ويُرفع أثرها من الأرصدة حتى تفك التجميد.',
                  ('freeze', false) => 'تعود الحركة سارية ويرجع أثرها للأرصدة.',
                  ('delete', true) =>
                    'تُحذف الحركة ويُعكس أثرها من الأرصدة. يمكنك استرجاعها لاحقاً من «محذوفة».',
                  _ => 'تعود الحركة كما كانت ويرجع أثرها للأرصدة.',
                },
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 10),
            Field('السبب (اختياري)', reason, maxLines: 2),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor:
                      action == 'delete' && on ? G.ruby.first : G.sky.first),
              onPressed: () => Navigator.pop(c, true),
              child: Text(verb)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await run(context, s, action, {'on': on, 'reason': reason.text.trim()},
        'تم: ${tr(verb)}');
  }

  @override
  Widget build(BuildContext context) {
    final s = ControlScope.of(context);
    final del = txnDeleted(row);
    final frozen = txnFrozen(row);
    final strip = del || frozen
        ? Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: (del ? G.ruby : G.sky).first.withValues(alpha: .1),
            ),
            child: Row(children: [
              Icon(del ? Icons.delete_outline : Icons.ac_unit,
                  size: 16, color: (del ? G.ruby : G.sky).first),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    del
                        ? '${tr('محذوفة')} · ${dateTimeText(row['deleted_at'])}'
                        : '${tr('مجمّدة')}${row['frozen_reason'] == null ? '' : ' · ${row['frozen_reason']}'}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: (del ? G.ruby : G.sky).first)),
              ),
            ]),
          )
        : null;
    if (s == null) return strip ?? const SizedBox.shrink();
    bool can(String k) => s.isSuper || s.can[k] != false;
    final buttons = <(String, IconData, List<Color>, VoidCallback?)>[
      ('عرض', Icons.visibility_outlined, G.midnight, () => view(context)),
      if (!del && fields.isNotEmpty)
        (
          'تعديل',
          Icons.edit_outlined,
          G.sapphire,
          can('edit') ? () => edit(context, s) : null
        ),
      if (!del && transfer != null)
        (
          'نقل',
          Icons.swap_horiz,
          G.violet,
          can('transfer') ? () => move(context, s) : null
        ),
      if (!del)
        (
          frozen ? 'فك التجميد' : 'تجميد',
          Icons.ac_unit,
          G.sky,
          can('hold')
              ? () => toggle(context, s, 'freeze', !frozen,
                  frozen ? 'فك التجميد' : 'تجميد')
              : null
        ),
      (
        del ? 'استرجاع' : 'حذف',
        del ? Icons.restore : Icons.delete_outline,
        del ? G.emerald : G.ruby,
        can('delete')
            ? () => toggle(context, s, 'delete', !del, del ? 'استرجاع' : 'حذف')
            : null
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (strip != null) strip,
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final b in buttons)
          _ActBtn(label: b.$1, icon: b.$2, colors: b.$3, onTap: b.$4),
      ]),
    ]);
  }
}

class _ActBtn extends StatelessWidget {
  const _ActBtn(
      {required this.label,
      required this.icon,
      required this.colors,
      required this.onTap});
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final off = onTap == null;
    return Tooltip(
      message: off ? tr('لا تملك صلاحية هذا الإجراء') : '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: off
                ? null
                : LinearGradient(colors: [
                    colors.last.withValues(alpha: .14),
                    colors.first.withValues(alpha: .10)
                  ]),
            color: off ? Colors.black.withValues(alpha: .04) : null,
            border: Border.all(
                color:
                    off ? Colors.black12 : colors.first.withValues(alpha: .35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: off ? Colors.black26 : colors.first),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: off ? Colors.black26 : colors.first)),
          ]),
        ),
      ),
    );
  }
}

/// Search, state filter (inside the control only) and sort over a list of
/// movements; [builder] gets the rows that pass.
class TxnSection extends StatefulWidget {
  const TxnSection(
      {super.key,
      required this.rows,
      required this.text,
      required this.builder,
      this.groups = const {},
      this.groupOf});
  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>) text;
  final Widget Function(BuildContext, List<Map<String, dynamic>>) builder;

  /// Optional extra filter, e.g. by kind: key -> (label, icon, colors).
  final Map<String, (String, IconData, List<Color>)> groups;
  final String Function(Map<String, dynamic>)? groupOf;
  @override
  State<TxnSection> createState() => _TxnSectionState();
}

class _TxnSectionState extends State<TxnSection> {
  final q = TextEditingController();
  String state = 'all';
  String sort = 'new';
  String group = '';

  static const sorts = <String, (String, IconData)>{
    'new': ('الأحدث', Icons.south),
    'old': ('الأقدم', Icons.north),
    'high': ('الأعلى مبلغاً', Icons.trending_up),
    'low': ('الأقل مبلغاً', Icons.trending_down),
  };

  @override
  Widget build(BuildContext context) {
    final ctl = ControlScope.of(context) != null;
    final b = brandOf(context);
    final st = ctl ? state : 'all';
    final base = widget.rows
        .where((r) =>
            group.isEmpty ||
            widget.groupOf == null ||
            widget.groupOf!(r) == group)
        .toList();
    final counts = {
      for (final k in txnStates.keys)
        k: base.where((r) => txnMatch(r, k)).length
    };
    final text = q.text.trim().toLowerCase();
    final out = base
        .where((r) => txnMatch(r, st))
        .where(
            (r) => text.isEmpty || widget.text(r).toLowerCase().contains(text))
        .toList();
    int byDate(Map a, Map b) =>
        '${b['created_at']}'.compareTo('${a['created_at']}');
    out.sort(switch (sort) {
      'old' => (a, b) => -byDate(a, b),
      'high' => (a, b) => toNum(b['amount']).compareTo(toNum(a['amount'])),
      'low' => (a, b) => toNum(a['amount']).compareTo(toNum(b['amount'])),
      _ => byDate,
    });
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: q,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: tr('بحث بالاسم أو الرقم أو المبلغ أو الملاحظة'),
            isDense: true),
      ),
      const SizedBox(height: 10),
      if (ctl) ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final e in txnStates.entries)
              TonePill(
                  label: e.value.$1,
                  icon: e.value.$2,
                  colors: e.value.$3,
                  count: counts[e.key] ?? 0,
                  selected: state == e.key,
                  onTap: () => setState(() => state = e.key)),
          ]),
        ),
        const SizedBox(height: 8),
      ],
      if (widget.groups.isNotEmpty) ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            TonePill(
                label: 'كل الأنواع',
                icon: Icons.category_outlined,
                colors: G.midnight,
                selected: group.isEmpty,
                onTap: () => setState(() => group = '')),
            for (final e in widget.groups.entries)
              TonePill(
                  label: e.value.$1,
                  icon: e.value.$2,
                  colors: e.value.$3,
                  selected: group == e.key,
                  onTap: () => setState(() => group = e.key)),
          ]),
        ),
        const SizedBox(height: 8),
      ],
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final e in sorts.entries)
            TonePill(
                label: e.value.$1,
                icon: e.value.$2,
                colors: b.stops.sublist(1),
                selected: sort == e.key,
                onTap: () => setState(() => sort = e.key)),
        ]),
      ),
      const SizedBox(height: 12),
      if (out.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا توجد حركات بهذا التصنيف',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45)),
        )
      else
        widget.builder(context, out),
    ]);
  }
}
