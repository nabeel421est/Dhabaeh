import 'package:flutter/material.dart';

import '../auth/gate.dart';
import '../core/common.dart';
import '../customer/order_details.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key, required this.profile, this.switcher});
  final Map<String, dynamic> profile;
  final Widget? switcher;
  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tab == 0 ? 'الطلبات المتاحة' : 'طلباتي'),
          Text(widget.profile['full_name'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
        actions: commonActions(context, widget.switcher),
      ),
      body: IndexedStack(index: tab, children: [DriverList(available: true, onClaimed: () => setState(() => tab = 1)), const DriverList(available: false)]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'المتاحة'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), label: 'طلباتي'),
        ],
      ),
    );
  }
}

class DriverList extends StatelessWidget {
  const DriverList({super.key, required this.available, this.onClaimed});
  final bool available;
  final VoidCallback? onClaimed;

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['orders'],
      load: () async {
        var q = sb.from('orders').select('*, merchants(name, area), order_items(name, qty)');
        q = available
            ? q.isFilter('driver_id', null).inFilter('status', ['accepted', 'slaughtering', 'ready'])
            : q.eq('driver_id', myId!).not('status', 'in', '(delivered,cancelled)');
        return List<Map<String, dynamic>>.from(await q.order('delivery_date'));
      },
      builder: (context, orders, reload) {
        if (orders.isEmpty) {
          return ListView(children: [Empty(available ? 'لا توجد طلبات متاحة الآن' : 'ما عندك طلبات حالية', icon: Icons.local_shipping_outlined)]);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final o = orders[i];
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text('#${o['code']} · ${o['merchants']?['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    StatusChip(o['status']),
                  ]),
                  const SizedBox(height: 6),
                  Text('من: ${o['merchants']?['area'] ?? ''}'),
                  Text('إلى: ${o['address']}'),
                  Text('التوصيل ${dateText(o['delivery_date'])} · ${o['delivery_slot']}'),
                  if (o['payment_method'] == 'cash') Text('تحصيل نقدي: ${bhd(o['total'])}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF9A5B13))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsPage(orderId: o['id'], viewer: 'driver'))),
                        child: const Text('التفاصيل'),
                      ),
                    ),
                    if (available) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final r = await guard(context, () => sb.rpc('driver_claim', params: {'p_order': o['id']}), ok: 'تم قبول الطلب');
                            await reload();
                            if (r != null) onClaimed?.call();
                          },
                          child: const Text('قبول الطلب'),
                        ),
                      ),
                    ],
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
