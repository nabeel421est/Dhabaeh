import 'package:flutter/material.dart';

import '../auth/gate.dart';
import '../core/brand.dart';
import '../core/common.dart';
import 'booking_page.dart';
import 'order_details.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: Text(tab == 0
            ? 'المسالخ'
            : tab == 1
                ? 'طلباتي'
                : 'الإشعارات'),
        actions: commonActions(context, widget.switcher),
      ),
      body: IndexedStack(
          index: tab,
          children: const [StoresPage(), MyOrdersPage(), NotificationsPage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.storefront_outlined), label: 'المسالخ'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'طلباتي'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined), label: 'الإشعارات'),
        ],
      ),
    );
  }
}

class StoresPage extends StatelessWidget {
  const StoresPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['merchants'],
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('merchants')
          .select('id, name, logo_url, area, description, is_open')
          .eq('suspended', false)
          .eq('frozen', false)
          .order('name')),
      builder: (context, stores, _) {
        if (stores.isEmpty)
          return ListView(
              children: const [Empty('لا توجد مسالخ متاحة حالياً')]);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: stores.length + 1,
          separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 16 : 10),
          itemBuilder: (context, i) {
            if (i == 0)
              return const BrandBanner(
                  title: 'أهلاً بك',
                  subtitle: 'اختر المسلخ واحجز ذبيحتك، ونوصلها لباب بيتك');
            final m = stores[i - 1];
            final open = m['is_open'] == true;
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: StoreLogo(m['logo_url'], size: 52),
                title: Text(m['name'],
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle:
                    Text([m['area'], if (!open) 'مغلق حالياً'].join(' · ')),
                trailing: const Icon(Icons.chevron_left),
                enabled: open,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => StorePage(store: m))),
              ),
            );
          },
        );
      },
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
              ? Image.network(url,
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph())
              : _ph(),
        ),
      );
  Widget _ph() => Container(
      color: const Color(0xFFF3E7E9),
      child: const Icon(Icons.storefront, color: Color(0xFF7A1E2C)));
}

class StorePage extends StatelessWidget {
  const StorePage({super.key, required this.store});
  final Map<String, dynamic> store;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: Text(store['name'])),
      body: Loader<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
        realtimeTables: const ['products', 'offers'],
        load: () async {
          final p = await sb
              .from('products')
              .select()
              .eq('merchant_id', store['id'])
              .eq('available', true)
              .order('price');
          final o = await sb
              .from('offers')
              .select()
              .eq('merchant_id', store['id'])
              .eq('active', true);
          return (
            List<Map<String, dynamic>>.from(p),
            List<Map<String, dynamic>>.from(o)
          );
        },
        builder: (context, data, _) {
          final (products, offers) = data;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              StoreLogo(store['logo_url'], size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store['name'],
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      Text(store['area'] ?? '',
                          style: const TextStyle(color: Colors.black54)),
                      if ((store['description'] ?? '').toString().isNotEmpty)
                        Text(store['description']),
                    ]),
              ),
            ]),
            if (offers.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final o in offers)
                Card(
                  color: const Color(0xFFFDF1E3),
                  child: ListTile(
                      leading: const Icon(Icons.local_offer,
                          color: Color(0xFF9A5B13)),
                      title: Text(o['title'])),
                ),
            ],
            const SizedBox(height: 16),
            const Text('اختر الذبيحة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (products.isEmpty) const Empty('لا توجد منتجات متاحة'),
            for (final p in products)
              Card(
                child: ListTile(
                  title: Text(p['name'],
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([
                    p['category'],
                    if ((p['description'] ?? '').toString().isNotEmpty)
                      p['description']
                  ].join(' · ')),
                  trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(bhd(p['price']),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        if (offerFor(offers, p) != null)
                          Text(offerFor(offers, p)!['title'],
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF9A5B13))),
                      ]),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              BookingPage(store: store, product: p))),
                ),
              ),
          ]);
        },
      ),
    );
  }

  static Map<String, dynamic>? offerFor(
      List<Map<String, dynamic>> offers, Map<String, dynamic> p) {
    for (final o in offers) {
      if (o['product_id'] == p['id']) return o;
    }
    return null;
  }
}

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['orders'],
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('orders')
          .select('*, merchants(name), order_items(name, qty)')
          .eq('customer_id', myId!)
          .order('created_at', ascending: false)),
      builder: (context, orders, _) {
        if (orders.isEmpty)
          return ListView(children: const [
            Empty('ما عندك طلبات بعد', icon: Icons.receipt_long_outlined)
          ]);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final o = orders[i];
            final items = (o['order_items'] as List)
                .map((x) => '${x['name']} × ${x['qty']}')
                .join('، ');
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text('#${o['code']} · ${o['merchants']?['name'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '$items\nالتوصيل ${dateText(o['delivery_date'])} · ${o['delivery_slot']}'),
                isThreeLine: true,
                trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip(o['status']),
                      const SizedBox(height: 4),
                      Text(bhd(o['total']),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => OrderDetailsPage(
                            orderId: o['id'], viewer: 'customer'))),
              ),
            );
          },
        );
      },
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['notifications'],
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50)),
      builder: (context, list, _) {
        if (list.isEmpty)
          return ListView(children: const [
            Empty('لا توجد إشعارات', icon: Icons.notifications_none)
          ]);
        return ListView(padding: const EdgeInsets.all(16), children: [
          for (final n in list)
            Card(
              child: ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: Text(n['title'],
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle:
                    Text('${n['body']}\n${dateTimeText(n['created_at'])}'),
                isThreeLine: true,
              ),
            ),
        ]);
      },
    );
  }
}
