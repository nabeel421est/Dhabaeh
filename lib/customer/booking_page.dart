import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/common.dart';
import 'order_details.dart';

const slaughterTimes = ['7:00 ص', '9:00 ص', '11:00 ص', '1:00 م', '4:00 م'];
const deliverySlots = ['8 - 10 ص', '10 - 12 ظ', '12 - 2 م', '4 - 6 م', '6 - 8 م'];
const cuttingOptions = ['تقطيع ثلاجة', 'تقطيع مندي', 'أنصاف', 'أرباع', 'كامل بدون تقطيع'];
const packingOptions = ['أكياس', 'صحون فلين', 'بدون تغليف'];

num calcValue(num base, String type, num v, bool enabled) {
  if (!enabled) return 0;
  return type == 'percent' ? (base * v / 100) : v;
}

class BookingPage extends StatefulWidget {
  const BookingPage({super.key, required this.store, required this.product});
  final Map<String, dynamic> store;
  final Map<String, dynamic> product;
  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  int qty = 1;
  String cutting = cuttingOptions.first;
  String packing = packingOptions.first;
  bool keepHead = false;
  late DateTime slaughterDay;
  String slaughterTime = slaughterTimes.first;
  late DateTime deliveryDay;
  String slot = deliverySlots.first;
  String? zoneId;
  String payment = 'benefitpay';
  final house = TextEditingController();
  final road = TextEditingController();
  final block = TextEditingController();
  final note = TextEditingController();
  PlatformFile? receipt;
  bool busy = false;

  late Future<(Map<String, dynamic>, List<Map<String, dynamic>>, List<Map<String, dynamic>>)> setup;

  @override
  void initState() {
    super.initState();
    final t = DateTime.now().add(const Duration(days: 1));
    slaughterDay = DateTime(t.year, t.month, t.day);
    deliveryDay = slaughterDay;
    setup = () async {
      final s = await sb.from('platform_settings').select().eq('id', 1).single();
      final z = await sb.from('delivery_zones').select().eq('active', true).order('name');
      final a = await sb.from('customer_addresses').select().eq('user_id', myId!).order('created_at', ascending: false);
      return (s, List<Map<String, dynamic>>.from(z), List<Map<String, dynamic>>.from(a));
    }();
  }

  List<DateTime> days(DateTime from, int n) => [for (var i = 0; i < n; i++) from.add(Duration(days: i))];
  String dayLabel(DateTime d) {
    const names = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return '${names[d.weekday - 1]}\n${d.day}/${d.month}';
  }

  Future<void> submit(List<Map<String, dynamic>> zones) async {
    if (zoneId == null) return toast(context, 'اختر منطقة التوصيل', error: true);
    if (block.text.trim().isEmpty || road.text.trim().isEmpty || house.text.trim().isEmpty) {
      return toast(context, 'أكمل العنوان: المنزل والطريق والمجمع', error: true);
    }
    if (payment == 'bank_transfer' && receipt == null) return toast(context, 'أرفق إيصال التحويل', error: true);
    final zone = zones.firstWhere((z) => z['id'] == zoneId);
    final address = 'منزل ${house.text.trim()}، طريق ${road.text.trim()}، مجمع ${block.text.trim()}، ${zone['name']}'
        '${note.text.trim().isEmpty ? '' : ' · ${note.text.trim()}'}';
    setState(() => busy = true);
    final order = await guard(context, () async {
      final o = await sb.rpc('place_order', params: {
        'p_merchant': widget.store['id'],
        'p_items': [
          {'product_id': widget.product['id'], 'qty': qty, 'options': {'cutting': cutting, 'packing': packing, 'keep_head': keepHead}}
        ],
        'p_slaughter_date': isoDate(slaughterDay),
        'p_slaughter_time': slaughterTime,
        'p_delivery_date': isoDate(deliveryDay),
        'p_delivery_slot': slot,
        'p_zone': zoneId,
        'p_address': address,
        'p_payment': payment,
        'p_notes': null,
      });
      if (receipt != null && receipt!.bytes != null) {
        final path = '$myId/receipt-${o['id']}-${receipt!.name}';
        await sb.storage.from('docs').uploadBinary(path, receipt!.bytes!);
        await sb.rpc('attach_receipt', params: {'p_order': o['id'], 'p_path': path});
      }
      await sb.from('customer_addresses').upsert({
        'user_id': myId, 'house': house.text.trim(), 'road': road.text.trim(), 'block': block.text.trim(),
        'area': zone['name'], 'note': note.text.trim(),
      });
      return o;
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (order != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderDetailsPage(orderId: order['id'], viewer: 'customer', justPlaced: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      appBar: AppBar(title: Text('حجز ${p['name']}')),
      body: FutureBuilder(
        future: setup,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(errText(snap.error!)));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (settings, zones, addresses) = snap.data!;
          if (addresses.isNotEmpty && house.text.isEmpty && road.text.isEmpty) {
            final a = addresses.first;
            house.text = a['house'] ?? '';
            road.text = a['road'] ?? '';
            block.text = a['block'] ?? '';
            note.text = a['note'] ?? '';
            zoneId ??= zones.where((z) => z['name'] == a['area']).map((z) => z['id'] as String).firstOrNull;
          }
          final sub = toNum(p['price']) * qty;
          final custComm = calcValue(sub, settings['customer_comm_type'], toNum(settings['customer_comm_value']), settings['customer_comm_enabled'] == true);
          final fee = zoneId == null ? 0 : toNum(zones.firstWhere((z) => z['id'] == zoneId)['fee']);
          final total = sub + custComm + fee;

          Widget chips<T>(List<T> values, T selected, String Function(T) label, void Function(T) pick) => Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  for (final v in values)
                    ChoiceChip(label: Text(label(v), textAlign: TextAlign.center), selected: v == selected, onSelected: (_) => setState(() => pick(v))),
                ],
              );

          return ListView(padding: const EdgeInsets.all(16), children: [
            SectionCard(
              title: 'الذبيحة',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text('${p['name']} · ${bhd(p['price'])}')),
                  IconButton(onPressed: qty > 1 ? () => setState(() => qty--) : null, icon: const Icon(Icons.remove_circle_outline)),
                  Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  IconButton(onPressed: () => setState(() => qty++), icon: const Icon(Icons.add_circle_outline)),
                ]),
                const SizedBox(height: 8),
                const Text('طريقة التقطيع'),
                const SizedBox(height: 6),
                chips(cuttingOptions, cutting, (v) => v, (v) => cutting = v),
                const SizedBox(height: 12),
                const Text('التغليف'),
                const SizedBox(height: 6),
                chips(packingOptions, packing, (v) => v, (v) => packing = v),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: keepHead, onChanged: (v) => setState(() => keepHead = v), title: const Text('أبي الرأس والكوارع')),
              ]),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'موعد الذبح',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                chips(days(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).add(const Duration(days: 1)), 7), slaughterDay, dayLabel, (v) {
                  slaughterDay = v;
                  if (deliveryDay.isBefore(v)) deliveryDay = v;
                }),
                const SizedBox(height: 10),
                chips(slaughterTimes, slaughterTime, (v) => v, (v) => slaughterTime = v),
              ]),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'موعد التوصيل',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                chips(days(slaughterDay, 3), deliveryDay, dayLabel, (v) => deliveryDay = v),
                const SizedBox(height: 10),
                chips(deliverySlots, slot, (v) => v, (v) => slot = v),
              ]),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'عنوان التوصيل',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DropdownButtonFormField<String>(
                  initialValue: zoneId,
                  decoration: const InputDecoration(labelText: 'المنطقة *'),
                  items: [for (final z in zones) DropdownMenuItem(value: z['id'] as String, child: Text('${z['name']} · توصيل ${bhd(z['fee'])}'))],
                  onChanged: (v) => setState(() => zoneId = v),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Field('المنزل', house, required: true, keyboard: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: Field('الطريق', road, required: true, keyboard: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: Field('المجمع', block, required: true, keyboard: TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                Field('وصف إضافي', note, hint: 'اختياري'),
              ]),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'طريقة الدفع',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final m in paymentLabels.entries)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: m.key,
                    groupValue: payment,
                    onChanged: (v) => setState(() => payment = v!),
                    title: Text(m.value),
                  ),
                if (payment == 'bank_transfer') ...[
                  Text('حوّل المبلغ إلى حساب المنصة: ${settings['platform_iban'] ?? 'يُضاف من الإدارة'}', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.attach_file),
                    label: Text(receipt?.name ?? 'إرفاق إيصال التحويل'),
                    onPressed: () async {
                      final r = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']);
                      if (r != null) setState(() => receipt = r.files.first);
                    },
                  ),
                ],
                if (payment == 'benefitpay')
                  const Text('في نسخة الاختبار يُسجّل الطلب بانتظار الدفع، والربط الفعلي مع BenefitPay في المرحلة الرابعة.', style: TextStyle(color: Colors.black54, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'الفاتورة',
              child: Column(children: [
                KeyVal('قيمة الذبيحة', bhd(sub)),
                if (custComm > 0) KeyVal('رسوم الخدمة', bhd(custComm)),
                KeyVal('التوصيل', bhd(fee)),
                const Divider(),
                KeyVal('الإجمالي', bhd(total), bold: true),
                const Text('الخصومات والعروض تُحسب نهائياً عند تأكيد الطلب', style: TextStyle(fontSize: 12, color: Colors.black45)),
              ]),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : () => submit(zones), child: Text(busy ? 'جارٍ الإرسال…' : 'تأكيد الحجز')),
            const SizedBox(height: 24),
          ]);
        },
      ),
    );
  }
}
