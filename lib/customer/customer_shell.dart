import 'package:flutter/material.dart';

import '../auth/gate.dart';
import '../core/brand.dart';
import '../core/common.dart';
import 'stores.dart';
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
            ? 'الملاحم'
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
              icon: Icon(Icons.storefront_outlined), label: 'الملاحم'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'طلباتي'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined), label: 'الإشعارات'),
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
              ? Image.network(url,
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph())
              : _ph(),
        ),
      );
  Widget _ph() => Container(
      color: const Color(0xFFF3E7E9),
      child: const Icon(Icons.storefront, color: Color(0xFF7A1E2C)));
}

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['orders'],
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('orders')
          .select('*, merchants(name), order_items(name, qty, options)')
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
                title: Text('#${o['code']} · ${orderKindLabels[orderKind(o)]} · ${o['merchants']?['name'] ?? ''}',
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
