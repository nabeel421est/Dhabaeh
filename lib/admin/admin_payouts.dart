import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/common.dart';
import '../core/payouts.dart';
import '../core/i18n.dart';
import '../core/ttext.dart';
import 'admin_txn_control.dart';

/// Merchants' withdrawal requests: review, approve with a transfer date, mark transferred, or reject.
class AdminPayouts extends StatefulWidget {
  const AdminPayouts({super.key});
  @override
  State<AdminPayouts> createState() => _AdminPayoutsState();
}

class _AdminPayoutsState extends State<AdminPayouts> {
  String filter = 'open';

  @override
  Widget build(BuildContext context) {
    final ctl = ControlScope.of(context) != null;
    return Loader<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
      key: ValueKey(ctl),
      realtimeTables: const ['payout_requests', 'payout_events'],
      load: () async {
        var q = sb.from('payout_requests').select('*, merchants(name, frozen)');
        if (!ctl) q = q.isFilter('deleted_at', null);
        final reqs = await q.order('created_at', ascending: false);
        final evs = await sb.from('payout_events').select().order('created_at');
        return (
          List<Map<String, dynamic>>.from(reqs),
          List<Map<String, dynamic>>.from(evs)
        );
      },
      builder: (context, data, reload) {
        final (all, evs) = data;
        final reqs = all.where((r) => !txnDeleted(r)).toList();
        bool open(Map r) =>
            ['requested', 'under_review', 'approved'].contains(r['status']);
        bool inFilter(Map r, String f) => switch (f) {
              'deleted' => txnDeleted(r),
              'frozen' => txnFrozen(r),
              'all' => !txnDeleted(r),
              'open' => !txnDeleted(r) && open(r),
              _ => !txnDeleted(r) && r['status'] == f,
            };
        num sumOf(Iterable<Map> rs) =>
            rs.fold<num>(0, (a, r) => a + toNum(r['amount']));
        final shown = all.where((r) => inFilter(r, filter)).toList();
        final filters = {
          'open': 'المفتوحة',
          ...payoutLabels,
          'all': 'الكل',
          if (ctl) 'frozen': 'مجمّدة',
          if (ctl) 'deleted': 'محذوفة',
        };
        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon: Icons.outbox_outlined,
            title: 'طلبات السحب',
            subtitle:
                'طلبات التجار لتحويل أرصدتهم، ومراحل كل طلب تظهر للتاجر في محفظته',
            stats: [
              (
                'جديدة',
                '${reqs.where((r) => r['status'] == 'requested').length}'
              ),
              ('مفتوحة', bhd(sumOf(reqs.where(open)))),
              (
                'بانتظار التحويل',
                '${reqs.where((r) => r['status'] == 'approved').length}'
              ),
              (
                'تم تحويله',
                bhd(sumOf(reqs.where((r) => r['status'] == 'transferred')))
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final f in filters.entries)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: _FilterPill(
                    label: f.value,
                    count: all.where((r) => inFilter(r, f.key)).length,
                    colors: f.key == 'open' || f.key == 'all'
                        ? brandOf(context).stops.sublist(1)
                        : f.key == 'frozen'
                            ? G.sky
                            : f.key == 'deleted'
                                ? G.ruby
                                : payoutColors(f.key),
                    selected: filter == f.key,
                    onTap: () => setState(() => filter = f.key),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            const Empty('لا توجد طلبات هنا', icon: Icons.outbox_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 440).floor().clamp(1, 3);
            final w = (c.maxWidth - 14 * (cols - 1)) / cols;
            return Wrap(spacing: 14, runSpacing: 14, children: [
              for (final r in shown)
                SizedBox(
                  width: w,
                  child: PayoutCard(
                    r: r,
                    merchantName: r['merchants']?['name'],
                    events:
                        evs.where((e) => e['request_id'] == r['id']).toList(),
                    action: !ctl && !(open(r) && txnActive(r)) && txnActive(r)
                        ? null
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                if (open(r) && txnActive(r))
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                        backgroundColor:
                                            payoutColors('${r['status']}')
                                                .first),
                                    onPressed: () async {
                                      await processPayout(context, r);
                                      await reload();
                                    },
                                    icon: const Icon(Icons.task_alt, size: 18),
                                    label: const Text('معالجة الطلب'),
                                  ),
                                TxnActions(
                                  type: 'payout',
                                  row: r,
                                  title: '${tr('طلب سحب')} #${r['code']}',
                                  party: '${r['merchants']?['name'] ?? ''}',
                                  reload: reload,
                                  transfer: 'merchant',
                                  fields: const [
                                    TxnField('amount', 'المبلغ (د.ب)',
                                        kind: 'amount'),
                                    TxnField('scheduled_date', 'موعد التحويل',
                                        kind: 'date'),
                                    TxnField('transfer_ref', 'رقم الحوالة'),
                                    TxnField('note', 'ملاحظة الإدارة',
                                        src: 'admin_note'),
                                  ],
                                ),
                              ]),
                  ),
                ),
            ]);
          }),
        ]);
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill(
      {required this.label,
      required this.count,
      required this.colors,
      required this.selected,
      required this.onTap});
  final String label;
  final int count;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected ? LinearGradient(colors: colors) : null,
            color: selected ? null : Colors.white,
            border: Border.all(
                color: selected
                    ? Colors.transparent
                    : colors.first.withValues(alpha: .3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : colors.first)),
            if (count >= 0) const SizedBox(width: 6),
            if (count >= 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: .25)
                        : colors.first.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(999)),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : colors.first)),
              ),
          ]),
        ),
      );
}

/// The processing dialog: pick the next stage; approval needs a date, transfer takes a reference, rejection needs a reason.
Future<void> processPayout(BuildContext context, Map<String, dynamic> r) async {
  final current = '${r['status']}';
  final next = [
    if (current == 'requested') 'under_review',
    if (current != 'approved') 'approved',
    'transferred',
    'rejected',
  ];
  String pick = next.first;
  DateTime? date = r['scheduled_date'] == null
      ? DateTime.now().add(const Duration(days: 2))
      : DateTime.parse(r['scheduled_date']);
  final note = TextEditingController();
  final ref = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) {
        final colors = payoutColors(pick);
        return AlertDialog(
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22))),
            child: Row(children: [
              const Icon(Icons.task_alt, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    'طلب #${r['code']} · ${r['merchants']?['name'] ?? ''} · ${bhd(r['amount'])}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
            ]),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('المرحلة الحالية: ${payoutLabels[current]}',
                        style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 12),
                    const Text('انقل الطلب إلى',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in next)
                        _FilterPill(
                            label: payoutLabels[s]!,
                            count: -1,
                            colors: payoutColors(s),
                            selected: pick == s,
                            onTap: () => set(() => pick = s)),
                    ]),
                    const SizedBox(height: 16),
                    if (pick == 'approved') ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.event_outlined),
                        onPressed: () async {
                          final d = await showDatePicker(
                              context: c,
                              initialDate: date ?? DateTime.now(),
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 1)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 120)));
                          if (d != null) set(() => date = d);
                        },
                        label: Text(date == null
                            ? 'حدّد موعد التحويل'
                            : 'موعد التحويل: ${dateText(isoDate(date!))}'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (pick == 'transferred') ...[
                      Field('رقم الحوالة البنكية', ref, ltr: true),
                      const SizedBox(height: 6),
                      Text(
                          'يُخصم ${bhd(r['amount'])} من محفظة التاجر عند الحفظ.',
                          style: TextStyle(
                              fontSize: 12,
                              color: colors.first,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                    ],
                    Field(
                        pick == 'rejected'
                            ? 'سبب الرفض *'
                            : 'ملاحظة تظهر للتاجر',
                        note,
                        maxLines: 2),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF5F8FA),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                          'يحوَّل إلى: ${r['bank_name'] ?? ''} · ${r['account_name'] ?? ''}\n${r['iban'] ?? ''}',
                          style: const TextStyle(fontSize: 12.5, height: 1.5)),
                    ),
                  ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: colors.first),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('حفظ المرحلة')),
          ],
        );
      },
    ),
  );
  if (ok != true || !context.mounted) return;
  await guard(
      context,
      () => sb.rpc('admin_process_payout', params: {
            'p_request': r['id'],
            'p_status': pick,
            'p_note': note.text.trim(),
            'p_date':
                pick == 'approved' && date != null ? isoDate(date!) : null,
            'p_ref': ref.text.trim(),
          }),
      ok: 'تم تحديث الطلب، ويشوف التاجر المرحلة في محفظته');
}
