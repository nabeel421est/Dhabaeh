import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/common.dart';
import '../customer/order_details.dart';

int gridCols(double w, double cell, {int min = 1, int max = 4}) =>
    (w / cell).floor().clamp(min, max);

// ---------------------------------------------------------------- orders

class MerchantOrders extends StatefulWidget {
  const MerchantOrders({super.key, required this.mid});
  final String mid;
  @override
  State<MerchantOrders> createState() => _MerchantOrdersState();
}

class _MerchantOrdersState extends State<MerchantOrders> {
  String filter = 'open';
  String search = '';

  static bool isOpen(Map o) => !['delivered', 'cancelled'].contains(o['status']);

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['orders'],
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('orders')
          .select('*, order_items(name, qty)')
          .eq('merchant_id', widget.mid)
          .order('slaughter_date')
          .order('created_at', ascending: false)),
      builder: (context, orders, _) {
        final b = brandOf(context);
        final today = isoDate(DateTime.now());
        final q = search.trim();
        final shown = orders.where((o) {
          if (filter == 'open' && !isOpen(o)) return false;
          if (filter != 'open' && filter != 'all' && o['status'] != filter) {
            return false;
          }
          if (q.isEmpty) return true;
          return '${o['code']}'.contains(q) ||
              '${o['customer_name'] ?? ''}'.contains(q) ||
              (o['order_items'] as List? ?? [])
                  .any((x) => '${x['name']}'.contains(q));
        }).toList();
        final delivered = orders.where((o) => o['status'] == 'delivered');
        final filters = <String, String>{
          'open': 'الجارية',
          ...statusLabels,
          'all': 'الكل'
        };
        return ListView(padding: const EdgeInsets.all(16), children: [
          PageHero(
            icon: Icons.receipt_long_outlined,
            title: 'الطلبات',
            subtitle: 'كل حجوزات متجرك، مرتبة حسب موعد الذبح',
            stats: [
              ('جارية', '${orders.where(isOpen).length}'),
              (
                'ذبح اليوم',
                '${orders.where((o) => o['slaughter_date'] == today && isOpen(o)).length}'
              ),
              ('مكتملة', '${delivered.length}'),
              (
                'صافي المكتمل',
                bhd(delivered.fold<num>(
                    0, (a, o) => a + toNum(o['merchant_net'])))
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث برقم الطلب أو اسم العميل أو الصنف'),
            onChanged: (v) => setState(() => search = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final f in filters.entries)
                TonePill(
                  label: f.value,
                  count: f.key == 'all'
                      ? orders.length
                      : f.key == 'open'
                          ? orders.where(isOpen).length
                          : orders.where((o) => o['status'] == f.key).length,
                  colors: f.key == 'open' || f.key == 'all'
                      ? b.stops.sublist(1)
                      : toneOf(statusColor(f.key)),
                  selected: filter == f.key,
                  onTap: () => setState(() => filter = f.key),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            const Empty('لا توجد طلبات هنا', icon: Icons.receipt_long_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = gridCols(c.maxWidth, 330);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final o in shown)
                SizedBox(width: w, child: MerchantOrderTile(o: o)),
            ]);
          }),
        ]);
      },
    );
  }
}

class MerchantOrderTile extends StatelessWidget {
  const MerchantOrderTile({super.key, required this.o});
  final Map<String, dynamic> o;
  @override
  Widget build(BuildContext context) {
    final c = statusColor('${o['status']}');
    final items = (o['order_items'] as List? ?? [])
        .map((x) => '${x['name']} × ${x['qty']}')
        .join('، ');
    final step = statusFlow.indexOf('${o['status']}');
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(icon, size: 16, color: c.withValues(alpha: .75)),
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
                    OrderDetailsPage(orderId: o['id'], viewer: 'merchant'))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: toneOf(c))),
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
                      Text('${o['customer_name'] ?? 'عميل'}',
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
                child: Text(statusLabels[o['status']] ?? '${o['status']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          if (step >= 0)
            LinearProgressIndicator(
                value: (step + 1) / statusFlow.length,
                minHeight: 4,
                color: c,
                backgroundColor: c.withValues(alpha: .1)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(Icons.set_meal_outlined, items.isEmpty ? '-' : items),
                  line(Icons.content_cut,
                      'الذبح ${dateText(o['slaughter_date'])} · ${o['slaughter_time']}'),
                  line(Icons.local_shipping_outlined,
                      'التوصيل ${dateText(o['delivery_date'])} · ${o['delivery_slot']}'),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(paymentLabels[o['payment_method']] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                    const Spacer(),
                    const Text('الصافي ',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(bhd(o['merchant_net']),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: c)),
                  ]),
                ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- products

class MerchantProducts extends StatefulWidget {
  const MerchantProducts(
      {super.key, required this.mid, required this.canPrice});
  final String mid;
  final bool canPrice;
  @override
  State<MerchantProducts> createState() => _MerchantProductsState();
}

class _MerchantProductsState extends State<MerchantProducts> {
  String? cat;
  String search = '';
  static const tones = [G.emerald, G.teal, G.amber, G.sapphire, G.ruby, G.violet, G.gold];

  Future<void> edit(Map<String, dynamic>? p, Future<void> Function() reload) async {
    final name = TextEditingController(text: p?['name'] ?? '');
    final category = TextEditingController(text: p?['category'] ?? 'ذبائح');
    final desc = TextEditingController(text: p?['description'] ?? '');
    final price = TextEditingController(text: p == null ? '' : '${p['price']}');
    final form = GlobalKey<FormState>();
    final b = brandOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              gradient: b.gradient,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22))),
          child: Row(children: [
            Icon(Icons.inventory_2_outlined, color: b.accent),
            const SizedBox(width: 10),
            Text(p == null ? 'منتج جديد' : 'تعديل المنتج',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Field('اسم المنتج', name,
                    required: true, hint: 'مثال: خروف نعيمي'),
                const SizedBox(height: 10),
                Field('التصنيف', category, required: true),
                const SizedBox(height: 10),
                Field('الوصف', desc, hint: 'الوزن التقريبي، العمر…'),
                const SizedBox(height: 10),
                if (widget.canPrice || p == null)
                  Field('السعر (د.ب)', price,
                      required: true,
                      ltr: true,
                      keyboard:
                          const TextInputType.numberWithOptions(decimal: true)),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(c, true);
              },
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final row = {
      'merchant_id': widget.mid,
      'name': name.text.trim(),
      'category': category.text.trim(),
      'description': desc.text.trim(),
      if (widget.canPrice || p == null)
        'price': num.tryParse(price.text.trim()) ?? 0,
    };
    await guard(context, () async {
      if (p == null) {
        await sb.from('products').insert(row);
      } else {
        await sb.from('products').update(row).eq('id', p['id']);
      }
    }, ok: 'تم الحفظ');
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['products'],
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('products')
          .select()
          .eq('merchant_id', widget.mid)
          .order('created_at')),
      builder: (context, list, reload) {
        final b = brandOf(context);
        final cats = <String>{for (final p in list) '${p['category'] ?? ''}'}
            .toList();
        List<Color> toneFor(String c) {
          final i = cats.indexOf(c);
          return tones[(i < 0 ? 0 : i) % tones.length];
        }

        final q = search.trim();
        final shown = list.where((p) {
          if (cat != null && p['category'] != cat) return false;
          if (q.isEmpty) return true;
          return '${p['name']}'.contains(q) ||
              '${p['description'] ?? ''}'.contains(q);
        }).toList();
        final prices = list.map((p) => toNum(p['price'])).toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          PageHero(
            icon: Icons.inventory_2_outlined,
            title: 'المنتجات',
            subtitle: 'أصناف متجرك وأسعارها، وتقدر توقف أي صنف مؤقتاً',
            stats: [
              ('الأصناف', '${list.length}'),
              ('متاح', '${list.where((p) => p['available'] == true).length}'),
              ('التصنيفات', '${cats.length}'),
              if (prices.isNotEmpty)
                (
                  'الأسعار',
                  '${bhd(prices.reduce((a, c) => a < c ? a : c))} - ${bhd(prices.reduce((a, c) => a > c ? a : c))}'
                ),
            ],
            action: HeroButton(
                icon: Icons.add,
                label: 'منتج جديد',
                onPressed: () => edit(null, reload)),
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث عن صنف، مثل: نعيمي'),
            onChanged: (v) => setState(() => search = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              TonePill(
                  label: 'الكل',
                  count: list.length,
                  colors: b.stops.sublist(1),
                  selected: cat == null,
                  onTap: () => setState(() => cat = null)),
              for (final c in cats)
                TonePill(
                    label: c,
                    count: list.where((p) => p['category'] == c).length,
                    colors: toneFor(c),
                    selected: cat == c,
                    onTap: () => setState(() => cat = c)),
            ]),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            Empty(list.isEmpty ? 'أضف أول منتج لمتجرك' : 'لا توجد أصناف تطابق البحث',
                icon: Icons.inventory_2_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 230).floor().clamp(2, 6);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 286),
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final p = shown[i];
                return _ProductCard(
                  p: p,
                  colors: toneFor('${p['category'] ?? ''}'),
                  onEdit: () => edit(p, reload),
                  onToggle: (v) async {
                    await guard(
                        context,
                        () => sb
                            .from('products')
                            .update({'available': v}).eq('id', p['id']));
                    await reload();
                  },
                  onDelete: () async {
                    final yes = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                              title: Text('حذف ${p['name']}؟'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('إلغاء')),
                                FilledButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('حذف')),
                              ],
                            ));
                    if (yes != true || !context.mounted) return;
                    await guard(
                        context,
                        () => sb.from('products').delete().eq('id', p['id']),
                        ok: 'تم حذف المنتج');
                    await reload();
                  },
                );
              },
            );
          }),
        ]);
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard(
      {required this.p,
      required this.colors,
      required this.onEdit,
      required this.onToggle,
      required this.onDelete});
  final Map<String, dynamic> p;
  final List<Color> colors;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final img = p['image_url'];
    final on = p['available'] == true;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 120,
            child: Stack(fit: StackFit.expand, children: [
              Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                          colors: on
                              ? colors
                              : [Colors.blueGrey.shade400, Colors.blueGrey.shade200]))),
              if (img is String && img.isNotEmpty)
                Image.network(img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox())
              else ...[
                PositionedDirectional(
                    end: -20,
                    top: -20,
                    child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .1)))),
                Center(
                    child: Icon(Icons.set_meal_outlined,
                        size: 52, color: Colors.white.withValues(alpha: .92))),
              ],
              PositionedDirectional(
                top: 8,
                start: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .22),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('${p['category'] ?? ''}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              if (!on)
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999)),
                    child: const Text('موقوف',
                        style: TextStyle(
                            color: Color(0xFFB83250),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    if ('${p['description'] ?? ''}'.isNotEmpty)
                      Text('${p['description']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54, height: 1.4)),
                    const Spacer(),
                    Text(bhd(p['price']),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: colors.first)),
                    Row(children: [
                      Transform.scale(
                          scale: .8,
                          alignment: AlignmentDirectional.centerStart,
                          child: Switch(
                              value: on,
                              activeTrackColor: colors.first,
                              onChanged: onToggle)),
                      Text(on ? 'متاح' : 'موقوف',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      const Spacer(),
                      IconButton(
                          tooltip: 'حذف',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: onDelete),
                    ]),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- offers

class MerchantOffers extends StatelessWidget {
  const MerchantOffers({super.key, required this.mid});
  final String mid;
  static const tones = [G.ruby, G.amber, G.violet, G.sapphire, G.emerald, G.teal];

  Future<void> add(BuildContext context, List<Map<String, dynamic>> products,
      Future<void> Function() reload) async {
    final title = TextEditingController();
    final value = TextEditingController();
    String? productId = products.isEmpty ? null : products.first['id'];
    String type = 'fixed';
    DateTime? ends;
    final b = brandOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
                gradient: LinearGradient(colors: G.ruby),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            child: Row(children: [
              Icon(Icons.local_offer_outlined, color: b.accent),
              const SizedBox(width: 10),
              const Text('عرض جديد',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Field('عنوان العرض', title,
                    required: true, hint: 'مثال: خصم 5 دنانير على النعيمي'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: productId,
                  decoration: const InputDecoration(labelText: 'المنتج'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('كل المنتجات')),
                    for (final p in products)
                      DropdownMenuItem<String?>(
                          value: p['id'] as String, child: Text(p['name']))
                  ],
                  onChanged: (v) => set(() => productId = v),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'fixed', label: Text('مبلغ ثابت')),
                    ButtonSegment(value: 'percent', label: Text('نسبة %'))
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => set(() => type = s.first),
                ),
                const SizedBox(height: 10),
                Field('قيمة الخصم', value,
                    required: true,
                    ltr: true,
                    keyboard:
                        const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_outlined),
                  onPressed: () async {
                    final d = await showDatePicker(
                        context: c,
                        initialDate:
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) set(() => ends = d);
                  },
                  label: Text(ends == null
                      ? 'تاريخ انتهاء العرض (اختياري)'
                      : 'ينتهي ${dateText(isoDate(ends!))}'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('نشر العرض')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted || title.text.trim().isEmpty) return;
    await guard(
        context,
        () => sb.from('offers').insert({
              'merchant_id': mid,
              'product_id': productId,
              'title': title.text.trim(),
              'discount_type': type,
              'discount_value': num.tryParse(value.text.trim()) ?? 0,
              if (ends != null) 'ends_on': isoDate(ends!),
            }),
        ok: 'تم نشر العرض');
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Loader<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
      realtimeTables: const ['offers'],
      load: () async {
        final o = await sb
            .from('offers')
            .select('*, products(name, price)')
            .eq('merchant_id', mid)
            .order('created_at', ascending: false);
        final p =
            await sb.from('products').select('id, name').eq('merchant_id', mid);
        return (
          List<Map<String, dynamic>>.from(o),
          List<Map<String, dynamic>>.from(p)
        );
      },
      builder: (context, data, reload) {
        final (offers, products) = data;
        final active = offers.where((o) => o['active'] == true).length;
        return ListView(padding: const EdgeInsets.all(16), children: [
          PageHero(
            icon: Icons.local_offer_outlined,
            title: 'العروض',
            subtitle: 'خصومات تظهر للعملاء على أصنافك',
            stats: [
              ('العروض', '${offers.length}'),
              ('مفعّلة', '$active'),
              ('موقوفة', '${offers.length - active}'),
            ],
            action: HeroButton(
                icon: Icons.add,
                label: 'عرض جديد',
                onPressed: () => add(context, products, reload)),
          ),
          const SizedBox(height: 16),
          if (offers.isEmpty)
            const Empty('لا توجد عروض، أضف أول عرض لجذب العملاء',
                icon: Icons.local_offer_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = gridCols(c.maxWidth, 320);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (var i = 0; i < offers.length; i++)
                SizedBox(
                  width: w,
                  child: _OfferCard(
                    o: offers[i],
                    colors: tones[i % tones.length],
                    onToggle: (v) async {
                      await guard(
                          context,
                          () => sb
                              .from('offers')
                              .update({'active': v}).eq('id', offers[i]['id']));
                      await reload();
                    },
                  ),
                ),
            ]);
          }),
        ]);
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard(
      {required this.o, required this.colors, required this.onToggle});
  final Map<String, dynamic> o;
  final List<Color> colors;
  final ValueChanged<bool> onToggle;
  @override
  Widget build(BuildContext context) {
    final on = o['active'] == true;
    final pct = o['discount_type'] == 'percent';
    final cs = on ? colors : [Colors.blueGrey.shade500, Colors.blueGrey.shade300];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: cs),
        boxShadow: [
          BoxShadow(
              color: cs.first.withValues(alpha: .25),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        PositionedDirectional(
            end: -30,
            top: -30,
            child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .1)))),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .35))),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                    pct
                        ? '${toNum(o['discount_value']).toStringAsFixed(0)}%'
                        : toNum(o['discount_value']).toStringAsFixed(
                            toNum(o['discount_value']) % 1 == 0 ? 0 : 3),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                Text(pct ? 'خصم' : 'د.ب خصم',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${o['title']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(o['products']?['name'] ?? 'كل المنتجات',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12.5)),
                    if (o['ends_on'] != null)
                      Text('حتى ${dateText(o['ends_on'])}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(on ? 'مفعّل' : 'موقوف',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Switch(
                          value: on,
                          activeThumbColor: colors.first,
                          activeTrackColor: Colors.white,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.white.withValues(alpha: .25),
                          onChanged: onToggle),
                    ]),
                  ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
