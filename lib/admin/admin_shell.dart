import 'package:flutter/material.dart' hide Text;

import 'admin_payment_methods.dart';
import '../auth/gate.dart';
import '../core/brand.dart';
import '../core/i18n.dart';
import '../core/common.dart';
import '../customer/order_details.dart';
import 'admin_driver_money.dart';
import 'admin_activity.dart';
import 'admin_drivers.dart';
import 'admin_merchants.dart';
import 'admin_money.dart';
import 'admin_offers.dart';
import 'admin_order_control.dart';
import 'admin_payouts.dart';
import 'admin_people.dart';
import 'admin_products.dart';
import '../core/ttext.dart';
import 'admin_settings.dart';
import '../core/order_alerts.dart';

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
    ('المنتجات', Icons.inventory_2_outlined, null),
    ('العروض', Icons.local_offer_outlined, null),
    ('تقارير التجار', Icons.bar_chart_outlined, null),
    ('المندوبون', Icons.local_shipping_outlined, null),
    ('الإشعارات', Icons.campaign_outlined, null),
    ('التحكم الإداري', Icons.verified_user_outlined, 'الإدارة العامة'),
    ('سجل الأنشطة', Icons.manage_search, 'الإدارة العامة'),
    ('محفظة المنصة', Icons.account_balance_outlined, 'الإدارة العامة'),
    ('طلبات السحب', Icons.outbox_outlined, 'الإدارة العامة'),
    ('مبالغ الدفع عند الاستلام', Icons.payments_outlined, 'الإدارة العامة'),
    ('رسوم المناديب', Icons.delivery_dining_outlined, 'الإدارة العامة'),
    ('الاشتراكات', Icons.workspace_premium_outlined, 'الإدارة العامة'),
    ('العمولات', Icons.percent, 'الإدارة العامة'),
    ('وسائل الدفع', Icons.account_balance_wallet_outlined, 'الإدارة العامة'),
    ('التوصيل', Icons.map_outlined, 'الإدارة العامة'),
    ('مستخدمو المنصة', Icons.admin_panel_settings_outlined, 'الإدارة العامة'),
    ('الإعدادات', Icons.settings_outlined, 'الإدارة العامة'),
  ];

  Widget page(int i) => switch (sections[i].$1) {
        'الرئيسية' => AdminHome(
            onGo: (label) => setState(
                () => idx = sections.indexWhere((x) => x.$1 == label))),
        'الطلبات' => const AdminOrders(),
        'العملاء' => const AdminUsers(group: UserGroup.customers),
        'التجار' => const AdminMerchants(),
        'المنتجات' => const AdminProducts(),
        'العروض' => const AdminOffers(),
        'التحكم الإداري' => const AdminOrderControl(),
        'سجل الأنشطة' => const AdminActivity(),
        'تقارير التجار' => const AdminReports(),
        'المندوبون' => const AdminDriversHub(),
        'الإشعارات' => const AdminNotify(),
        'محفظة المنصة' => const PlatformWallet(),
        'طلبات السحب' => const AdminPayouts(),
        'مبالغ الدفع عند الاستلام' => const AdminDriverMoney(fees: false),
        'رسوم المناديب' => const AdminDriverMoney(fees: true),
        'الاشتراكات' => const AdminPlans(),
        'العمولات' => const AdminCommissions(),
        'وسائل الدفع' => const AdminPaymentMethods(),
        'التوصيل' => const AdminZones(),
        'الإعدادات' => const AdminSettings(),
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
          const AppLogo(size: 44),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('لوحة الإدارة',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            Text(appName,
                style: const TextStyle(fontSize: 12, color: Colors.white60)),
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
                    color: Color(0xFFF4C752),
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
    return OrderAlertWatcher(
        title: 'طلب جديد',
        fetch: () => newOrderAlerts(),
        onOpen: (c, id) => Navigator.push(
            c,
            MaterialPageRoute(
                builder: (_) =>
                    OrderDetailsPage(orderId: id, viewer: 'admin'))),
        child: Scaffold(
          appBar: GradientAppBar(
            logo: true,
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
        ));
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
  final void Function(String) onGo;
  @override
  Widget build(BuildContext context) {
    return Loader<Map<String, dynamic>>(
      realtimeTables: const ['orders'],
      load: () async {
        final orders = List<Map<String, dynamic>>.from(await sb
            .from('orders')
            .select(
                'id, code, status, total, created_at, customer_name, merchants(name)')
            .order('created_at', ascending: false));
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
        final ledger = await sb
            .from('platform_ledger')
            .select('amount')
            .isFilter('deleted_at', null)
            .eq('frozen', false);
        final summary = List<Map<String, dynamic>>.from(
            await sb.rpc('admin_merchant_summary'))
          ..sort((a, b) => toNum(b['sales']).compareTo(toNum(a['sales'])));
        final today = DateTime.now();
        bool isToday(Map o) {
          final d = DateTime.parse(o['created_at']).toLocal();
          return d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        }

        final byStatus = <String, int>{for (final k in statusLabels.keys) k: 0};
        for (final o in orders) {
          byStatus[o['status']] = (byStatus[o['status']] ?? 0) + 1;
        }
        return {
          'today': orders.where(isToday).length,
          'todaySales': orders
              .where(isToday)
              .fold<num>(0, (a, o) => a + toNum(o['total'])),
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
          'byStatus': byStatus,
          'total': orders.length,
          'latest': orders.take(5).toList(),
          'top': summary.take(5).toList(),
        };
      },
      builder: (context, d, _) {
        final b = brandOf(context);
        final hour = DateTime.now().hour;
        final byStatus = d['byStatus'] as Map<String, int>;
        final top = d['top'] as List<Map<String, dynamic>>;
        final topSales = top.fold<num>(0, (a, r) => a + toNum(r['sales']));
        return ListView(padding: const EdgeInsets.all(18), children: [
          GradientCard(
            padding: const EdgeInsets.all(22),
            child: Wrap(
                spacing: 24,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(hour < 12 ? 'صباح الخير' : 'مساء الخير',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${arabicDay(DateTime.now())} · ملخص المنصة اليوم',
                            style: const TextStyle(color: Colors.white70)),
                      ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _HeroStat('طلبات اليوم', '${d['today']}', b.accent),
                    const SizedBox(width: 12),
                    _HeroStat('مبيعات اليوم', bhd(d['todaySales']), b.accent),
                  ]),
                ]),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 1000
                ? 3
                : c.maxWidth >= 560
                    ? 2
                    : 1;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final k in [
                (
                  'طلبات جارية',
                  '${d['open']}',
                  Icons.pending_actions_outlined,
                  const [Color(0xFF0B6FB0), Color(0xFF47BFF0)],
                  'الطلبات'
                ),
                (
                  'مبيعات مسلّمة',
                  bhd(d['delivered']),
                  Icons.payments_outlined,
                  const [Color(0xFF0D6152), Color(0xFF3CC4A0)],
                  'تقارير التجار'
                ),
                (
                  'رصيد المنصة',
                  bhd(d['platform']),
                  Icons.account_balance_outlined,
                  const [Color(0xFF8C6A12), Color(0xFFD4AF37)],
                  'محفظة المنصة'
                ),
                (
                  'التجار',
                  '${d['active']} فعال من ${d['merchants']}',
                  Icons.storefront_outlined,
                  const [Color(0xFF3A2878), Color(0xFF7A5AD4)],
                  'التجار'
                ),
                (
                  'العملاء',
                  '${d['customers']}',
                  Icons.people_outline,
                  const [Color(0xFF8E2442), Color(0xFFE07A86)],
                  'العملاء'
                ),
                (
                  'كل الطلبات',
                  '${d['total']}',
                  Icons.receipt_long_outlined,
                  const [Color(0xFF9A4A12), Color(0xFFF2A65A)],
                  'الطلبات'
                ),
              ])
                SizedBox(
                    width: w,
                    child: InkWell(
                        onTap: () => onGo(k.$5),
                        borderRadius: BorderRadius.circular(20),
                        child: Kpi(
                            label: k.$1,
                            value: k.$2,
                            icon: k.$3,
                            colors: k.$4))),
            ]);
          }),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, c) {
            final two = c.maxWidth >= 900;
            final w = two ? (c.maxWidth - 12) / 2 : c.maxWidth;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                width: w,
                child: SectionCard(
                  title: 'الطلبات حسب الحالة',
                  trailing: TextButton(
                      onPressed: () => onGo('الطلبات'),
                      child: const Text('عرض الكل')),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 14,
                            child: d['total'] == 0
                                ? Container(color: const Color(0xFFE6EEF4))
                                : Row(children: [
                                    for (final e in byStatus.entries)
                                      if (e.value > 0)
                                        Expanded(
                                            flex: e.value,
                                            child: Container(
                                                color: statusColor(e.key))),
                                  ]),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          for (final e in byStatus.entries)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                  color:
                                      statusColor(e.key).withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                            color: statusColor(e.key),
                                            shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text(statusLabels[e.key]!,
                                        style: const TextStyle(fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Text('${e.value}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: statusColor(e.key))),
                                  ]),
                            ),
                        ]),
                      ]),
                ),
              ),
              SizedBox(
                width: w,
                child: SectionCard(
                  title: 'أعلى التجار مبيعاً',
                  trailing: TextButton(
                      onPressed: () => onGo('تقارير التجار'),
                      child: const Text('التقارير')),
                  child: top.isEmpty
                      ? const Text('لا توجد مبيعات بعد')
                      : Column(children: [
                          for (var i = 0; i < top.length; i++)
                            ShareBar(
                                name: top[i]['name'],
                                value: toNum(top[i]['sales']),
                                total: topSales,
                                colors: reportGradients[
                                    i % reportGradients.length]),
                        ]),
                ),
              ),
            ]);
          }),
          const SizedBox(height: 12),
          SectionCard(
            title: 'آخر الطلبات',
            trailing: TextButton(
                onPressed: () => onGo('الطلبات'),
                child: const Text('كل الطلبات')),
            child: Column(children: [
              if ((d['latest'] as List).isEmpty)
                const Text('لا توجد طلبات بعد'),
              for (final o in d['latest'] as List<Map<String, dynamic>>)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(colors: [
                        statusColor(o['status']),
                        Color.lerp(statusColor(o['status']), Colors.white, .35)!
                      ]),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        color: Colors.white, size: 20),
                  ),
                  title: Text(
                      '#${o['code']} · ${o['merchants']?['name'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${o['customer_name'] ?? ''} · ${dateTimeText(o['created_at'])}'),
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
            ]),
          ),
        ]);
      },
    );
  }
}

/// e.g. "الثلاثاء 10 نوفمبر 2026", without needing locale data to load.
String arabicDay(DateTime d) {
  const days = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد'
  ];
  const months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر'
  ];
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} ${d.year}';
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(this.label, this.value, this.accent);
  final String label;
  final String value;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: accent, fontSize: 22, fontWeight: FontWeight.w700)),
        ]),
      );
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
            var q = sb
                .from('orders')
                .select('*, merchants(name)')
                .isFilter('deleted_at', null);
            if (status != 'all') q = q.eq('status', status);
            return List<Map<String, dynamic>>.from(
                await q.order('created_at', ascending: false).limit(200));
          },
          builder: (context, orders, _) {
            if (orders.isEmpty)
              return ListView(children: const [Empty('لا توجد طلبات')]);
            return LayoutBuilder(builder: (context, c) {
              final cols = (c.maxWidth / 340).floor().clamp(1, 4);
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 238),
                itemCount: orders.length,
                itemBuilder: (context, i) => OrderTile(o: orders[i]),
              );
            });
          },
        ),
      ),
    ]);
  }
}

/// One order in the admin grid: gradient header in the status colour, then dates, payment, driver and total.
class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.o});
  final Map<String, dynamic> o;
  @override
  Widget build(BuildContext context) {
    final c = statusColor(o['status']);
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(icon, size: 16, color: Colors.black45),
            const SizedBox(width: 6),
            Expanded(
                child: Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13))),
          ]),
        );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    OrderDetailsPage(orderId: o['id'], viewer: 'admin'))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [c, Color.lerp(c, Colors.white, .4)!]),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${o['code']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      Text(o['merchants']?['name'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(999)),
                child: Text(
                    o['held'] == true
                        ? '${tr('موقوف')} · ${statusOf(o)}'
                        : statusOf(o),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    line(Icons.person_outline, o['customer_name'] ?? ''),
                    line(Icons.event_outlined,
                        'الذبح ${dateText(o['slaughter_date'])}'),
                    line(
                        o['fulfillment'] == 'pickup'
                            ? Icons.storefront_outlined
                            : Icons.local_shipping_outlined,
                        '${o['fulfillment'] == 'pickup' ? 'استلام من المحل' : 'التوصيل'} ${dateText(o['delivery_date'])} ${o['delivery_slot'] ?? ''}'),
                    line(Icons.payments_outlined,
                        '${payLabel(o)} · ${paymentStatusLabels[o['payment_status']]}'),
                    if (o['fulfillment'] != 'pickup')
                      line(Icons.two_wheeler_outlined,
                          'المندوب: ${o['driver_name'] ?? 'غير معيّن'}'),
                  ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: c.withValues(alpha: .06),
            child: Row(children: [
              const Text('الإجمالي', style: TextStyle(color: Colors.black54)),
              const Spacer(),
              Text(bhd(o['total']),
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: c)),
            ]),
          ),
        ]),
      ),
    );
  }
}
