import 'package:flutter/material.dart' hide Text;

import '../auth/gate.dart';
import '../core/brand.dart';
import '../core/common.dart';
import '../core/push.dart';
import 'stores.dart';
import 'order_details.dart';
import 'customer_profile.dart';
import '../core/ttext.dart';
import '../core/i18n.dart';
import '../core/tap_pay.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, required this.profile, this.switcher});
  final Map<String, dynamic> profile;
  final Widget? switcher;
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    // Back from the Tap payment page: confirm the payment and open the order.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = await checkTapReturn(context);
      if (id != null && mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    OrderDetailsPage(orderId: id, viewer: 'customer')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        logo: true,
        title: Text(tab == 0
            ? 'الملاحم'
            : tab == 1
                ? 'طلباتي'
                : 'الإشعارات'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: IconButton(
              tooltip: tr('معلوماتي'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CustomerProfilePage())),
              icon: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: brandOf(context).accent, width: 1.4),
                    color: Colors.white.withValues(alpha: .14)),
                child: Icon(Icons.person_outline,
                    size: 20, color: brandOf(context).accent),
              ),
            ),
          ),
          ...commonActions(context, widget.switcher),
        ],
      ),
      body: Column(children: [
        const PushBanner(),
        Expanded(
            child: IndexedStack(index: tab, children: const [
          StoresPage(),
          MyOrdersPage(),
          NotificationsPage()
        ])),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.storefront_outlined), label: tr('الملاحم')),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: tr('طلباتي')),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined), label: tr('الإشعارات')),
        ],
      ),
    );
  }
}

class StoreLogo extends StatelessWidget {
  const StoreLogo(this.url, {super.key, this.size = 48});
  final dynamic url;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size,
          child: (url is String && url.isNotEmpty)
              ? (url.toLowerCase().endsWith('-cut.png')
                  // Logo without background: fitted whole on a clean tile.
                  ? Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(size * .07),
                      child: Image.network(url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _ph()))
                  : Image.network(url,
                      fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph()))
              : _ph(),
        ),
      );
  Widget _ph() => Container(
      color: const Color(0xFFF3E7E9),
      child: const Icon(Icons.storefront, color: Color(0xFF7A1E2C)));
}

int _cols(double w, double cell) => (w / cell).floor().clamp(1, 3);

/// Customer's orders: gradient hero, status filters and a grid of gradient order cards.
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});
  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  String filter = 'open';
  static bool isOpen(Map o) =>
      !['delivered', 'cancelled'].contains(o['status']);

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['orders'],
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('orders')
          .select(
              '*, merchants(name, logo_url), order_items(name, qty, options)')
          .eq('customer_id', myId!)
          .order('created_at', ascending: false)),
      builder: (context, orders, _) {
        final b = brandOf(context);
        final shown = orders.where((o) {
          if (filter == 'open') return isOpen(o);
          if (filter == 'all') return true;
          return o['status'] == filter;
        }).toList();
        final delivered = orders.where((o) => o['status'] == 'delivered');
        final filters = <String, (String, IconData, List<Color>)>{
          'open': ('الجارية', Icons.timelapse, b.stops.sublist(1)),
          'delivered': ('تم التسليم', Icons.task_alt, G.emerald),
          'cancelled': ('ملغية', Icons.block, G.ruby),
          'all': ('الكل', Icons.all_inbox_outlined, G.violet),
        };
        int count(String k) => k == 'all'
            ? orders.length
            : k == 'open'
                ? orders.where(isOpen).length
                : orders.where((o) => o['status'] == k).length;
        return ListView(padding: const EdgeInsets.all(16), children: [
          PageHero(
            icon: Icons.receipt_long_outlined,
            title: 'طلباتي',
            subtitle: 'تابع حجوزاتك ومشترياتك خطوة بخطوة',
            stats: [
              ('جارية', '${orders.where(isOpen).length}'),
              ('مكتملة', '${delivered.length}'),
              (
                'إجمالي مشترياتي',
                bhd(delivered.fold<num>(0, (a, o) => a + toNum(o['total'])))
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final f in filters.entries)
                TonePill(
                  label: f.value.$1,
                  icon: f.value.$2,
                  colors: f.value.$3,
                  count: count(f.key),
                  selected: filter == f.key,
                  onTap: () => setState(() => filter = f.key),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            Empty(orders.isEmpty ? 'ما عندك طلبات بعد' : 'لا توجد طلبات هنا',
                icon: Icons.receipt_long_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = _cols(c.maxWidth, 340);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final o in shown)
                SizedBox(width: w, child: CustomerOrderCard(o: o)),
            ]);
          }),
        ]);
      },
    );
  }
}

const _stepIcons = [
  Icons.receipt_outlined,
  Icons.thumb_up_alt_outlined,
  Icons.content_cut,
  Icons.inventory_2_outlined,
  Icons.local_shipping_outlined,
  Icons.home_outlined,
];

class CustomerOrderCard extends StatelessWidget {
  const CustomerOrderCard({super.key, required this.o});
  final Map<String, dynamic> o;
  @override
  Widget build(BuildContext context) {
    final status = '${o['status']}';
    final c = statusColor(status);
    final tone = status == 'delivered'
        ? G.emerald
        : status == 'cancelled'
            ? G.ruby
            : toneOf(c);
    final kind = orderKind(o);
    final items = (o['order_items'] as List? ?? [])
        .map((x) => '${x['name']} × ${x['qty']}')
        .join('، ');
    final step = statusFlow.indexOf(status);
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                  color: tone.first.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 15, color: tone.first),
            ),
            const SizedBox(width: 8),
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
                    OrderDetailsPage(orderId: o['id'], viewer: 'customer'))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: tone)),
            child: Column(children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(13)),
                  child: StoreLogo(o['merchants']?['logo_url'], size: 42),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${o['merchants']?['name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        Text('#${o['code']} · ${dateText(o['created_at'])}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _pill(statusLabels[status] ?? status, .26),
                  const SizedBox(height: 4),
                  _pill('${orderKindLabels[kind]}', .14),
                ]),
              ]),
              if (step >= 0) ...[
                const SizedBox(height: 12),
                Row(children: [
                  for (var i = 0; i < statusFlow.length; i++) ...[
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= step
                            ? Colors.white
                            : Colors.white.withValues(alpha: .18),
                      ),
                      child: Icon(_stepIcons[i],
                          size: 14,
                          color: i <= step ? tone.first : Colors.white70),
                    ),
                    if (i < statusFlow.length - 1)
                      Expanded(
                        child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: i < step
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: .25))),
                      ),
                  ],
                ]),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              line(Icons.set_meal_outlined, items.isEmpty ? '-' : items),
              line(Icons.content_cut,
                  'الذبح ${dateText(o['slaughter_date'])} · ${o['slaughter_time'] ?? ''}'),
              line(Icons.local_shipping_outlined,
                  'التوصيل ${dateText(o['delivery_date'])} · ${o['delivery_slot'] ?? ''}'),
              const Divider(height: 14),
              Row(children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${payLabel(o)} · ${payStatusText(o)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ),
                ShaderMask(
                  shaderCallback: (r) =>
                      LinearGradient(colors: tone).createShader(r),
                  child: Text(bhd(o['total']),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pill(String t, double a) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: a),
            borderRadius: BorderRadius.circular(999)),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
      );
}

/// Picks an icon and gradient for a notification from its wording.
/// Sent by the platform admin to everyone or to all customers.
bool isBroadcast(Map n) =>
    n['audience'] == 'all' || n['audience'] == 'customers';

(IconData, List<Color>) notifLook(Map n) {
  if (n['kind'] == 'offer') return (Icons.local_offer_outlined, G.gold);
  if (isBroadcast(n)) return (Icons.campaign_outlined, G.sapphire);
  final t = '${n['title']} ${n['body']}';
  bool has(List<String> w) => w.any(t.contains);
  if (has(['تسليم', 'توصيل', 'الطريق', 'مندوب'])) {
    return (Icons.local_shipping_outlined, G.sky);
  }
  if (has(['دفع', 'مبلغ', 'تحويل', 'إيصال', 'محفظة'])) {
    return (Icons.payments_outlined, G.emerald);
  }
  if (has(['ذبح', 'جاهز'])) return (Icons.content_cut, G.amber);
  if (has(['إلغاء', 'ملغي', 'رفض'])) return (Icons.block, G.ruby);
  if (has(['عرض', 'خصم', 'تخفيض'])) return (Icons.local_offer_outlined, G.gold);
  if (has(['طلب', 'حجز'])) return (Icons.receipt_long_outlined, G.violet);
  if (n['audience'] == 'all') return (Icons.campaign_outlined, G.sapphire);
  return (Icons.notifications_active_outlined, G.teal);
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String filter = 'all'; // all | offer | admin | order

  static bool _match(String f, Map n) => switch (f) {
        'offer' => n['kind'] == 'offer',
        'admin' => isBroadcast(n) && n['kind'] != 'offer',
        'order' => !isBroadcast(n),
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['notifications'],
      // Only what is meant for this customer: platform messages and offers to
      // everyone/customers, plus updates on their own orders.
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('notifications')
          .select()
          .inFilter('audience', ['all', 'customers', 'user'])
          .order('created_at', ascending: false)
          .limit(80)),
      builder: (context, all, _) {
        final list = all.where((n) => _match(filter, n)).toList();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        String group(Map n) {
          final d = DateTime.tryParse('${n['created_at']}')?.toLocal();
          if (d == null) return 'أقدم';
          final day = DateTime(d.year, d.month, d.day);
          if (day == today) return 'اليوم';
          if (day == today.subtract(const Duration(days: 1))) return 'أمس';
          if (today.difference(day).inDays < 7) return 'هذا الأسبوع';
          return 'أقدم';
        }

        final groups = <String, List<Map<String, dynamic>>>{};
        for (final n in list) {
          groups.putIfAbsent(group(n), () => []).add(n);
        }
        return ListView(padding: const EdgeInsets.all(16), children: [
          PageHero(
            icon: Icons.notifications_active_outlined,
            title: 'الإشعارات',
            subtitle: 'آخر تحديثات طلباتك وعروض الملاحم',
            stats: [
              ('اليوم', '${groups['اليوم']?.length ?? 0}'),
              ('العروض', '${all.where((n) => _match('offer', n)).length}'),
              ('الكل', '${all.length}'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final f in const [
                ('all', 'الكل', G.violet),
                ('offer', 'العروض', G.gold),
                ('admin', 'رسائل الإدارة', G.sapphire),
                ('order', 'طلباتي', G.teal),
              ])
                TonePill(
                    label: f.$2,
                    count: all.where((n) => _match(f.$1, n)).length,
                    colors: f.$3,
                    selected: filter == f.$1,
                    onTap: () => setState(() => filter = f.$1)),
            ]),
          ),
          const SizedBox(height: 14),
          if (list.isEmpty)
            const Empty('لا توجد إشعارات', icon: Icons.notifications_none),
          for (final g in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Row(children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: brandOf(context).stops.sublist(1)),
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                Text(g.key,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text('(${g.value.length})',
                    style: const TextStyle(color: Colors.black45)),
              ]),
            ),
            LayoutBuilder(builder: (context, c) {
              final cols = _cols(c.maxWidth, 420);
              final w = (c.maxWidth - 12 * (cols - 1)) / cols;
              return Wrap(spacing: 12, runSpacing: 10, children: [
                for (final n in g.value)
                  SizedBox(width: w, child: _NotifCard(n: n)),
              ]);
            }),
            const SizedBox(height: 16),
          ],
        ]);
      },
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.n});
  final Map<String, dynamic> n;
  @override
  Widget build(BuildContext context) {
    final (icon, tone) = notifLook(n);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [tone.last.withValues(alpha: .13), Colors.white]),
          border:
              BorderDirectional(start: BorderSide(color: tone.first, width: 4)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GradientBadge(colors: tone, icon: icon, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (isBroadcast(n))
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: tone),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(
                      n['kind'] == 'offer'
                          ? 'عرض من ذبائح'
                          : 'رسالة من إدارة التطبيق',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800)),
                ),
              Text('${n['title'] ?? ''}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: tone.first)),
              const SizedBox(height: 3),
              Text('${n['body'] ?? ''}',
                  style: const TextStyle(fontSize: 13.5, height: 1.45)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.schedule, size: 13, color: Colors.black38),
                const SizedBox(width: 4),
                Text(dateTimeText(n['created_at']),
                    style:
                        const TextStyle(fontSize: 11.5, color: Colors.black45)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
