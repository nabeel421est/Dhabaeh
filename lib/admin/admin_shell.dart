import 'package:flutter/material.dart';

import '../auth/gate.dart';
import '../core/brand.dart';
import '../core/common.dart';
import '../customer/order_details.dart';
import 'admin_merchants.dart';
import 'admin_money.dart';
import 'admin_people.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.profile, this.switcher});
  final Map<String, dynamic> profile;
  final Widget? switcher;
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int idx = 0;

  static const sections = <(String, IconData, String?)>[
    ('الرئيسية', Icons.dashboard_outlined, null),
    ('الطلبات', Icons.receipt_long_outlined, null),
    ('العملاء', Icons.people_outline, null),
    ('التجار', Icons.storefront_outlined, null),
    ('تقارير التجار', Icons.bar_chart_outlined, null),
    ('المندوبون', Icons.local_shipping_outlined, null),
    ('الإشعارات', Icons.campaign_outlined, null),
    ('محفظة المنصة', Icons.account_balance_outlined, 'الإدارة العامة'),
    ('الاشتراكات', Icons.workspace_premium_outlined, 'الإدارة العامة'),
    ('العمولات', Icons.percent, 'الإدارة العامة'),
    ('التوصيل', Icons.map_outlined, 'الإدارة العامة'),
    ('مستخدمو المنصة', Icons.admin_panel_settings_outlined, 'الإدارة العامة'),
  ];

  Widget page(int i) => switch (i) {
        0 => AdminHome(onGo: (i) => setState(() => idx = i)),
        1 => const AdminOrders(),
        2 => const AdminUsers(group: UserGroup.customers),
        3 => const AdminMerchants(),
        4 => const AdminReports(),
        5 => const AdminDrivers(),
        6 => const AdminNotify(),
        7 => const PlatformWallet(),
        8 => const AdminPlans(),
        9 => const AdminCommissions(),
        10 => const AdminZones(),
        _ => const AdminUsers(group: UserGroup.platform),
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final b = brandOf(context);
    final nav = ListView(padding: EdgeInsets.zero, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: b.accent.withValues(alpha: .7)),
                color: Colors.white.withValues(alpha: .08)),
            child: Icon(b.icon, color: b.accent),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('لوحة الإدارة',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            Text('ذبائح البحرين',
                style: TextStyle(fontSize: 12, color: Colors.white60)),
          ]),
        ]),
      ),
      for (var i = 0; i < sections.length; i++) ...[
        if (sections[i].$3 != null && (i == 0 || sections[i - 1].$3 == null))
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('الإدارة العامة',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFE8C66A),
                    fontWeight: FontWeight.w600,
                    letterSpacing: .3)),
          ),
        ListTile(
          dense: true,
          selected: idx == i,
          iconColor: Colors.white60,
          textColor: Colors.white70,
          selectedColor: Colors.white,
          selectedTileColor: Colors.white.withValues(alpha: .12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(sections[i].$2, color: idx == i ? b.accent : null),
          title: Text(sections[i].$1,
              style: TextStyle(
                  fontWeight: idx == i ? FontWeight.w700 : FontWeight.w500)),
          onTap: () {
            setState(() => idx = i);
            if (!wide) Navigator.pop(context);
          },
        ),
      ],
    ]);
    return Scaffold(
      appBar: GradientAppBar(
        title: Text(sections[idx].$1),
        actions: [
          Center(
              child: Text(widget.profile['full_name'] ?? '',
                  style: const TextStyle(color: Colors.white70))),
          ...commonActions(context, widget.switcher),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              child: DecoratedBox(
                  decoration: BoxDecoration(gradient: sideGradient(b)),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: nav))),
      body: Row(children: [
        if (wide)
          SizedBox(
            width: 260,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: sideGradient(b)),
              child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: nav)),
            ),
          ),
        Expanded(child: page(idx)),
      ]),
    );
  }
}

LinearGradient sideGradient(Brand b) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [b.stops[0], b.stops[1]]);

class StatTile extends StatelessWidget {
  const StatTile(this.label, this.value, {super.key, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 230,
        child: GradientCard(
          onTap: onTap,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
        ),
      );
}

class AdminHome extends StatelessWidget {
  const AdminHome({super.key, required this.onGo});
  final void Function(int) onGo;
  @override
  Widget build(BuildContext context) {
    return Loader<Map<String, dynamic>>(
      realtimeTables: const ['orders'],
      load: () async {
        final orders =
            await sb.from('orders').select('status, total, created_at');
        final merchants =
            await sb.from('merchants').select('id, suspended, frozen');
        final roles = await sb.from('user_roles').select('user_id, role');
        final nonCustomer = {
          for (final r in roles)
            if (r['role'] != 'customer') r['user_id']
        };
        final customers = {
          for (final r in roles)
            if (r['role'] == 'customer' && !nonCustomer.contains(r['user_id']))
              r['user_id']
        };
        final ledger = await sb.from('platform_ledger').select('amount');
        final today = DateTime.now();
        final todays = orders.where((o) {
          final d = DateTime.parse(o['created_at']).toLocal();
          return d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        }).toList();
        return {
          'today': todays.length,
          'open': orders
              .where((o) => !['delivered', 'cancelled'].contains(o['status']))
              .length,
          'delivered': orders
              .where((o) => o['status'] == 'delivered')
              .fold<num>(0, (a, o) => a + toNum(o['total'])),
          'merchants': merchants.length,
          'active': merchants
              .where((m) => m['suspended'] != true && m['frozen'] != true)
              .length,
          'customers': customers.length,
          'platform': ledger.fold<num>(0, (a, r) => a + toNum(r['amount'])),
        };
      },
      builder: (context, d, _) =>
          ListView(padding: const EdgeInsets.all(20), children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          StatTile('طلبات اليوم', '${d['today']}', onTap: () => onGo(1)),
          StatTile('طلبات جارية', '${d['open']}', onTap: () => onGo(1)),
          StatTile('مبيعات مسلّمة', bhd(d['delivered']), onTap: () => onGo(4)),
          StatTile('التجار', '${d['active']} فعال من ${d['merchants']}',
              onTap: () => onGo(3)),
          StatTile('العملاء', '${d['customers']}', onTap: () => onGo(2)),
          StatTile('رصيد المنصة', bhd(d['platform']), onTap: () => onGo(7)),
        ]),
      ]),
    );
  }
}

class AdminOrders extends StatefulWidget {
  const AdminOrders({super.key});
  @override
  State<AdminOrders> createState() => _AdminOrdersState();
}

class _AdminOrdersState extends State<AdminOrders> {
  String status = 'all';
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 56,
        child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              for (final s in ['all', ...statusLabels.keys])
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                      label: Text(s == 'all' ? 'الكل' : statusLabels[s]!),
                      selected: status == s,
                      onSelected: (_) => setState(() => status = s)),
                ),
            ]),
      ),
      Expanded(
        child: Loader<List<Map<String, dynamic>>>(
          key: ValueKey(status),
          realtimeTables: const ['orders'],
          load: () async {
            var q = sb.from('orders').select('*, merchants(name)');
            if (status != 'all') q = q.eq('status', status);
            return List<Map<String, dynamic>>.from(
                await q.order('created_at', ascending: false).limit(200));
          },
          builder: (context, orders, _) {
            if (orders.isEmpty)
              return ListView(children: const [Empty('لا توجد طلبات')]);
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final o = orders[i];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(
                        '#${o['code']} · ${o['merchants']?['name'] ?? ''} · ${o['customer_name'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        'الذبح ${dateText(o['slaughter_date'])} · التوصيل ${dateText(o['delivery_date'])} ${o['delivery_slot']}\n'
                        '${paymentLabels[o['payment_method']]} · ${paymentStatusLabels[o['payment_status']]} · المندوب: ${o['driver_name'] ?? 'غير معيّن'}'),
                    isThreeLine: true,
                    trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusChip(o['status']),
                          const SizedBox(height: 4),
                          Text(bhd(o['total']),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => OrderDetailsPage(
                                orderId: o['id'], viewer: 'admin'))),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}
