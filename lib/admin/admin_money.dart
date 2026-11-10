import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/common.dart';

/// Gradient pairs used to tell merchants apart in the reports, in rank order.
const reportGradients = <List<Color>>[
  [Color(0xFF8C6A12), Color(0xFFD4AF37)], // gold
  [Color(0xFF0D6152), Color(0xFF3CC4A0)], // emerald
  [Color(0xFF8E2442), Color(0xFFE07A86)], // ruby
  [Color(0xFF1C4790), Color(0xFF5FA6F2)], // sapphire
  [Color(0xFF9A4A12), Color(0xFFF2A65A)], // amber
  [Color(0xFF136A82), Color(0xFF5CC8DA)], // teal
];

class AdminReports extends StatelessWidget {
  const AdminReports({super.key});
  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['orders'],
      load: () async => List<Map<String, dynamic>>.from(
          await sb.rpc('admin_merchant_summary')),
      builder: (context, raw, _) {
        final rows = [...raw]
          ..sort((a, b) => toNum(b['sales']).compareTo(toNum(a['sales'])));
        num sum(String k) => rows.fold<num>(0, (a, r) => a + toNum(r[k]));
        final sales = sum('sales');
        final platform = sum('merchant_comm') + sum('customer_comm');
        final b = brandOf(context);
        return ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Icon(Icons.insights_outlined, color: b.accent),
            const SizedBox(width: 8),
            const Text('أداء التجار',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const Spacer(),
            const Text('الطلبات المسلّمة فقط',
                style: TextStyle(color: Colors.black45, fontSize: 12)),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 4 : 2;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final k in [
                (
                  'إجمالي المبيعات',
                  bhd(sales),
                  Icons.payments_outlined,
                  reportGradients[0]
                ),
                (
                  'عمولات المنصة',
                  bhd(platform),
                  Icons.account_balance_outlined,
                  reportGradients[1]
                ),
                (
                  'صافي التجار',
                  bhd(sum('net')),
                  Icons.storefront_outlined,
                  reportGradients[3]
                ),
                (
                  'الطلبات',
                  '${sum('orders_count')}',
                  Icons.receipt_long_outlined,
                  reportGradients[2]
                ),
              ])
                SizedBox(
                    width: w,
                    child: Kpi(
                        label: k.$1, value: k.$2, icon: k.$3, colors: k.$4)),
            ]);
          }),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            const Empty('لا توجد مبيعات مسلّمة بعد',
                icon: Icons.insights_outlined),
          if (rows.isNotEmpty)
            SectionCard(
              title: 'حصة كل تاجر من المبيعات',
              child: Column(children: [
                for (var i = 0; i < rows.length; i++)
                  ShareBar(
                      name: rows[i]['name'],
                      value: toNum(rows[i]['sales']),
                      total: sales,
                      colors: reportGradients[i % reportGradients.length]),
              ]),
            ),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 2 : 1;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (var i = 0; i < rows.length; i++)
                SizedBox(
                    width: w,
                    child: _MerchantReport(
                        rank: i + 1,
                        r: rows[i],
                        total: sales,
                        colors: reportGradients[i % reportGradients.length])),
            ]);
          }),
          const SizedBox(height: 14),
          if (rows.isNotEmpty)
            Card(
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, c) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: c.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStatePropertyAll(b.dark),
                      headingTextStyle: TextStyle(
                          color: b.accent, fontWeight: FontWeight.w700),
                      columns: const [
                        DataColumn(label: Text('التاجر')),
                        DataColumn(label: Text('الطلبات'), numeric: true),
                        DataColumn(label: Text('المبيعات'), numeric: true),
                        DataColumn(label: Text('عمولة التاجر'), numeric: true),
                        DataColumn(label: Text('عمولة العميل'), numeric: true),
                        DataColumn(label: Text('التوصيل'), numeric: true),
                        DataColumn(label: Text('صافي التاجر'), numeric: true),
                        DataColumn(label: Text('الرصيد الحالي'), numeric: true),
                      ],
                      rows: [
                        for (var i = 0; i < rows.length; i++)
                          DataRow(
                            color: WidgetStatePropertyAll(
                                i.isOdd ? b.surface : Colors.white),
                            cells: [
                              DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                                colors: reportGradients[i %
                                                    reportGradients.length]))),
                                    const SizedBox(width: 8),
                                    Text(rows[i]['name']),
                                  ])),
                              DataCell(Text('${rows[i]['orders_count']}')),
                              DataCell(Text(bhd(rows[i]['sales']))),
                              DataCell(Text(bhd(rows[i]['merchant_comm']))),
                              DataCell(Text(bhd(rows[i]['customer_comm']))),
                              DataCell(Text(bhd(rows[i]['delivery_fees']))),
                              DataCell(Text(bhd(rows[i]['net']))),
                              DataCell(Text(bhd(rows[i]['balance']))),
                            ],
                          ),
                        DataRow(
                          color: WidgetStatePropertyAll(
                              Color.lerp(b.accent, Colors.white, .8)),
                          cells: [
                            const DataCell(Text('الإجمالي',
                                style: TextStyle(fontWeight: FontWeight.w700))),
                            for (final k in [
                              'orders_count',
                              'sales',
                              'merchant_comm',
                              'customer_comm',
                              'delivery_fees',
                              'net',
                              'balance'
                            ])
                              DataCell(Text(
                                  k == 'orders_count'
                                      ? '${sum(k)}'
                                      : bhd(sum(k)),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

class Kpi extends StatelessWidget {
  const Kpi(
      {required this.label,
      required this.value,
      required this.icon,
      required this.colors});
  final String label;
  final String value;
  final IconData icon;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: colors),
          boxShadow: [
            BoxShadow(
                color: colors.first.withValues(alpha: .3),
                blurRadius: 16,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .85),
                      fontSize: 13)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      );
}

class ShareBar extends StatelessWidget {
  const ShareBar(
      {required this.name,
      required this.value,
      required this.total,
      required this.colors});
  final String name;
  final num value;
  final num total;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : (value / total).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(bhd(value), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          SizedBox(
              width: 44,
              child: Text('${(share * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: Colors.black54))),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(children: [
            Container(height: 12, color: const Color(0xFFEDEAE3)),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: share.clamp(0.0, 1.0),
              child: Container(
                  height: 12,
                  decoration:
                      BoxDecoration(gradient: LinearGradient(colors: colors))),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _MerchantReport extends StatelessWidget {
  const _MerchantReport(
      {required this.rank,
      required this.r,
      required this.total,
      required this.colors});
  final int rank;
  final Map<String, dynamic> r;
  final num total;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0 : (toNum(r['sales']) / total * 100).round();
    Widget item(String k, String v) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k,
                style: const TextStyle(fontSize: 12, color: Colors.black45)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: colors)),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .25),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .7))),
              child: Text('$rank',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(r['name'],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700))),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(bhd(r['sales']),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              Text('$share% من المبيعات',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .85),
                      fontSize: 12)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              item('الطلبات', '${r['orders_count']}'),
              item('عمولة التاجر', bhd(r['merchant_comm'])),
              item('عمولة العميل', bhd(r['customer_comm'])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              item('التوصيل', bhd(r['delivery_fees'])),
              item('صافي التاجر', bhd(r['net'])),
              item('الرصيد الحالي', bhd(r['balance'])),
            ]),
          ]),
        ),
      ]),
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
  static const kindLook = <String, (IconData, List<Color>)>{
    'merchant_commission': (Icons.storefront_outlined, G.emerald),
    'customer_commission': (Icons.people_outline, G.ruby),
    'subscription': (Icons.workspace_premium_outlined, G.gold),
    'delivery_fee': (Icons.local_shipping_outlined, G.sapphire),
  };
  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['platform_ledger'],
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('platform_ledger')
          .select('*, merchants(name), orders(code)')
          .order('created_at', ascending: false)),
      builder: (context, rows, _) {
        final total = rows.fold<num>(0, (a, r) => a + toNum(r['amount']));
        num of(String k) => rows
            .where((r) => r['kind'] == k)
            .fold<num>(0, (a, r) => a + toNum(r['amount']));
        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon: Icons.account_balance_outlined,
            title: 'محفظة المنصة',
            subtitle: 'كل ما تحصّله المنصة من العمولات والاشتراكات والتوصيل',
            stats: [('الرصيد', bhd(total)), ('الحركات', '${rows.length}')],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 1000
                ? 4
                : c.maxWidth >= 560
                    ? 2
                    : 1;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final k in kinds.entries)
                SizedBox(
                    width: w,
                    child: Kpi(
                        label: k.value,
                        value: bhd(of(k.key)),
                        icon: kindLook[k.key]!.$1,
                        colors: kindLook[k.key]!.$2)),
            ]);
          }),
          const SizedBox(height: 16),
          if (total > 0)
            SectionCard(
              title: 'من أين يأتي الرصيد',
              child: Column(children: [
                for (final k in kinds.entries)
                  ShareBar(
                      name: k.value,
                      value: of(k.key),
                      total: total,
                      colors: kindLook[k.key]!.$2),
              ]),
            ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'تقرير المبالغ المحصّلة',
            child: Column(children: [
              if (rows.isEmpty) const Text('لا توجد مبالغ محصّلة بعد'),
              for (final r in rows.take(200))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    GradientBadge(
                        colors:
                            (kindLook[r['kind']] ?? kindLook['subscription']!)
                                .$2,
                        icon: (kindLook[r['kind']] ?? kindLook['subscription']!)
                            .$1,
                        size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${kinds[r['kind']] ?? r['kind']} · ${r['merchants']?['name'] ?? ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${r['orders'] != null ? 'طلب #${r['orders']['code']} · ' : ''}${dateTimeText(r['created_at'])}',
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 12)),
                          ]),
                    ),
                    Text('+ ${bhd(r['amount'])}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: (kindLook[r['kind']] ??
                                    kindLook['subscription']!)
                                .$2
                                .first)),
                  ]),
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
  static const planLook = <String, (IconData, List<Color>)>{
    'trial': (Icons.hourglass_top_outlined, G.amber),
    'monthly': (Icons.calendar_month_outlined, G.sky),
    'yearly': (Icons.workspace_premium_outlined, G.gold),
  };
  @override
  Widget build(BuildContext context) {
    return Loader<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
      realtimeTables: const ['subscriptions'],
      load: () async {
        final s =
            await sb.from('platform_settings').select().eq('id', 1).single();
        final subs = await sb
            .from('subscriptions')
            .select('*, merchants(name)')
            .order('created_at', ascending: false);
        return (s, List<Map<String, dynamic>>.from(subs));
      },
      builder: (context, data, reload) {
        final (s, subs) = data;
        final trial = TextEditingController(text: '${s['trial_days']}');
        final monthly = TextEditingController(text: '${s['monthly_price']}');
        final yearly = TextEditingController(text: '${s['yearly_price']}');
        final revenue = subs.fold<num>(0, (a, r) => a + toNum(r['amount']));
        final now = DateTime.now();
        final active = subs
            .where(
                (r) => DateTime.tryParse('${r['ends']}')?.isAfter(now) ?? false)
            .length;
        Widget plan(String key, String title, String note,
                TextEditingController c, String label) =>
            GradientHeaderCard(
              title: title,
              subtitle: note,
              icon: planLook[key]!.$1,
              colors: planLook[key]!.$2,
              child: Field(label, c, keyboard: TextInputType.number),
            );
        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon: Icons.workspace_premium_outlined,
            title: 'الاشتراكات',
            subtitle: 'خطط اشتراك التجار وتقرير ما تم تحصيله',
            stats: [
              ('الاشتراكات', '${subs.length}'),
              ('سارية', '$active'),
              ('الإيراد', bhd(revenue))
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 3 : 1;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: w,
                  child: plan('trial', 'تجريبي', 'مجاناً لفترة محددة', trial,
                      'عدد الأيام')),
              SizedBox(
                  width: w,
                  child: plan('monthly', 'شهري', 'يتجدد كل شهر', monthly,
                      'السعر (د.ب)')),
              SizedBox(
                  width: w,
                  child: plan('yearly', 'سنوي', 'الأوفر للتاجر', yearly,
                      'السعر (د.ب)')),
            ]);
          }),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              icon: const Icon(Icons.save_outlined, size: 18),
              onPressed: () async {
                await guard(
                    context,
                    () => sb.from('platform_settings').update({
                          'trial_days': int.tryParse(trial.text) ?? 14,
                          'monthly_price': num.tryParse(monthly.text) ?? 0,
                          'yearly_price': num.tryParse(yearly.text) ?? 0,
                          'updated_at': DateTime.now().toIso8601String(),
                        }).eq('id', 1),
                    ok: 'تم الحفظ');
                await reload();
              },
              label: const Text('حفظ الخطط'),
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'تقرير الاشتراكات',
            child: Column(children: [
              if (subs.isEmpty) const Text('لا توجد اشتراكات بعد'),
              for (final r in subs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    GradientBadge(
                        colors:
                            (planLook[r['plan']] ?? planLook['monthly']!).$2,
                        icon: (planLook[r['plan']] ?? planLook['monthly']!).$1,
                        size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${r['merchants']?['name'] ?? ''} · ${planLabels[r['plan']]}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${dateText(r['starts'])} إلى ${dateText(r['ends'])}',
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 12)),
                          ]),
                    ),
                    Text(bhd(r['amount']),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
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
      load: () async =>
          await sb.from('platform_settings').select().eq('id', 1).single(),
      builder: (context, s, reload) {
        String show(String who) => s['${who}_comm_enabled'] != true
            ? 'متوقفة'
            : s['${who}_comm_type'] == 'percent'
                ? '${s['${who}_comm_value']}%'
                : bhd(s['${who}_comm_value']);
        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon: Icons.percent,
            title: 'العمولات',
            subtitle:
                'عمولة التاجر وعمولة العميل منفصلتين، كل وحدة نسبة أو مبلغ ثابت',
            stats: [
              ('عمولة التاجر', show('merchant')),
              ('عمولة العميل', show('customer'))
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 2 : 1;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: w,
                  child: _CommCard(
                      who: 'merchant',
                      title: 'عمولة التاجر',
                      note: 'تُخصم من قيمة الطلب قبل إضافته لمحفظة التاجر',
                      icon: Icons.storefront_outlined,
                      colors: G.emerald,
                      s: s,
                      reload: reload)),
              SizedBox(
                  width: w,
                  child: _CommCard(
                      who: 'customer',
                      title: 'عمولة العميل',
                      note: 'تُضاف على فاتورة العميل كرسوم خدمة',
                      icon: Icons.people_outline,
                      colors: G.ruby,
                      s: s,
                      reload: reload)),
            ]);
          }),
          const SizedBox(height: 12),
          _IbanCard(s: s, reload: reload),
        ]);
      },
    );
  }
}

class _CommCard extends StatefulWidget {
  const _CommCard(
      {required this.who,
      required this.title,
      required this.note,
      required this.icon,
      required this.colors,
      required this.s,
      required this.reload});
  final String who, title, note;
  final IconData icon;
  final List<Color> colors;
  final Map<String, dynamic> s;
  final Future<void> Function() reload;
  @override
  State<_CommCard> createState() => _CommCardState();
}

class _CommCardState extends State<_CommCard> {
  late bool enabled = widget.s['${widget.who}_comm_enabled'] == true;
  late String type = widget.s['${widget.who}_comm_type'];
  late final value =
      TextEditingController(text: '${widget.s['${widget.who}_comm_value']}');
  @override
  Widget build(BuildContext context) => GradientHeaderCard(
        title: widget.title,
        subtitle: widget.note,
        icon: widget.icon,
        colors: widget.colors,
        trailing: Switch(
          value: enabled,
          activeThumbColor: Colors.white,
          activeTrackColor: Colors.white.withValues(alpha: .4),
          onChanged: (v) => setState(() => enabled = v),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(enabled ? 'مفعّلة' : 'متوقفة',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: enabled ? widget.colors.first : Colors.black45)),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            style: SegmentedButton.styleFrom(
                selectedBackgroundColor:
                    widget.colors.first.withValues(alpha: .14),
                selectedForegroundColor: widget.colors.first),
            segments: const [
              ButtonSegment(value: 'percent', label: Text('نسبة %')),
              ButtonSegment(value: 'fixed', label: Text('مبلغ ثابت'))
            ],
            selected: {type},
            onSelectionChanged: (x) => setState(() => type = x.first),
          ),
          const SizedBox(height: 12),
          Field(type == 'percent' ? 'النسبة %' : 'المبلغ (د.ب)', value,
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: widget.colors.first),
              onPressed: () async {
                await guard(
                    context,
                    () => sb.from('platform_settings').update({
                          '${widget.who}_comm_enabled': enabled,
                          '${widget.who}_comm_type': type,
                          '${widget.who}_comm_value':
                              num.tryParse(value.text) ?? 0,
                        }).eq('id', 1),
                    ok: 'تم الحفظ، تُطبّق على الطلبات الجديدة');
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
    return GradientHeaderCard(
      title: 'حساب المنصة للتحويل البنكي',
      subtitle: 'يظهر للعميل عند اختيار التحويل البنكي',
      icon: Icons.account_balance_outlined,
      colors: G.sapphire,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Field('IBAN', iban, ltr: true),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: G.sapphire.first),
            onPressed: () async {
              await guard(
                  context,
                  () => sb
                      .from('platform_settings')
                      .update({'platform_iban': iban.text.trim()}).eq('id', 1),
                  ok: 'تم الحفظ');
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
      load: () async => List<Map<String, dynamic>>.from(
          await sb.from('delivery_zones').select().order('name')),
      builder: (context, zones, reload) {
        final name = TextEditingController();
        final fee = TextEditingController();
        final active = zones.where((z) => z['active'] == true).toList();
        final avg = active.isEmpty
            ? 0
            : active.fold<num>(0, (a, z) => a + toNum(z['fee'])) /
                active.length;
        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon: Icons.map_outlined,
            title: 'التوصيل',
            subtitle: 'مناطق التوصيل في البحرين ورسوم كل منطقة',
            stats: [
              ('المناطق', '${zones.length}'),
              ('مفعّلة', '${active.length}'),
              ('متوسط الرسوم', bhd(avg))
            ],
          ),
          const SizedBox(height: 16),
          GradientHeaderCard(
            title: 'إضافة منطقة',
            icon: Icons.add_location_alt_outlined,
            colors: G.sky,
            child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(width: 240, child: Field('المنطقة', name)),
                  SizedBox(
                      width: 180,
                      child: Field('رسوم التوصيل (د.ب)', fee,
                          keyboard: const TextInputType.numberWithOptions(
                              decimal: true))),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () async {
                      if (name.text.trim().isEmpty) return;
                      await guard(
                          context,
                          () => sb.from('delivery_zones').insert({
                                'name': name.text.trim(),
                                'fee': num.tryParse(fee.text) ?? 0
                              }),
                          ok: 'تمت الإضافة');
                      await reload();
                    },
                    label: const Text('إضافة'),
                  ),
                ]),
          ),
          const SizedBox(height: 18),
          const Text('رسوم التوصيل حسب المنطقة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Text('عدّل الرسم واضغط Enter للحفظ',
              style: TextStyle(color: Colors.black45, fontSize: 12)),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 300).floor().clamp(1, 4);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (var i = 0; i < zones.length; i++)
                SizedBox(
                    width: w,
                    child: _ZoneTile(
                        z: zones[i],
                        colors: reportGradients[i % reportGradients.length],
                        reload: reload)),
            ]);
          }),
        ]);
      },
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile(
      {required this.z, required this.colors, required this.reload});
  final Map<String, dynamic> z;
  final List<Color> colors;
  final Future<void> Function() reload;
  @override
  Widget build(BuildContext context) {
    final fee = TextEditingController(text: '${z['fee']}');
    final on = z['active'] == true;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Opacity(
              opacity: on ? 1 : .4,
              child: GradientBadge(
                  colors: colors, icon: Icons.location_on_outlined, size: 40)),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(z['name'],
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: on ? null : Colors.black38)),
              Text(on ? 'مفعّلة' : 'متوقفة',
                  style: TextStyle(
                      fontSize: 12, color: on ? colors.first : Colors.black38)),
            ]),
          ),
          SizedBox(
            width: 92,
            child: TextField(
              controller: fee,
              textAlign: TextAlign.center,
              decoration:
                  const InputDecoration(isDense: true, suffixText: 'د.ب'),
              onSubmitted: (v) async {
                await guard(
                    context,
                    () => sb.from('delivery_zones').update(
                        {'fee': num.tryParse(v) ?? 0}).eq('id', z['id']),
                    ok: 'تم التحديث');
                await reload();
              },
            ),
          ),
          Switch(
            value: on,
            onChanged: (v) async {
              await guard(
                  context,
                  () => sb
                      .from('delivery_zones')
                      .update({'active': v}).eq('id', z['id']));
              await reload();
            },
          ),
        ]),
      ),
    );
  }
}
