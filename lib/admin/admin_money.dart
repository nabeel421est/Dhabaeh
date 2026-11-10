import 'package:flutter/material.dart';

import '../core/common.dart';

class AdminReports extends StatelessWidget {
  const AdminReports({super.key});
  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['orders'],
      load: () async => List<Map<String, dynamic>>.from(await sb.rpc('admin_merchant_summary')),
      builder: (context, rows, _) {
        num sum(String k) => rows.fold<num>(0, (a, r) => a + toNum(r[k]));
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('الطلبات المسلّمة فقط', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(columns: const [
                DataColumn(label: Text('التاجر')),
                DataColumn(label: Text('الطلبات'), numeric: true),
                DataColumn(label: Text('المبيعات'), numeric: true),
                DataColumn(label: Text('عمولة التاجر'), numeric: true),
                DataColumn(label: Text('عمولة العميل'), numeric: true),
                DataColumn(label: Text('التوصيل'), numeric: true),
                DataColumn(label: Text('صافي التاجر'), numeric: true),
                DataColumn(label: Text('الرصيد الحالي'), numeric: true),
              ], rows: [
                for (final r in rows)
                  DataRow(cells: [
                    DataCell(Text(r['name'])),
                    DataCell(Text('${r['orders_count']}')),
                    DataCell(Text(bhd(r['sales']))),
                    DataCell(Text(bhd(r['merchant_comm']))),
                    DataCell(Text(bhd(r['customer_comm']))),
                    DataCell(Text(bhd(r['delivery_fees']))),
                    DataCell(Text(bhd(r['net']))),
                    DataCell(Text(bhd(r['balance']))),
                  ]),
                DataRow(cells: [
                  const DataCell(Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w700))),
                  DataCell(Text('${sum('orders_count')}')),
                  DataCell(Text(bhd(sum('sales')))),
                  DataCell(Text(bhd(sum('merchant_comm')))),
                  DataCell(Text(bhd(sum('customer_comm')))),
                  DataCell(Text(bhd(sum('delivery_fees')))),
                  DataCell(Text(bhd(sum('net')))),
                  DataCell(Text(bhd(sum('balance')))),
                ]),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

class PlatformWallet extends StatelessWidget {
  const PlatformWallet({super.key});
  static const kinds = {
    'merchant_commission': 'عمولات التجار',
    'customer_commission': 'عمولات العملاء',
    'subscription': 'الاشتراكات',
    'delivery_fee': 'رسوم التوصيل',
  };
  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['platform_ledger'],
      load: () async => List<Map<String, dynamic>>.from(await sb.from('platform_ledger').select('*, merchants(name), orders(code)').order('created_at', ascending: false)),
      builder: (context, rows, _) {
        final total = rows.fold<num>(0, (a, r) => a + toNum(r['amount']));
        return ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('رصيد محفظة المنصة', style: TextStyle(color: Colors.black54)),
              Text(bhd(total), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF4B4380))),
              const SizedBox(height: 8),
              for (final k in kinds.entries)
                KeyVal(k.value, bhd(rows.where((r) => r['kind'] == k.key).fold<num>(0, (a, r) => a + toNum(r['amount'])))),
            ]),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'تقرير المبالغ المحصّلة',
            child: Column(children: [
              if (rows.isEmpty) const Text('لا توجد مبالغ محصّلة بعد'),
              for (final r in rows.take(200))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${kinds[r['kind']]} · ${r['merchants']?['name'] ?? ''}${r['orders'] != null ? ' · طلب #${r['orders']['code']}' : ''}'),
                  subtitle: Text(dateTimeText(r['created_at'])),
                  trailing: Text(bhd(r['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
        ]);
      },
    );
  }
}

class AdminPlans extends StatelessWidget {
  const AdminPlans({super.key});
  @override
  Widget build(BuildContext context) {
    return Loader<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
      realtimeTables: const ['subscriptions'],
      load: () async {
        final s = await sb.from('platform_settings').select().eq('id', 1).single();
        final subs = await sb.from('subscriptions').select('*, merchants(name)').order('created_at', ascending: false);
        return (s, List<Map<String, dynamic>>.from(subs));
      },
      builder: (context, data, reload) {
        final (s, subs) = data;
        final trial = TextEditingController(text: '${s['trial_days']}');
        final monthly = TextEditingController(text: '${s['monthly_price']}');
        final yearly = TextEditingController(text: '${s['yearly_price']}');
        return ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(
            title: 'خطط الاشتراك',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(width: 200, child: Field('أيام الفترة التجريبية', trial, keyboard: TextInputType.number)),
                SizedBox(width: 200, child: Field('سعر الشهري (د.ب)', monthly, keyboard: TextInputType.number)),
                SizedBox(width: 200, child: Field('سعر السنوي (د.ب)', yearly, keyboard: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton(
                  onPressed: () async {
                    await guard(context, () => sb.from('platform_settings').update({
                          'trial_days': int.tryParse(trial.text) ?? 14,
                          'monthly_price': num.tryParse(monthly.text) ?? 0,
                          'yearly_price': num.tryParse(yearly.text) ?? 0,
                          'updated_at': DateTime.now().toIso8601String(),
                        }).eq('id', 1), ok: 'تم الحفظ');
                    await reload();
                  },
                  child: const Text('حفظ'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'تقرير الاشتراكات',
            child: Column(children: [
              if (subs.isEmpty) const Text('لا توجد اشتراكات بعد'),
              for (final r in subs)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${r['merchants']?['name'] ?? ''} · ${planLabels[r['plan']]}'),
                  subtitle: Text('${dateText(r['starts'])} إلى ${dateText(r['ends'])}'),
                  trailing: Text(bhd(r['amount'])),
                ),
            ]),
          ),
        ]);
      },
    );
  }
}

class AdminCommissions extends StatelessWidget {
  const AdminCommissions({super.key});
  @override
  Widget build(BuildContext context) {
    return Loader<Map<String, dynamic>>(
      load: () async => await sb.from('platform_settings').select().eq('id', 1).single(),
      builder: (context, s, reload) => ListView(padding: const EdgeInsets.all(16), children: [
        _CommCard(who: 'merchant', title: 'عمولة التاجر', note: 'تُخصم من قيمة الطلب قبل إضافته لمحفظة التاجر', s: s, reload: reload),
        const SizedBox(height: 12),
        _CommCard(who: 'customer', title: 'عمولة العميل', note: 'تُضاف على فاتورة العميل كرسوم خدمة', s: s, reload: reload),
        const SizedBox(height: 12),
        _IbanCard(s: s, reload: reload),
      ]),
    );
  }
}

class _CommCard extends StatefulWidget {
  const _CommCard({required this.who, required this.title, required this.note, required this.s, required this.reload});
  final String who, title, note;
  final Map<String, dynamic> s;
  final Future<void> Function() reload;
  @override
  State<_CommCard> createState() => _CommCardState();
}

class _CommCardState extends State<_CommCard> {
  late bool enabled = widget.s['${widget.who}_comm_enabled'] == true;
  late String type = widget.s['${widget.who}_comm_type'];
  late final value = TextEditingController(text: '${widget.s['${widget.who}_comm_value']}');
  @override
  Widget build(BuildContext context) => SectionCard(
        title: widget.title,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.note, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(enabled ? 'مفعّلة' : 'متوقفة'), value: enabled, onChanged: (v) => setState(() => enabled = v)),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'percent', label: Text('نسبة %')), ButtonSegment(value: 'fixed', label: Text('مبلغ ثابت'))],
            selected: {type},
            onSelectionChanged: (x) => setState(() => type = x.first),
          ),
          const SizedBox(height: 10),
          Field(type == 'percent' ? 'النسبة %' : 'المبلغ (د.ب)', value, keyboard: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
              onPressed: () async {
                await guard(context, () => sb.from('platform_settings').update({
                      '${widget.who}_comm_enabled': enabled,
                      '${widget.who}_comm_type': type,
                      '${widget.who}_comm_value': num.tryParse(value.text) ?? 0,
                    }).eq('id', 1), ok: 'تم الحفظ، تُطبّق على الطلبات الجديدة');
                await widget.reload();
              },
              child: const Text('حفظ'),
            ),
          ),
        ]),
      );
}

class _IbanCard extends StatelessWidget {
  const _IbanCard({required this.s, required this.reload});
  final Map<String, dynamic> s;
  final Future<void> Function() reload;
  @override
  Widget build(BuildContext context) {
    final iban = TextEditingController(text: s['platform_iban'] ?? '');
    return SectionCard(
      title: 'حساب المنصة للتحويل البنكي',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field('IBAN يظهر للعميل عند اختيار التحويل البنكي', iban, ltr: true),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            onPressed: () async {
              await guard(context, () => sb.from('platform_settings').update({'platform_iban': iban.text.trim()}).eq('id', 1), ok: 'تم الحفظ');
              await reload();
            },
            child: const Text('حفظ'),
          ),
        ),
      ]),
    );
  }
}

class AdminZones extends StatelessWidget {
  const AdminZones({super.key});
  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      load: () async => List<Map<String, dynamic>>.from(await sb.from('delivery_zones').select().order('name')),
      builder: (context, zones, reload) {
        final name = TextEditingController();
        final fee = TextEditingController();
        return ListView(padding: const EdgeInsets.all(16), children: [
          SectionCard(
            title: 'إضافة منطقة',
            child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 220, child: Field('المنطقة', name)),
              SizedBox(width: 160, child: Field('رسوم التوصيل (د.ب)', fee, keyboard: const TextInputType.numberWithOptions(decimal: true))),
              FilledButton(
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  await guard(context, () => sb.from('delivery_zones').insert({'name': name.text.trim(), 'fee': num.tryParse(fee.text) ?? 0}), ok: 'تمت الإضافة');
                  await reload();
                },
                child: const Text('إضافة'),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'رسوم التوصيل حسب المنطقة',
            child: Column(children: [
              for (final z in zones) _ZoneRow(z: z, reload: reload),
            ]),
          ),
        ]);
      },
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.z, required this.reload});
  final Map<String, dynamic> z;
  final Future<void> Function() reload;
  @override
  Widget build(BuildContext context) {
    final fee = TextEditingController(text: '${z['fee']}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(z['name'])),
        SizedBox(
          width: 110,
          child: TextField(
            controller: fee,
            decoration: const InputDecoration(isDense: true, suffixText: 'د.ب'),
            onSubmitted: (v) async {
              await guard(context, () => sb.from('delivery_zones').update({'fee': num.tryParse(v) ?? 0}).eq('id', z['id']), ok: 'تم التحديث');
              await reload();
            },
          ),
        ),
        Switch(
          value: z['active'] == true,
          onChanged: (v) async {
            await guard(context, () => sb.from('delivery_zones').update({'active': v}).eq('id', z['id']));
            await reload();
          },
        ),
      ]),
    );
  }
}
