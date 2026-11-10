import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/common.dart';
import 'order_details.dart';
import 'stores.dart' show offerValue;

const slaughterTimes = ['7:00 ص', '9:00 ص', '11:00 ص', '1:00 م', '4:00 م'];
const deliverySlots = [
  '8 - 10 ص',
  '10 - 12 ظ',
  '12 - 2 م',
  '4 - 6 م',
  '6 - 8 م'
];
const cuttingOptions = [
  'تقطيع ثلاجة',
  'تقطيع مندي',
  'أنصاف',
  'أرباع',
  'كامل بدون تقطيع'
];
const cuttingIcons = [
  Icons.kitchen_outlined,
  Icons.rice_bowl_outlined,
  Icons.vertical_split_outlined,
  Icons.grid_view_outlined,
  Icons.crop_square_outlined,
];
const packingOptions = ['أكياس', 'صحون فلين', 'بدون تغليف'];
const paymentLook = <String, (IconData, String)>{
  'benefitpay': (Icons.phone_iphone, 'ادفع من تطبيق بنفت'),
  'bank_transfer': (Icons.account_balance_outlined, 'حوّل وارفع الإيصال'),
  'cash': (Icons.payments_outlined, 'ادفع للمندوب عند الاستلام'),
};

num calcValue(num base, String type, num v, bool enabled) {
  if (!enabled) return 0;
  return type == 'percent' ? (base * v / 100) : v;
}

const _weekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد'
];

/// Everything the customer picks, shared by the order page and the payment page.
class OrderDraft {
  OrderDraft(this.kind) {
    final t = DateTime.now().add(const Duration(days: 1));
    slaughterDay = DateTime(t.year, t.month, t.day);
    deliveryDay = slaughterDay;
  }
  final String kind;
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
  bool prefilled = false;

  bool get purchase => kind == 'purchase';
  Map<String, dynamic> get options => purchase
      ? {
          'kind': 'purchase',
          'cutting': cutting,
          'packing': packing,
          'keep_head': keepHead
        }
      : {'kind': 'reservation'};
}

/// Data both pages need: settings, delivery zones, saved address, the customer's profile.
typedef OrderSetup = (
  Map<String, dynamic>,
  List<Map<String, dynamic>>,
  List<Map<String, dynamic>>,
  Map<String, dynamic>?
);

Future<OrderSetup> loadOrderSetup() async {
  final s = await sb.from('platform_settings').select().eq('id', 1).single();
  final z =
      await sb.from('delivery_zones').select().eq('active', true).order('name');
  final a = await sb
      .from('customer_addresses')
      .select()
      .eq('user_id', myId!)
      .order('created_at', ascending: false);
  final p = await sb
      .from('profiles')
      .select('full_name, phone')
      .eq('id', myId!)
      .maybeSingle();
  return (
    s,
    List<Map<String, dynamic>>.from(z),
    List<Map<String, dynamic>>.from(a),
    p
  );
}

// ---------------------------------------------------------------- small building blocks

class _Section extends StatelessWidget {
  const _Section(
      {required this.icon,
      required this.title,
      required this.colors,
      required this.child});
  final IconData icon;
  final String title;
  final List<Color> colors;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              GradientBadge(colors: colors, icon: icon, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice(
      {required this.label,
      required this.selected,
      required this.colors,
      required this.onTap,
      this.icon,
      this.sub,
      this.width});
  final String label;
  final bool selected;
  final List<Color> colors;
  final VoidCallback onTap;
  final IconData? icon;
  final String? sub;
  final double? width;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: selected
                ? LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: colors)
                : null,
            color: selected ? null : const Color(0xFFF8F6F5),
            border: Border.all(
                color: selected
                    ? Colors.transparent
                    : colors.first.withValues(alpha: .18)),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: colors.first.withValues(alpha: .25),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 22, color: selected ? Colors.white : colors.first),
              const SizedBox(height: 4),
            ],
            if (sub != null)
              Text(sub!,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: selected ? Colors.white70 : Colors.black45)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: selected ? Colors.white : Colors.black87)),
          ]),
        ),
      );
}

Widget _wrap(List<Widget> c) => Wrap(spacing: 8, runSpacing: 8, children: c);

List<DateTime> _days(DateTime from, int n) =>
    [for (var i = 0; i < n; i++) from.add(Duration(days: i))];

/// Product summary card at the top of both pages.
class _ProductBanner extends StatelessWidget {
  const _ProductBanner(
      {required this.store,
      required this.product,
      required this.colors,
      required this.kind,
      required this.unit,
      this.qty,
      this.onQty});
  final Map<String, dynamic> store;
  final Map<String, dynamic> product;
  final List<Color> colors;
  final String kind;
  final num unit;
  final int? qty;
  final ValueChanged<int>? onQty;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [colors.first, colors.last, colors.first]),
          boxShadow: [
            BoxShadow(
                color: colors.first.withValues(alpha: .3),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.set_meal_outlined,
                color: Colors.white, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999)),
                child: Text(orderKindLabels[kind]!,
                    style: TextStyle(
                        color: colors.first,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 4),
              Text('${product['name']}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              Text('${store['name']} · ${bhd(unit)} للذبيحة',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            ]),
          ),
          if (onQty != null)
            Container(
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    color: Colors.white,
                    onPressed: qty! > 1 ? () => onQty!(qty! - 1) : null,
                    icon: const Icon(Icons.remove)),
                Text('$qty',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                IconButton(
                    color: Colors.white,
                    onPressed: () => onQty!(qty! + 1),
                    icon: const Icon(Icons.add)),
              ]),
            )
          else if (qty != null)
            Text('× $qty',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
        ]),
      );
}

// ---------------------------------------------------------------- order page

/// Buy: product info, cutting, packing, slaughter and delivery times, address, payment and invoice on one page.
/// Reserve: slaughter and delivery times, then the payment page.
class OrderPage extends StatefulWidget {
  const OrderPage(
      {super.key,
      required this.store,
      required this.product,
      required this.colors,
      required this.kind,
      this.offer});
  final Map<String, dynamic> store;
  final Map<String, dynamic> product;
  final Map<String, dynamic>? offer;
  final List<Color> colors;
  final String kind;
  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  late final d = OrderDraft(widget.kind);
  late final Future<OrderSetup> setup = loadOrderSetup();

  @override
  Widget build(BuildContext context) {
    final cs = widget.colors;
    final purchase = d.purchase;
    return Scaffold(
      appBar: GradientAppBar(
          title: Text(purchase
              ? 'شراء ${widget.product['name']}'
              : 'حجز ${widget.product['name']}')),
      body: FutureBuilder<OrderSetup>(
        future: setup,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(errText(snap.error!)));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final today = DateTime.now();
          final first = DateTime(today.year, today.month, today.day)
              .add(const Duration(days: 1));
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _ProductBanner(
                    store: widget.store,
                    product: widget.product,
                    colors: cs,
                    kind: d.kind,
                    unit: toNum(widget.product['price']),
                    qty: d.qty,
                    onQty: (v) => setState(() => d.qty = v)),
                if (purchase && '${widget.product['description'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Section(
                    icon: Icons.info_outline,
                    title: 'معلومات المنتج',
                    colors: cs,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('${widget.product['description']}',
                              style: const TextStyle(height: 1.6)),
                          const SizedBox(height: 6),
                          Text(
                              'التصنيف: ${widget.product['category'] ?? ''} · ذبح شرعي في ${widget.store['name']}',
                              style: const TextStyle(
                                  fontSize: 12.5, color: Colors.black54)),
                        ]),
                  ),
                ],
                if (purchase) ...[
                  const SizedBox(height: 12),
                  _Section(
                    icon: Icons.content_cut,
                    title: 'طريقة التقطيع والتغليف',
                    colors: cs,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _wrap([
                            for (var i = 0; i < cuttingOptions.length; i++)
                              _Choice(
                                  label: cuttingOptions[i],
                                  icon: cuttingIcons[i],
                                  width: 104,
                                  colors: cs,
                                  selected: d.cutting == cuttingOptions[i],
                                  onTap: () => setState(
                                      () => d.cutting = cuttingOptions[i])),
                          ]),
                          const SizedBox(height: 14),
                          const Text('التغليف',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _wrap([
                            for (final v in packingOptions)
                              _Choice(
                                  label: v,
                                  colors: cs,
                                  selected: d.packing == v,
                                  onTap: () => setState(() => d.packing = v)),
                          ]),
                          const SizedBox(height: 6),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              activeTrackColor: cs.first,
                              value: d.keepHead,
                              onChanged: (v) => setState(() => d.keepHead = v),
                              title: const Text('أبي الرأس والكوارع')),
                        ]),
                  ),
                ],
                const SizedBox(height: 12),
                _Section(
                  icon: Icons.schedule,
                  title: 'موعد الذبح',
                  colors: cs,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 66,
                          child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final day in _days(first, 7))
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                        end: 8),
                                    child: _Choice(
                                        sub: _weekdays[day.weekday - 1],
                                        label: '${day.day}/${day.month}',
                                        width: 78,
                                        colors: cs,
                                        selected: d.slaughterDay == day,
                                        onTap: () => setState(() {
                                              d.slaughterDay = day;
                                              if (d.deliveryDay.isBefore(day)) {
                                                d.deliveryDay = day;
                                              }
                                            })),
                                  ),
                              ]),
                        ),
                        const SizedBox(height: 10),
                        _wrap([
                          for (final v in slaughterTimes)
                            _Choice(
                                label: v,
                                colors: cs,
                                selected: d.slaughterTime == v,
                                onTap: () =>
                                    setState(() => d.slaughterTime = v)),
                        ]),
                      ]),
                ),
                const SizedBox(height: 12),
                _Section(
                  icon: Icons.local_shipping_outlined,
                  title: purchase ? 'موعد التسليم' : 'موعد التوصيل',
                  colors: cs,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _wrap([
                          for (final day in _days(d.slaughterDay, 3))
                            _Choice(
                                sub: _weekdays[day.weekday - 1],
                                label: '${day.day}/${day.month}',
                                width: 78,
                                colors: cs,
                                selected: d.deliveryDay == day,
                                onTap: () =>
                                    setState(() => d.deliveryDay = day)),
                        ]),
                        const SizedBox(height: 10),
                        _wrap([
                          for (final v in deliverySlots)
                            _Choice(
                                label: v,
                                colors: cs,
                                selected: d.slot == v,
                                onTap: () => setState(() => d.slot = v)),
                        ]),
                      ]),
                ),
                const SizedBox(height: 12),
                if (purchase)
                  CheckoutSections(
                      draft: d,
                      setup: snap.data!,
                      store: widget.store,
                      product: widget.product,
                      offer: widget.offer,
                      colors: cs,
                      onChanged: () => setState(() {}))
                else ...[
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: cs.first,
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CheckoutPage(
                                draft: d,
                                setup: snap.data!,
                                store: widget.store,
                                product: widget.product,
                                offer: widget.offer,
                                colors: cs))),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('متابعة للدفع'),
                  ),
                  const SizedBox(height: 24),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- payment page (reservation)

class CheckoutPage extends StatefulWidget {
  const CheckoutPage(
      {super.key,
      required this.draft,
      required this.setup,
      required this.store,
      required this.product,
      required this.colors,
      this.offer});
  final OrderDraft draft;
  final OrderSetup setup;
  final Map<String, dynamic> store;
  final Map<String, dynamic> product;
  final Map<String, dynamic>? offer;
  final List<Color> colors;
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final cs = widget.colors;
    return Scaffold(
      appBar: const GradientAppBar(title: Text('الدفع وتأكيد الحجز')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            _ProductBanner(
                store: widget.store,
                product: widget.product,
                colors: cs,
                kind: d.kind,
                unit: toNum(widget.product['price']),
                qty: d.qty),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(
                      child: _when(Icons.schedule, 'الذبح',
                          '${_weekdays[d.slaughterDay.weekday - 1]} ${d.slaughterDay.day}/${d.slaughterDay.month} · ${d.slaughterTime}',
                          cs)),
                  Container(width: 1, height: 40, color: Colors.black12),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _when(Icons.local_shipping_outlined, 'التوصيل',
                          '${_weekdays[d.deliveryDay.weekday - 1]} ${d.deliveryDay.day}/${d.deliveryDay.month} · ${d.slot}',
                          cs)),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('تعديل')),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            CheckoutSections(
                draft: d,
                setup: widget.setup,
                store: widget.store,
                product: widget.product,
                offer: widget.offer,
                colors: cs,
                onChanged: () => setState(() {})),
          ]),
        ),
      ),
    );
  }

  Widget _when(IconData i, String k, String v, List<Color> cs) =>
      Row(children: [
        Icon(i, color: cs.first),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Text(v,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ]);
}

// ---------------------------------------------------------------- address, payment, invoice, confirm

class CheckoutSections extends StatefulWidget {
  const CheckoutSections(
      {super.key,
      required this.draft,
      required this.setup,
      required this.store,
      required this.product,
      required this.colors,
      required this.onChanged,
      this.offer});
  final OrderDraft draft;
  final OrderSetup setup;
  final Map<String, dynamic> store;
  final Map<String, dynamic> product;
  final Map<String, dynamic>? offer;
  final List<Color> colors;
  final VoidCallback onChanged;
  @override
  State<CheckoutSections> createState() => _CheckoutSectionsState();
}

class _CheckoutSectionsState extends State<CheckoutSections> {
  bool busy = false;

  OrderDraft get d => widget.draft;

  void changed() {
    setState(() {});
    widget.onChanged();
  }

  Future<void> submit(List<Map<String, dynamic>> zones) async {
    if (d.zoneId == null) {
      return toast(context, 'اختر منطقة التوصيل', error: true);
    }
    if (d.block.text.trim().isEmpty ||
        d.road.text.trim().isEmpty ||
        d.house.text.trim().isEmpty) {
      return toast(context, 'أكمل العنوان: المنزل والطريق والمجمع',
          error: true);
    }
    if (d.payment == 'bank_transfer' && d.receipt == null) {
      return toast(context, 'أرفق إيصال التحويل', error: true);
    }
    final zone = zones.firstWhere((z) => z['id'] == d.zoneId);
    final address =
        'مبنى ${d.house.text.trim()}، طريق ${d.road.text.trim()}، مجمع ${d.block.text.trim()}، ${zone['name']}'
        '${d.note.text.trim().isEmpty ? '' : ' · ${d.note.text.trim()}'}';
    setState(() => busy = true);
    final order = await guard(context, () async {
      final o = await sb.rpc('place_order', params: {
        'p_merchant': widget.store['id'],
        'p_items': [
          {
            'product_id': widget.product['id'],
            'qty': d.qty,
            'options': d.options,
          }
        ],
        'p_slaughter_date': isoDate(d.slaughterDay),
        'p_slaughter_time': d.slaughterTime,
        'p_delivery_date': isoDate(d.deliveryDay),
        'p_delivery_slot': d.slot,
        'p_zone': d.zoneId,
        'p_address': address,
        'p_payment': d.payment,
        'p_notes': null,
      });
      if (d.receipt != null && d.receipt!.bytes != null) {
        final safe = d.receipt!.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        final path = '$myId/receipt-${o['id']}-$safe';
        await sb.storage.from('docs').uploadBinary(path, d.receipt!.bytes!);
        await sb.rpc('attach_receipt',
            params: {'p_order': o['id'], 'p_path': path});
      }
      final row = {
        'user_id': myId,
        'house': d.house.text.trim(),
        'road': d.road.text.trim(),
        'block': d.block.text.trim(),
        'area': zone['name'],
        'note': d.note.text.trim(),
      };
      final saved = widget.setup.$3;
      final same = saved.isNotEmpty &&
          saved.first['house'] == row['house'] &&
          saved.first['road'] == row['road'] &&
          saved.first['block'] == row['block'] &&
          saved.first['area'] == row['area'];
      // Keep the saved address (with its city, flat and map pin) when unchanged.
      if (same) {
        await sb.from('customer_addresses')
            .update({'note': row['note']}).eq('id', saved.first['id']);
      } else {
        await sb.from('customer_addresses').insert(row);
      }
      return o;
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (order != null) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OrderDetailsPage(
                  orderId: order['id'], viewer: 'customer', justPlaced: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (settings, zones, addresses, profile) = widget.setup;
    final cs = widget.colors;
    if (!d.prefilled) {
      d.prefilled = true;
      if (addresses.isNotEmpty) {
        final a = addresses.first;
        d.house.text = a['house'] ?? '';
        d.road.text = a['road'] ?? '';
        d.block.text = a['block'] ?? '';
        d.note.text = a['note'] ?? '';
        d.zoneId ??= zones
            .where((z) => z['name'] == a['area'])
            .map((z) => z['id'] as String)
            .firstOrNull;
      }
    }
    final price = toNum(widget.product['price']);
    final sub = price * d.qty;
    final disc = offerValue(widget.offer, price) * d.qty;
    final custComm = calcValue(
        sub - disc,
        settings['customer_comm_type'],
        toNum(settings['customer_comm_value']),
        settings['customer_comm_enabled'] == true);
    final zone = zones.where((z) => z['id'] == d.zoneId).firstOrNull;
    final fee = zone == null ? 0 : toNum(zone['fee']);
    final total = sub - disc + custComm + fee;

    Widget line(String k, String v, {bool bold = false, Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
                child: Text(k,
                    style: TextStyle(
                        color: bold ? Colors.black87 : Colors.black54,
                        fontWeight: bold ? FontWeight.w700 : null))),
            Text(v,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    fontSize: bold ? 18 : 14,
                    color: color)),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Section(
        icon: Icons.place_outlined,
        title: 'عنوان التوصيل',
        colors: cs,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(
            initialValue: d.zoneId,
            decoration: const InputDecoration(labelText: 'المنطقة *'),
            items: [
              for (final z in zones)
                DropdownMenuItem(
                    value: z['id'] as String,
                    child: Text('${z['name']} · توصيل ${bhd(z['fee'])}'))
            ],
            onChanged: (v) {
              d.zoneId = v;
              changed();
            },
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: Field('المبنى', d.house,
                    required: true, keyboard: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(
                child: Field('الطريق', d.road,
                    required: true, keyboard: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(
                child: Field('المجمع', d.block,
                    required: true, keyboard: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          Field('وصف إضافي', d.note, hint: 'اختياري، مثل: بجانب المسجد'),
        ]),
      ),
      const SizedBox(height: 12),
      _Section(
        icon: Icons.account_balance_wallet_outlined,
        title: 'طريقة الدفع',
        colors: cs,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 480 ? 3 : 1;
            final w = (c.maxWidth - 8 * (cols - 1)) / cols;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in paymentLabels.entries)
                SizedBox(
                  width: w,
                  child: _PayTile(
                    title: m.value,
                    sub: paymentLook[m.key]?.$2 ?? '',
                    icon: paymentLook[m.key]?.$1 ?? Icons.payments_outlined,
                    colors: cs,
                    selected: d.payment == m.key,
                    onTap: () {
                      d.payment = m.key;
                      changed();
                    },
                  ),
                ),
            ]);
          }),
          if (d.payment == 'bank_transfer') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: cs.first.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('حوّل المبلغ إلى حساب المنصة',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    SelectableText(
                        '${settings['platform_iban'] ?? 'يُضاف من الإدارة'}',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: Icon(d.receipt == null
                          ? Icons.cloud_upload_outlined
                          : Icons.task_alt),
                      label: Text(d.receipt?.name ?? 'إرفاق إيصال التحويل'),
                      onPressed: () async {
                        final r = await FilePicker.platform.pickFiles(
                            withData: true,
                            type: FileType.custom,
                            allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']);
                        if (r != null) {
                          d.receipt = r.files.first;
                          changed();
                        }
                      },
                    ),
                  ]),
            ),
          ],
          if (d.payment == 'benefitpay')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'في نسخة الاختبار يُسجّل الطلب بانتظار الدفع، والربط الفعلي مع BenefitPay لاحقاً.',
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: cs)),
            child: Row(children: [
              const Icon(Icons.receipt_long_outlined, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('بيانات الفاتورة',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              Text(isoDate(DateTime.now()),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  line('العميل',
                      '${profile?['full_name'] ?? ''} · ${profile?['phone'] ?? ''}'),
                  line('الملحمة', '${widget.store['name']}'),
                  line('نوع الطلب', orderKindLabels[d.kind]!),
                  if (d.purchase)
                    line('التقطيع والتغليف',
                        '${d.cutting} · ${d.packing}${d.keepHead ? ' · مع الرأس' : ''}'),
                  line('الدفع', paymentLabels[d.payment] ?? d.payment),
                  const Divider(height: 20),
                  line('${widget.product['name']} × ${d.qty}', bhd(sub)),
                  if (disc > 0)
                    line('الخصم', '- ${bhd(disc)}', color: G.emerald.first),
                  if (custComm > 0) line('رسوم الخدمة', bhd(custComm)),
                  line('التوصيل${zone == null ? '' : ' (${zone['name']})'}',
                      zone == null ? 'اختر المنطقة' : bhd(fee)),
                  const Divider(height: 20),
                  line('الإجمالي', bhd(total), bold: true, color: cs.first),
                  const SizedBox(height: 4),
                  const Text('المبلغ النهائي يُحسب عند تأكيد الطلب.',
                      style: TextStyle(fontSize: 12, color: Colors.black45)),
                ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        style: FilledButton.styleFrom(
            backgroundColor: cs.first,
            padding: const EdgeInsets.symmetric(vertical: 16)),
        onPressed: busy ? null : () => submit(zones),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.verified_outlined),
        label: Text(busy
            ? 'جارٍ الإرسال…'
            : '${d.purchase ? 'تأكيد الشراء' : 'تأكيد الحجز'} · ${bhd(total)}'),
      ),
      const SizedBox(height: 24),
    ]);
  }
}

class _PayTile extends StatelessWidget {
  const _PayTile(
      {required this.title,
      required this.sub,
      required this.icon,
      required this.colors,
      required this.selected,
      required this.onTap});
  final String title;
  final String sub;
  final IconData icon;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected
                ? LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: colors)
                : null,
            color: selected ? null : const Color(0xFFF8F6F5),
            border: Border.all(
                color: selected
                    ? Colors.transparent
                    : colors.first.withValues(alpha: .18)),
          ),
          child: Row(children: [
            Icon(icon, color: selected ? Colors.white : colors.first),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : Colors.black87)),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: selected ? Colors.white70 : Colors.black45)),
                  ]),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20, color: selected ? Colors.white : colors.first),
          ]),
        ),
      );
}
