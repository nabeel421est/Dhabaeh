import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/common.dart';
import '../core/i18n.dart';
import '../core/ttext.dart';

/// Blue-family tones for offer cards, so the page stays in the admin identity.
const offerTones = [G.sapphire, G.sky, G.teal, G.midnight, G.violet];

/// Every store's offers in one place: filter by store and state, add an offer for
/// any store, edit, switch on or off, or remove it.
class AdminOffers extends StatefulWidget {
  const AdminOffers({super.key});
  @override
  State<AdminOffers> createState() => _AdminOffersState();
}

typedef _OffersData = (
  List<Map<String, dynamic>> offers,
  List<Map<String, dynamic>> stores,
  List<Map<String, dynamic>> products,
);

class _AdminOffersState extends State<AdminOffers> {
  String store = 'all';
  String state = 'all';
  final q = TextEditingController();

  static String stateOf(Map o) {
    final ends = DateTime.tryParse('${o['ends_on'] ?? ''}');
    final today = DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day);
    if (ends != null && ends.isBefore(d0)) return 'expired';
    if (o['active'] != true) return 'off';
    if (ends != null && ends.difference(d0).inDays <= 3) return 'soon';
    return 'on';
  }

  static const stateLabels = {
    'all': 'الكل',
    'on': 'مفعّلة',
    'soon': 'تنتهي قريباً',
    'off': 'موقوفة',
    'expired': 'منتهية',
  };
  static const stateIcons = <String, IconData>{
    'all': Icons.apps_outlined,
    'on': Icons.bolt_outlined,
    'soon': Icons.timer_outlined,
    'off': Icons.pause_circle_outline,
    'expired': Icons.history_outlined,
  };
  static const stateTones = {
    'all': G.sapphire,
    'on': G.emerald,
    'soon': G.amber,
    'off': G.midnight,
    'expired': G.ruby,
  };

  Future<_OffersData> load() async {
    final o = await sb
        .from('offers')
        .select('*, products(name, price), merchants(name)')
        .order('created_at', ascending: false);
    final m =
        await sb.from('merchants').select('id, name, suspended').order('name');
    final p = await sb
        .from('products')
        .select('id, name, price, merchant_id')
        .order('name');
    return (
      List<Map<String, dynamic>>.from(o),
      List<Map<String, dynamic>>.from(m),
      List<Map<String, dynamic>>.from(p),
    );
  }

  Future<void> edit(
      BuildContext context, _OffersData data, Future<void> Function() reload,
      {Map<String, dynamic>? o}) async {
    final (_, stores, products) = data;
    if (stores.isEmpty) {
      toast(context, 'أضف متجراً أولاً', error: true);
      return;
    }
    String mid =
        o?['merchant_id'] ?? (store != 'all' ? store : stores.first['id']);
    String? pid = o?['product_id'];
    String type = o?['discount_type'] ?? 'percent';
    bool active = o?['active'] ?? true;
    DateTime? ends = DateTime.tryParse('${o?['ends_on'] ?? ''}');
    final title = TextEditingController(text: o?['title'] ?? '');
    final value = TextEditingController(
        text: o == null ? '' : '${toNum(o['discount_value'])}');
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) {
          final mine = products.where((p) => p['merchant_id'] == mid).toList();
          if (pid != null && !mine.any((p) => p['id'] == pid)) pid = null;
          return AlertDialog(
            title: Row(children: [
              const GradientBadge(
                  colors: G.sapphire,
                  icon: Icons.local_offer_outlined,
                  size: 38),
              const SizedBox(width: 10),
              Text(o == null ? 'عرض جديد' : 'تعديل العرض'),
            ]),
            content: SizedBox(
              width: 440,
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                      initialValue: mid,
                      decoration: InputDecoration(labelText: tr('المتجر')),
                      items: [
                        for (final m in stores)
                          DropdownMenuItem(
                              value: m['id'] as String,
                              child: Text('${m['name']}')),
                      ],
                      onChanged: (v) => set(() {
                        mid = v!;
                        pid = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    Field('عنوان العرض', title, required: true),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      key: ValueKey(mid),
                      initialValue: pid,
                      decoration: InputDecoration(labelText: tr('المنتج')),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('كل المنتجات')),
                        for (final p in mine)
                          DropdownMenuItem<String?>(
                              value: p['id'] as String,
                              child: Text('${p['name']} · ${bhd(p['price'])}')),
                      ],
                      onChanged: (v) => set(() => pid = v),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'percent', label: Text('نسبة %')),
                        ButtonSegment(value: 'fixed', label: Text('مبلغ ثابت')),
                      ],
                      selected: {type},
                      onSelectionChanged: (s) => set(() => type = s.first),
                    ),
                    const SizedBox(height: 10),
                    Field('قيمة الخصم', value,
                        required: true,
                        ltr: true,
                        keyboard: const TextInputType.numberWithOptions(
                            decimal: true)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event_outlined),
                          onPressed: () async {
                            final d = await showDatePicker(
                                context: c,
                                initialDate: ends ??
                                    DateTime.now().add(const Duration(days: 7)),
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 365)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 730)));
                            if (d != null) set(() => ends = d);
                          },
                          label: Text(ends == null
                              ? 'تاريخ الانتهاء (اختياري)'
                              : '${tr('ينتهي')} ${dateText(isoDate(ends!))}'),
                        ),
                      ),
                      if (ends != null)
                        IconButton(
                            tooltip: tr('بدون تاريخ انتهاء'),
                            onPressed: () => set(() => ends = null),
                            icon: const Icon(Icons.close)),
                    ]),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: active,
                      onChanged: (v) => set(() => active = v),
                      title: const Text('العرض مفعّل'),
                    ),
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
                  child: Text(o == null ? 'نشر العرض' : 'حفظ')),
            ],
          );
        },
      ),
    );
    if (ok != true || !context.mounted) return;
    final row = {
      'merchant_id': mid,
      'product_id': pid,
      'title': title.text.trim(),
      'discount_type': type,
      'discount_value': num.tryParse(value.text.trim()) ?? 0,
      'ends_on': ends == null ? null : isoDate(ends!),
      'active': active,
    };
    await guard(
        context,
        () => o == null
            ? sb.from('offers').insert(row)
            : sb.from('offers').update(row).eq('id', o['id']),
        ok: o == null ? 'تم نشر العرض' : 'تم حفظ العرض');
    await reload();
  }

  Future<void> remove(BuildContext context, Map<String, dynamic> o,
      Future<void> Function() reload) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف العرض؟'),
        content: Text('«${o['title']}» · ${o['merchants']?['name'] ?? ''}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: G.ruby.first),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await guard(context, () => sb.from('offers').delete().eq('id', o['id']),
        ok: 'تم حذف العرض');
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Loader<_OffersData>(
      realtimeTables: const ['offers'],
      load: load,
      builder: (context, data, reload) {
        final (offers, stores, _) = data;
        final counts = <String, int>{'all': offers.length};
        for (final o in offers) {
          final s = stateOf(o);
          counts[s] = (counts[s] ?? 0) + 1;
        }
        final text = q.text.trim().toLowerCase();
        final list = offers.where((o) {
          if (store != 'all' && o['merchant_id'] != store) return false;
          if (state != 'all' && stateOf(o) != state) return false;
          if (text.isEmpty) return true;
          return '${o['title']} ${o['merchants']?['name']} ${o['products']?['name']}'
              .toLowerCase()
              .contains(text);
        }).toList();
        final storesWith = {for (final o in offers) o['merchant_id']};
        return ListView(padding: const EdgeInsets.all(16), children: [
          PageHero(
            icon: Icons.local_offer_outlined,
            title: 'العروض',
            subtitle: 'عروض كل الملاحم في مكان واحد: أضف وعدّل وأوقف',
            stats: [
              ('كل العروض', '${offers.length}'),
              ('مفعّلة', '${(counts['on'] ?? 0) + (counts['soon'] ?? 0)}'),
              ('تنتهي قريباً', '${counts['soon'] ?? 0}'),
              ('متاجر لديها عروض', '${storesWith.length}'),
            ],
            action: HeroButton(
                icon: Icons.add,
                label: 'عرض جديد',
                onPressed: () => edit(context, data, reload)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: q,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: tr('ابحث بعنوان العرض أو المتجر أو المنتج'),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final s in stateLabels.keys)
                TonePill(
                  label: stateLabels[s]!,
                  icon: stateIcons[s],
                  colors: stateTones[s]!,
                  selected: state == s,
                  count: counts[s] ?? 0,
                  onTap: () => setState(() => state = s),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              TonePill(
                label: 'كل المتاجر',
                icon: Icons.storefront_outlined,
                colors: G.sapphire,
                selected: store == 'all',
                onTap: () => setState(() => store = 'all'),
              ),
              for (var i = 0; i < stores.length; i++)
                TonePill(
                  label: '${stores[i]['name']}',
                  colors: offerTones[i % offerTones.length],
                  selected: store == stores[i]['id'],
                  count: offers
                      .where((o) => o['merchant_id'] == stores[i]['id'])
                      .length,
                  onTap: () => setState(() => store = stores[i]['id']),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            const Empty('لا توجد عروض بهذا التصنيف',
                icon: Icons.local_offer_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 360).floor().clamp(1, 4);
            final w = (c.maxWidth - 14 * (cols - 1)) / cols;
            final storeIdx = {
              for (var i = 0; i < stores.length; i++) stores[i]['id']: i
            };
            return Wrap(spacing: 14, runSpacing: 14, children: [
              for (final o in list)
                SizedBox(
                  width: w,
                  child: AdminOfferCard(
                    o: o,
                    state: stateOf(o),
                    colors: offerTones[
                        (storeIdx[o['merchant_id']] ?? 0) % offerTones.length],
                    onEdit: () => edit(context, data, reload, o: o),
                    onDelete: () => remove(context, o, reload),
                    onToggle: (v) async {
                      await guard(
                          context,
                          () => sb
                              .from('offers')
                              .update({'active': v}).eq('id', o['id']));
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

class AdminOfferCard extends StatelessWidget {
  const AdminOfferCard(
      {super.key,
      required this.o,
      required this.state,
      required this.colors,
      required this.onEdit,
      required this.onDelete,
      required this.onToggle});
  final Map<String, dynamic> o;
  final String state;
  final List<Color> colors;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final live = state == 'on' || state == 'soon';
    final cs =
        live ? colors : [const Color(0xFF55657A), const Color(0xFF9AA8BA)];
    final pct = o['discount_type'] == 'percent';
    final v = toNum(o['discount_value']);
    final price = toNum(o['products']?['price']);
    final b = brandOf(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: cs),
        border: Border.all(color: b.accent.withValues(alpha: live ? .45 : .15)),
        boxShadow: [
          BoxShadow(
              color: cs.first.withValues(alpha: .28),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        PositionedDirectional(
            end: -40,
            top: -40,
            child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Colors.white.withValues(alpha: .22),
                      Colors.white.withValues(alpha: 0)
                    ])))),
        PositionedDirectional(
            start: -30,
            bottom: -50,
            child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .06)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.storefront_outlined,
                  size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${o['merchants']?['name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ),
              _StateTag(state: state),
            ]),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: .26),
                        Colors.white.withValues(alpha: .1)
                      ]),
                  border: Border.all(color: b.accent.withValues(alpha: .6)),
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                          pct
                              ? '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)}%'
                              : v.toStringAsFixed(v % 1 == 0 ? 0 : 3),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w800)),
                      Text(pct ? 'خصم' : 'د.ب خصم',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(o['products']?['name'] ?? 'كل المنتجات',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                      if (o['products'] != null && price > 0)
                        Text(
                            '${bhd(price)} ← ${bhd(price - (pct ? price * v / 100 : v).clamp(0, price))}',
                            style: TextStyle(
                                color: b.accent,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                      Text(
                          o['ends_on'] == null
                              ? 'بدون تاريخ انتهاء'
                              : '${tr('حتى')} ${dateText(o['ends_on'])}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ]),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Switch(
                  value: o['active'] == true,
                  activeThumbColor: cs.first,
                  activeTrackColor: Colors.white,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: .25),
                  onChanged: onToggle),
              Text(o['active'] == true ? 'مفعّل' : 'موقوف',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                  tooltip: tr('تعديل'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, color: Colors.white)),
              IconButton(
                  tooltip: tr('حذف'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.white)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _StateTag extends StatelessWidget {
  const _StateTag({required this.state});
  final String state;
  @override
  Widget build(BuildContext context) {
    final label = _AdminOffersState.stateLabels[state] ?? '';
    final c = _AdminOffersState.stateTones[state]!.last;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_AdminOffersState.stateIcons[state], size: 13, color: c),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: Color.lerp(c, Colors.black, .35),
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
