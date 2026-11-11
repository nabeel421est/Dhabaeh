import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/common.dart';
import '../core/ttext.dart';

/// Shared page for the two driver settlements:
/// cash: the admin receives cash-on-delivery money a driver collected (effective at once);
/// fees: the admin hands delivery fees to a driver, who confirms receipt in the driver app.
class AdminDriverMoney extends StatelessWidget {
  const AdminDriverMoney({super.key, required this.fees});
  final bool fees;

  List<Color> get tone => fees ? G.emerald : G.amber;

  Future<void> settle(BuildContext context, Map<String, dynamic> d, num max,
      Future<void> Function() reload) async {
    final amount = TextEditingController(text: max.toStringAsFixed(3));
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: tone),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22))),
          child: Row(children: [
            Icon(fees ? Icons.south_west : Icons.call_received,
                color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  fees
                      ? 'تسليم رسوم التوصيل · ${d['full_name']}'
                      : 'استلام مبالغ التحصيل · ${d['full_name']}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    fees
                        ? 'المستحق للمندوب: ${bhd(max)}'
                        : 'النقد الذي بحوزة المندوب: ${bhd(max)}',
                    style: TextStyle(
                        color: tone.first, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    fees
                        ? 'تظهر للمندوب نافذة بارزة في تطبيقه حتى يضغط "تم الاستلام"، وبعدها تُخصم من مستحقاته.'
                        : 'يُخصم المبلغ من النقد الذي بحوزة المندوب فوراً، ويوصله إشعار بالاستلام.',
                    style:
                        const TextStyle(fontSize: 12.5, color: Colors.black54)),
                const SizedBox(height: 14),
                Field('المبلغ (د.ب)', amount,
                    required: true,
                    ltr: true,
                    keyboard:
                        const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 10),
                Field(fees ? 'ملاحظة للمندوب' : 'ملاحظة', note, maxLines: 2),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: tone.first),
              onPressed: () => Navigator.pop(c, true),
              icon: const Icon(Icons.task_alt, size: 18),
              label: Text(fees ? 'تسليم' : 'تم الاستلام')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await guard(
        context,
        () => sb.rpc(fees ? 'admin_pay_driver_fees' : 'admin_receive_cash',
                params: {
                  'p_driver': d['driver_id'],
                  'p_amount': num.tryParse(amount.text.trim()) ?? 0,
                  'p_note': note.text.trim(),
                }),
        ok: fees
            ? 'تم التسليم، وبانتظار تأكيد المندوب'
            : 'تم تسجيل استلام المبلغ');
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Loader<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
      key: ValueKey(fees),
      realtimeTables: const ['driver_ledger', 'driver_settlements'],
      load: () async {
        final b = await sb.rpc('admin_driver_balances');
        final s = await sb
            .from('driver_settlements')
            .select('*, profiles(full_name)')
            .eq('kind', fees ? 'fee_payout' : 'cash_receipt')
            .order('created_at', ascending: false)
            .limit(100);
        return (
          List<Map<String, dynamic>>.from(b ?? []),
          List<Map<String, dynamic>>.from(s)
        );
      },
      builder: (context, data, reload) {
        final (drivers, sets) = data;
        num avail(Map d) => fees
            ? toNum(d['fees_due']) - toNum(d['pending_payout'])
            : toNum(d['cash_held']);
        final total = drivers.fold<num>(0, (a, d) => a + avail(d));
        final pending = sets.where((s) => s['status'] == 'pending');
        final done = sets.fold<num>(
            0,
            (a, s) =>
                a + (s['status'] == 'confirmed' ? toNum(s['amount']) : 0));
        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon:
                fees ? Icons.delivery_dining_outlined : Icons.payments_outlined,
            title: fees ? 'رسوم المناديب' : 'مبالغ الدفع عند الاستلام',
            subtitle: fees
                ? 'سلّم كل مندوب رسوم التوصيل المستحقة له، ويؤكد الاستلام من تطبيقه'
                : 'استلم من المناديب المبالغ التي حصّلوها نقداً من العملاء',
            stats: [
              (fees ? 'مستحق للمناديب' : 'بحوزة المناديب', bhd(total)),
              if (fees) ('بانتظار التأكيد', '${pending.length}'),
              (fees ? 'تم تسليمه' : 'تم استلامه', bhd(done)),
              ('المناديب', '${drivers.length}'),
            ],
          ),
          const SizedBox(height: 16),
          if (drivers.isEmpty)
            const Empty('لا يوجد مناديب', icon: Icons.delivery_dining_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 340).floor().clamp(1, 4);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final d in drivers)
                SizedBox(
                  width: w,
                  child: _DriverCard(
                    d: d,
                    fees: fees,
                    colors: tone,
                    available: avail(d),
                    onSettle: avail(d) <= 0
                        ? null
                        : () => settle(context, d, avail(d), reload),
                  ),
                ),
            ]);
          }),
          const SizedBox(height: 20),
          Row(children: [
            GradientBadge(colors: tone, icon: Icons.history, size: 34),
            const SizedBox(width: 8),
            Text(fees ? 'سجل تسليم الرسوم' : 'سجل الاستلام',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          if (sets.isEmpty)
            const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('لا توجد عمليات بعد',
                      style: TextStyle(color: Colors.black54))),
            ),
          for (final s in sets)
            Card(
              child: ListTile(
                leading: GradientBadge(
                    colors: s['status'] == 'pending' ? G.amber : tone,
                    icon: s['status'] == 'pending'
                        ? Icons.hourglass_bottom
                        : Icons.task_alt,
                    size: 40),
                title: Text(
                    '#${s['code']} · ${s['profiles']?['full_name'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text([
                  dateTimeText(s['created_at']),
                  if (s['status'] == 'pending')
                    'بانتظار تأكيد المندوب'
                  else if (fees)
                    'أكّد الاستلام ${dateTimeText(s['confirmed_at'])}',
                  if ('${s['note'] ?? ''}'.isNotEmpty) '${s['note']}',
                ].join(' · ')),
                trailing: Text(bhd(s['amount']),
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: tone.first)),
              ),
            ),
        ]);
      },
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard(
      {required this.d,
      required this.fees,
      required this.colors,
      required this.available,
      required this.onSettle});
  final Map<String, dynamic> d;
  final bool fees;
  final List<Color> colors;
  final num available;
  final VoidCallback? onSettle;
  @override
  Widget build(BuildContext context) {
    final name = '${d['full_name'] ?? ''}';
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: colors)),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white.withValues(alpha: .2),
              child: Text(name.isEmpty ? '?' : name.characters.first,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    Text('${d['phone'] ?? ''}',
                        style: const TextStyle(color: Colors.white70)),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fees ? 'المستحق' : 'بحوزته',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(bhd(available),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _stat(fees ? 'طلبات موصّلة' : 'طلبات نقدية',
                  '${fees ? d['delivered'] : d['cash_orders']}'),
              _stat(fees ? 'بانتظار تأكيده' : 'رسوم مستحقة له',
                  fees ? bhd(d['pending_payout']) : bhd(d['fees_due'])),
            ]),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: colors.first),
              onPressed: onSettle,
              icon:
                  Icon(fees ? Icons.south_west : Icons.call_received, size: 18),
              label: Text(onSettle == null
                  ? (fees ? 'لا توجد رسوم مستحقة' : 'لا يوجد مبلغ للاستلام')
                  : (fees ? 'تسليم الرسوم' : 'استلام المبلغ')),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(String k, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(v,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
      );
}
