import 'package:flutter/material.dart' hide Text;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/address_map.dart';
import '../core/brand.dart';
import '../core/common.dart';
import '../customer/customer_shell.dart' show StoreLogo;
import 'admin_plan_requests.dart';
import '../core/ttext.dart';
import '../core/i18n.dart';

/// Gradient pairs used to tell merchants apart in the reports, in rank order.
const reportGradients = <List<Color>>[
  [Color(0xFF8C6A12), Color(0xFFD4AF37)], // gold
  [Color(0xFF0D6152), Color(0xFF3CC4A0)], // emerald
  [Color(0xFF8E2442), Color(0xFFE07A86)], // ruby
  [Color(0xFF1C4790), Color(0xFF5FA6F2)], // sapphire
  [Color(0xFF9A4A12), Color(0xFFF2A65A)], // amber
  [Color(0xFF136A82), Color(0xFF5CC8DA)], // teal
];

class AdminReports extends StatefulWidget {
  const AdminReports({super.key});
  @override
  State<AdminReports> createState() => _AdminReportsState();
}

class _AdminReportsState extends State<AdminReports> {
  String? picked; // merchant id, null = all
  String search = '';
  final searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Loader<(List<Map<String, dynamic>>, Map<String, dynamic>)>(
      realtimeTables: const ['orders'],
      load: () async {
        final s = List<Map<String, dynamic>>.from(
            await sb.rpc('admin_merchant_summary'));
        final m = await sb.from('merchants').select('id, logo_url, area');
        return (s, {for (final x in m) '${x['id']}': x});
      },
      builder: (context, data, _) {
        final (raw, info) = data;
        final all = [...raw]
          ..sort((a, b) => toNum(b['sales']).compareTo(toNum(a['sales'])));
        final colorOf = {
          for (var i = 0; i < all.length; i++)
            all[i]['merchant_id']: reportGradients[i % reportGradients.length]
        };
        final rankOf = {
          for (var i = 0; i < all.length; i++) all[i]['merchant_id']: i + 1
        };
        final q = search.trim();
        final rows =
            all.where((r) => q.isEmpty || '${r['name']}'.contains(q)).toList();
        num sumOf(List<Map<String, dynamic>> l, String k) =>
            l.fold<num>(0, (a, r) => a + toNum(r[k]));
        final totalSales = sumOf(all, 'sales');
        final sel = picked == null
            ? null
            : all.where((r) => r['merchant_id'] == picked).firstOrNull;
        final scope = sel == null ? rows : [sel];
        final sales = sumOf(scope, 'sales');
        final platform =
            sumOf(scope, 'merchant_comm') + sumOf(scope, 'customer_comm');

        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon: Icons.insights_outlined,
            title: sel == null ? 'تقارير التجار' : 'تقرير ${sel['name']}',
            subtitle: sel == null
                ? 'أداء كل المتاجر من الطلبات المسلّمة، اختر تاجراً لعرض تقريره'
                : 'الطلبات المسلّمة ورصيد محفظة هذا التاجر',
            stats: [
              ('المبيعات', bhd(sales)),
              ('عمولات المنصة', bhd(platform)),
              ('الطلبات', '${sumOf(scope, 'orders_count')}'),
              if (sel == null) ('التجار', '${rows.length}'),
            ],
            action: sel == null
                ? null
                : HeroButton(
                    icon: Icons.apps,
                    label: 'كل التجار',
                    onPressed: () => setState(() => picked = null)),
          ),
          const SizedBox(height: 14),
          // Search + merchant picker
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(colors: [
                G.violet.first.withValues(alpha: .06),
                G.sky.last.withValues(alpha: .12)
              ]),
              border: Border.all(color: G.violet.first.withValues(alpha: .15)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: G.violet.first),
                      hintText: tr('ابحث عن تاجر بالاسم، مثل: مسلخ الواحة'),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: search.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                    searchCtrl.clear();
                                    search = '';
                                  })),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() {
                      search = v;
                      final hits = all
                          .where((r) => '${r['name']}'.contains(v.trim()))
                          .toList();
                      if (v.trim().isNotEmpty && hits.length == 1) {
                        picked = hits.first['merchant_id'];
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child:
                        ListView(scrollDirection: Axis.horizontal, children: [
                      _MPill(
                        name: 'كل التجار',
                        sub: bhd(totalSales),
                        colors: G.violet,
                        selected: picked == null,
                        onTap: () => setState(() => picked = null),
                      ),
                      for (final r in rows)
                        _MPill(
                          name: '${r['name']}',
                          sub: bhd(r['sales']),
                          logo: info['${r['merchant_id']}']?['logo_url'],
                          colors: colorOf[r['merchant_id']]!,
                          selected: picked == r['merchant_id'],
                          onTap: () =>
                              setState(() => picked = r['merchant_id']),
                        ),
                    ]),
                  ),
                ]),
          ),
          const SizedBox(height: 16),
          if (sel != null)
            _MerchantDetail(
              r: sel,
              info: info['${sel['merchant_id']}'] ?? const {},
              rank: rankOf[sel['merchant_id']] ?? 1,
              total: totalSales,
              colors: colorOf[sel['merchant_id']]!,
            )
          else ...[
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
                    bhd(sumOf(rows, 'net')),
                    Icons.storefront_outlined,
                    reportGradients[3]
                  ),
                  (
                    'الطلبات',
                    '${sumOf(rows, 'orders_count')}',
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
            const SizedBox(height: 16),
            if (rows.isEmpty)
              Empty(
                  q.isEmpty
                      ? 'لا توجد مبيعات مسلّمة بعد'
                      : 'لا يوجد تاجر بهذا الاسم',
                  icon: Icons.insights_outlined),
            if (rows.isNotEmpty)
              GradientHeaderCard(
                title: 'حصة كل تاجر من المبيعات',
                subtitle: 'اضغط على التاجر لعرض تقريره',
                icon: Icons.donut_large_outlined,
                colors: G.violet,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    for (final r in rows)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => picked = r['merchant_id']),
                        child: ShareBar(
                            name: r['name'],
                            value: toNum(r['sales']),
                            total: totalSales,
                            colors: colorOf[r['merchant_id']]!),
                      ),
                  ]),
                ),
              ),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 900 ? 2 : 1;
              final w = (c.maxWidth - 12 * (cols - 1)) / cols;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                for (final r in rows)
                  SizedBox(
                      width: w,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => setState(() => picked = r['merchant_id']),
                        child: _MerchantReport(
                            rank: rankOf[r['merchant_id']] ?? 1,
                            r: r,
                            logo: info['${r['merchant_id']}']?['logo_url'],
                            total: totalSales,
                            colors: colorOf[r['merchant_id']]!),
                      )),
              ]);
            }),
          ],
        ]);
      },
    );
  }
}

class _MPill extends StatelessWidget {
  const _MPill(
      {required this.name,
      required this.sub,
      required this.colors,
      required this.selected,
      required this.onTap,
      this.logo});
  final String name, sub;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;
  final dynamic logo;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsetsDirectional.fromSTEB(6, 5, 16, 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: selected ? LinearGradient(colors: colors) : null,
              color: selected ? null : Colors.white,
              border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : colors.first.withValues(alpha: .3)),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: colors.first.withValues(alpha: .3),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (name == 'كل التجار')
                CircleAvatar(
                    radius: 17,
                    backgroundColor: selected
                        ? Colors.white24
                        : colors.first.withValues(alpha: .12),
                    child: Icon(Icons.apps,
                        size: 17,
                        color: selected ? Colors.white : colors.first))
              else
                ClipOval(child: StoreLogo(logo, size: 34)),
              const SizedBox(width: 8),
              Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: selected ? Colors.white : colors.first)),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? Colors.white.withValues(alpha: .85)
                                : Colors.black45)),
                  ]),
            ]),
          ),
        ),
      );
}

/// One merchant's full report: gradient hero, money tiles and recent delivered orders.
class _MerchantDetail extends StatelessWidget {
  const _MerchantDetail(
      {required this.r,
      required this.info,
      required this.rank,
      required this.total,
      required this.colors});
  final Map<String, dynamic> r;
  final Map info;
  final int rank;
  final num total;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0 : (toNum(r['sales']) / total * 100);
    final n = toNum(r['orders_count']);
    final avg = n == 0 ? 0 : toNum(r['sales']) / n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [colors.last, colors.first]),
          boxShadow: [
            BoxShadow(
                color: colors.first.withValues(alpha: .3),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF2D58A), width: 2)),
              child: ClipOval(child: StoreLogo(info['logo_url'], size: 62)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r['name']}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    Text(
                        'المرتبة $rank بين التجار${info['area'] == null ? '' : ' · ${info['area']}'}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .85))),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(bhd(r['sales']),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              Text('${share.toStringAsFixed(1)}% من مبيعات المنصة',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .85),
                      fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (share / 100).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: .2),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFF2D58A)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 4 : 2;
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final k in [
            (
              'الطلبات المسلّمة',
              '${r['orders_count']}',
              Icons.receipt_long_outlined,
              G.sapphire
            ),
            ('متوسط الطلب', bhd(avg), Icons.functions, G.violet),
            ('عمولة التاجر', bhd(r['merchant_comm']), Icons.percent, G.ruby),
            (
              'عمولة العميل',
              bhd(r['customer_comm']),
              Icons.person_outline,
              G.amber
            ),
            (
              'رسوم التوصيل',
              bhd(r['delivery_fees']),
              Icons.local_shipping_outlined,
              G.teal
            ),
            ('صافي التاجر', bhd(r['net']), Icons.savings_outlined, G.emerald),
            (
              'رصيد المحفظة',
              bhd(r['balance']),
              Icons.account_balance_wallet_outlined,
              G.gold
            ),
            (
              'عمولات المنصة',
              bhd(toNum(r['merchant_comm']) + toNum(r['customer_comm'])),
              Icons.account_balance_outlined,
              G.sky
            ),
          ])
            SizedBox(
                width: w,
                child: Kpi(label: k.$1, value: k.$2, icon: k.$3, colors: k.$4)),
        ]);
      }),
      const SizedBox(height: 14),
      Loader<List<Map<String, dynamic>>>(
        key: ValueKey(r['merchant_id']),
        load: () async => List<Map<String, dynamic>>.from(await sb
            .from('orders')
            .select(
                'id, code, created_at, subtotal, discount, total, merchant_net, merchant_commission, status, customer_name')
            .eq('merchant_id', r['merchant_id'])
            .order('created_at', ascending: false)
            .limit(30)),
        builder: (context, orders, _) {
          final byStatus = <String, int>{};
          for (final o in orders) {
            byStatus['${o['status']}'] = (byStatus['${o['status']}'] ?? 0) + 1;
          }
          return GradientHeaderCard(
            title: 'آخر طلبات المتجر',
            subtitle: '${orders.length} طلب، كل الحالات',
            icon: Icons.history,
            colors: colors,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (byStatus.isNotEmpty)
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final e in byStatus.entries)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              gradient: LinearGradient(
                                  colors: toneOf(statusColor(e.key))),
                            ),
                            child: Text(
                                '${statusLabels[e.key] ?? e.key} · ${e.value}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ]),
                    const SizedBox(height: 10),
                    if (orders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('لا توجد طلبات لهذا المتجر بعد',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black45)),
                      ),
                    for (final o in orders)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: statusColor('${o['status']}')
                              .withValues(alpha: .06),
                          border: Border.all(
                              color: statusColor('${o['status']}')
                                  .withValues(alpha: .18)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 6,
                            height: 38,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors:
                                        toneOf(statusColor('${o['status']}')))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'طلب #${o['code'] ?? ''} · ${o['customer_name'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  Text(
                                      '${dateTimeText(o['created_at'])} · ${statusOf(o)}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54)),
                                ]),
                          ),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(bhd(o['total']),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: colors.first)),
                                Text('صافي ${bhd(o['merchant_net'])}',
                                    style: const TextStyle(
                                        fontSize: 11.5, color: Colors.black54)),
                              ]),
                        ]),
                      ),
                  ]),
            ),
          );
        },
      ),
    ]);
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
      required this.colors,
      this.logo});
  final int rank;
  final dynamic logo;
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
            ClipOval(child: StoreLogo(logo, size: 36)),
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
          const SizedBox(height: 18),
          const PlanRequestsSection(),
          const SizedBox(height: 22),
          const Text('أسعار الباقات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
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

class AdminZones extends StatefulWidget {
  const AdminZones({super.key});
  @override
  State<AdminZones> createState() => _AdminZonesState();
}

class _AdminZonesState extends State<AdminZones> {
  String? gov; // null = all governorates

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['delivery_zones'],
      load: () async => List<Map<String, dynamic>>.from(
          await sb.from('delivery_zones').select().order('name')),
      builder: (context, zones, reload) {
        final active = zones.where((z) => z['active'] == true).toList();
        final avg = active.isEmpty
            ? 0
            : active.fold<num>(0, (a, z) => a + toNum(z['fee'])) /
                active.length;
        final govs = <String>{
          ...bahrainGovernorates.keys,
          for (final z in zones)
            if ('${z['governorate'] ?? ''}'.isNotEmpty) '${z['governorate']}'
        }.toList();
        Color govTone(String? g) {
          final i = g == null ? -1 : govs.indexOf(g);
          return i < 0
              ? G.violet.first
              : reportGradients[i % reportGradients.length].first;
        }

        final shown =
            zones.where((z) => gov == null || z['governorate'] == gov).toList();
        final pinned = zones.where((z) => z['lat'] != null).length;
        Future<void> edit([Map<String, dynamic>? z]) async {
          if (await showZoneEditor(context, z)) await reload();
        }

        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon: Icons.map_outlined,
            title: 'التوصيل',
            subtitle:
                'مناطق التوصيل حسب الدولة والمحافظة والمدينة، ورسوم كل منطقة',
            stats: [
              ('المناطق', '${zones.length}'),
              ('مفعّلة', '${active.length}'),
              ('على الخارطة', '$pinned'),
              ('متوسط الرسوم', bhd(avg)),
            ],
            action: HeroButton(
                icon: Icons.add_location_alt_outlined,
                label: 'إضافة منطقة',
                onPressed: () => edit()),
          ),
          const SizedBox(height: 16),
          GradientHeaderCard(
            title: 'خارطة المناطق',
            subtitle: 'اضغط على أي دبوس لتعديل المنطقة',
            icon: Icons.travel_explore_outlined,
            colors: G.sky,
            child: _ZonesMap(
                zones: shown,
                toneOf: (z) => govTone(z['governorate'] as String?),
                onTap: edit),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            TonePill(
                label: 'كل المحافظات',
                icon: Icons.apps,
                colors: G.violet,
                count: zones.length,
                selected: gov == null,
                onTap: () => setState(() => gov = null)),
            for (final g in govs)
              TonePill(
                  label: g,
                  icon: Icons.location_city_outlined,
                  colors: toneOf(govTone(g)),
                  count: zones.where((z) => z['governorate'] == g).length,
                  selected: gov == g,
                  onTap: () => setState(() => gov = g)),
          ]),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            const Empty('لا توجد مناطق في هذه المحافظة بعد',
                icon: Icons.map_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 320).floor().clamp(1, 4);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final z in shown)
                SizedBox(
                    width: w,
                    child: _ZoneTile(
                        z: z,
                        colors: toneOf(govTone(z['governorate'] as String?)),
                        onEdit: () => edit(z),
                        reload: reload)),
            ]);
          }),
        ]);
      },
    );
  }
}

/// All zones as coloured pins on one map.
class _ZonesMap extends StatelessWidget {
  const _ZonesMap(
      {required this.zones, required this.toneOf, required this.onTap});
  final List<Map<String, dynamic>> zones;
  final Color Function(Map<String, dynamic>) toneOf;
  final void Function(Map<String, dynamic>) onTap;
  @override
  Widget build(BuildContext context) {
    final pins = zones.where((z) => z['lat'] != null && z['lng'] != null);
    return SizedBox(
      height: 340,
      child: Stack(children: [
        FlutterMap(
          options: const MapOptions(
              initialCenter: LatLng(26.16, 50.55), initialZoom: 10.4),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'app.dhabaeh.bahrain',
            ),
            MarkerLayer(markers: [
              for (final z in pins)
                Marker(
                  point: LatLng(
                      toNum(z['lat']).toDouble(), toNum(z['lng']).toDouble()),
                  width: 130,
                  height: 62,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => onTap(z),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: LinearGradient(colors: [
                            toneOf(z),
                            Color.lerp(toneOf(z), Colors.white, .3)!
                          ]),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6)
                          ],
                        ),
                        child: Text('${z['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                      Icon(Icons.location_on,
                          size: 30,
                          color: z['active'] == true ? toneOf(z) : Colors.grey,
                          shadows: const [
                            Shadow(color: Colors.black38, blurRadius: 4)
                          ]),
                    ]),
                  ),
                ),
            ]),
          ],
        ),
        PositionedDirectional(
          bottom: 6,
          end: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .8),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('© OpenStreetMap',
                textDirection: TextDirection.ltr,
                style: TextStyle(fontSize: 10, color: Colors.black54)),
          ),
        ),
      ]),
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile(
      {required this.z,
      required this.colors,
      required this.onEdit,
      required this.reload});
  final Map<String, dynamic> z;
  final List<Color> colors;
  final VoidCallback onEdit;
  final Future<void> Function() reload;
  @override
  Widget build(BuildContext context) {
    final on = z['active'] == true;
    final place = [
      z['country'] ?? 'البحرين',
      z['governorate'],
      z['city'],
    ].where((x) => '${x ?? ''}'.isNotEmpty).join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: on
                ? colors.first.withValues(alpha: .18)
                : Colors.black.withValues(alpha: .08)),
        boxShadow: [
          BoxShadow(
              color: colors.first.withValues(alpha: on ? .12 : .03),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: on
                    ? [colors.first, colors.last]
                    : [Colors.grey.shade500, Colors.grey.shade400]),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(12)),
              child:
                  const Icon(Icons.location_on_outlined, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${z['name']}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Text(place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .85),
                            fontSize: 12)),
                  ]),
            ),
            Switch(
              value: on,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFFF2D58A),
              inactiveThumbColor: Colors.white70,
              inactiveTrackColor: Colors.black26,
              onChanged: (v) async {
                await guard(
                    context,
                    () => sb
                        .from('delivery_zones')
                        .update({'active': v}).eq('id', z['id']),
                    ok: v ? 'تم تفعيل المنطقة' : 'تم إيقاف المنطقة');
                await reload();
              },
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('رسوم التوصيل',
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
              ShaderMask(
                shaderCallback: (r) =>
                    LinearGradient(colors: colors).createShader(r),
                child: Text(bhd(z['fee']),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ),
            ]),
            const Spacer(),
            Icon(
                z['lat'] == null
                    ? Icons.location_off_outlined
                    : Icons.where_to_vote_outlined,
                size: 18,
                color: z['lat'] == null ? G.ruby.first : G.emerald.first),
            const SizedBox(width: 4),
            Text(z['lat'] == null ? 'بدون موقع' : 'على الخارطة',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: z['lat'] == null ? G.ruby.first : G.emerald.first)),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                  foregroundColor: colors.first,
                  backgroundColor: colors.first.withValues(alpha: .1)),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('تعديل'),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Add or edit a delivery zone: country, governorate, city, name, fee and a map pin.
Future<bool> showZoneEditor(
    BuildContext context, Map<String, dynamic>? z) async {
  final form = GlobalKey<FormState>();
  final country = TextEditingController(text: z?['country'] ?? 'البحرين');
  final city = TextEditingController(text: z?['city'] ?? '');
  final name = TextEditingController(text: z?['name'] ?? '');
  final fee = TextEditingController(text: z == null ? '2.000' : '${z['fee']}');
  final govCtrl = TextEditingController(text: z?['governorate'] ?? '');
  String? gov = z?['governorate'] as String?;
  bool active = z == null ? true : z['active'] == true;
  LatLng? point = z?['lat'] == null
      ? null
      : LatLng(toNum(z!['lat']).toDouble(), toNum(z['lng']).toDouble());
  bool locating = false;
  const colors = [Color(0xFF0B6FB0), Color(0xFF47BFF0)];

  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final bh = country.text.trim() == 'البحرين';
      final cities = bh && gov != null
          ? (bahrainGovernorates[gov]?.keys.toList() ?? <String>[])
          : <String>[];
      InputDecoration deco(String label, IconData icon, {String? suffix}) =>
          InputDecoration(
            labelText: tr(label),
            prefixIcon: Icon(icon, color: colors.first),
            suffixText: tr(suffix),
            filled: true,
            fillColor: colors.first.withValues(alpha: .04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: colors.first.withValues(alpha: .18))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.first, width: 1.6)),
          );

      Future<void> locate() async {
        final t = city.text.trim();
        if (t.isEmpty) {
          toast(c, 'اختر المدينة أولاً', error: true);
          return;
        }
        final known = bh ? bahrainPlace(t) : null;
        if (known != null) {
          set(() => point = known.$2);
          return;
        }
        set(() => locating = true);
        final p = await geocodeBahrain(area: name.text.trim(), city: t);
        set(() {
          locating = false;
          if (p != null) point = p;
        });
        if (p == null && c.mounted) {
          toast(c, 'ما لقينا المدينة، اضغط على الخارطة لتحديدها', error: true);
        }
      }

      void pickCity(String t) => set(() {
            final wasName = name.text.trim().isEmpty ||
                name.text.trim() == city.text.trim();
            city.text = t;
            if (wasName) name.text = t;
            final known = bh ? bahrainPlace(t) : null;
            if (known != null) point = known.$2;
          });

      Widget twoCols(List<Widget> kids) =>
          LayoutBuilder(builder: (context, box) {
            final w =
                box.maxWidth >= 480 ? (box.maxWidth - 12) / 2 : box.maxWidth;
            return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [for (final k in kids) SizedBox(width: w, child: k)]);
          });

      return Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 900),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      Color(0xFF47BFF0),
                      Color(0xFF0B6FB0),
                      Color(0xFF06375A)
                    ]),
              ),
              child: Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: const Color(0xFFF2D58A), width: 1.6),
                  ),
                  child: const Icon(Icons.add_location_alt_outlined,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(z == null ? 'إضافة منطقة' : 'تعديل ${z['name']}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                            [country.text.trim(), gov ?? '', city.text.trim()]
                                .where((x) => x.isNotEmpty)
                                .join(' · '),
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .85),
                                fontSize: 13)),
                      ]),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(c, false),
                    icon: const Icon(Icons.close, color: Colors.white)),
              ]),
            ),
            Flexible(
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        twoCols([
                          TextFormField(
                            controller: country,
                            onChanged: (_) => set(() {}),
                            decoration: deco('الدولة *', Icons.public_outlined),
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? tr('اكتب الدولة')
                                : null,
                          ),
                          bh
                              ? DropdownButtonFormField<String>(
                                  initialValue:
                                      bahrainGovernorates.containsKey(gov)
                                          ? gov
                                          : null,
                                  isExpanded: true,
                                  decoration: deco('المحافظة *',
                                      Icons.location_city_outlined),
                                  items: [
                                    for (final g in bahrainGovernorates.keys)
                                      DropdownMenuItem(value: g, child: Text(g))
                                  ],
                                  onChanged: (v) => set(() => gov = v),
                                  validator: (v) =>
                                      v == null ? tr('اختر المحافظة') : null,
                                )
                              : TextFormField(
                                  controller: govCtrl,
                                  onChanged: (v) => set(() => gov = v.trim()),
                                  decoration: deco('المحافظة *',
                                      Icons.location_city_outlined),
                                  validator: (v) => (v ?? '').trim().isEmpty
                                      ? tr('اكتب المحافظة')
                                      : null,
                                ),
                        ]),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: city,
                          onChanged: (_) => set(() {}),
                          onFieldSubmitted: (_) => locate(),
                          decoration:
                              deco('المدينة *', Icons.apartment_outlined),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? tr('اختر أو اكتب المدينة')
                              : null,
                        ),
                        if (cities.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final t in cities)
                              TonePill(
                                label: t,
                                colors: colors,
                                selected: city.text.trim() == t,
                                onTap: () => pickCity(t),
                              ),
                          ]),
                        ],
                        const SizedBox(height: 12),
                        twoCols([
                          TextFormField(
                            controller: name,
                            onChanged: (_) => set(() {}),
                            decoration: deco('اسم المنطقة كما يراه العميل *',
                                Icons.place_outlined),
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? tr('اكتب اسم المنطقة')
                                : null,
                          ),
                          TextFormField(
                            controller: fee,
                            textDirection: TextDirection.ltr,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: deco(
                                'رسوم التوصيل *', Icons.local_shipping_outlined,
                                suffix: ' د.ب '),
                            validator: (v) =>
                                num.tryParse((v ?? '').trim()) == null
                                    ? tr('اكتب الرسوم')
                                    : null,
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Icon(Icons.map_outlined, color: colors.first),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('موقع المنطقة على الخارطة',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: colors.first,
                                foregroundColor: Colors.white),
                            onPressed: locating ? null : locate,
                            icon: locating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.my_location, size: 18),
                            label: const Text('حدد من المدينة'),
                          ),
                        ]),
                        const Padding(
                          padding: EdgeInsets.only(top: 2, bottom: 8),
                          child: Text(
                              'يتحدد الدبوس من المدينة تلقائياً، واضغط على الخارطة لتعديله. يستخدمه المندوب للوصول للمنطقة',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ),
                        AddressMap(
                          point: point,
                          height: 260,
                          color: colors.first,
                          onPick: (p) => set(() => point = p),
                        ),
                        if (point != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                '${point!.latitude.toStringAsFixed(5)}, ${point!.longitude.toStringAsFixed(5)}',
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black45)),
                          ),
                        const SizedBox(height: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: (active ? G.emerald : G.ruby)
                                .first
                                .withValues(alpha: .07),
                            border: Border.all(
                                color: (active ? G.emerald : G.ruby)
                                    .first
                                    .withValues(alpha: .25)),
                          ),
                          child: SwitchListTile(
                            value: active,
                            activeThumbColor: Colors.white,
                            activeTrackColor: G.emerald.first,
                            title: Text(
                                active ? 'المنطقة مفعّلة' : 'المنطقة متوقفة',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            subtitle: Text(active
                                ? 'تظهر للعميل عند اختيار منطقة التوصيل'
                                : 'لا تظهر للعميل حتى تفعّلها'),
                            onChanged: (v) => set(() => active = v),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ]),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: colors.first.withValues(alpha: .1))),
              ),
              child: Row(children: [
                Expanded(
                  flex: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(colors: colors),
                      boxShadow: [
                        BoxShadow(
                            color: colors.first.withValues(alpha: .35),
                            blurRadius: 14,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        if (!form.currentState!.validate()) return;
                        if (point == null) {
                          toast(c, 'حدد موقع المنطقة على الخارطة', error: true);
                          return;
                        }
                        Navigator.pop(c, true);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(z == null ? 'إضافة المنطقة' : 'حفظ',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: colors.first,
                      side:
                          BorderSide(color: colors.first.withValues(alpha: .4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('إلغاء'),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
    }),
  );
  if (ok != true || !context.mounted) return false;
  final row = {
    'country': country.text.trim(),
    'governorate': country.text.trim() == 'البحرين' ? gov : govCtrl.text.trim(),
    'city': city.text.trim(),
    'name': name.text.trim(),
    'fee': num.tryParse(fee.text.trim()) ?? 0,
    'active': active,
    'lat': point?.latitude,
    'lng': point?.longitude,
  };
  final r = await guard(context, () async {
    if (z == null) {
      await sb.from('delivery_zones').insert(row);
    } else {
      await sb.from('delivery_zones').update(row).eq('id', z['id']);
    }
    return true;
  }, ok: z == null ? 'تمت إضافة المنطقة' : 'تم حفظ المنطقة');
  return r == true;
}
