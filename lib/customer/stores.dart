import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/common.dart';
import 'booking_page.dart';
import 'customer_shell.dart' show StoreLogo;

/// Store colours: each butcher shop keeps its own gradient everywhere in the customer app.
const storeTones = [G.ruby, G.amber, G.violet, G.sapphire, G.emerald, G.teal, G.gold];

/// The offer that applies to a product (product-specific offers only, as the order is priced).
Map<String, dynamic>? offerFor(List<Map<String, dynamic>> offers, Map p) {
  Map<String, dynamic>? best;
  num bestV = 0;
  for (final o in offers) {
    if (o['product_id'] != p['id'] || o['active'] != true) continue;
    final v = offerValue(o, toNum(p['price']));
    if (v > bestV) {
      bestV = v;
      best = o;
    }
  }
  return best;
}

num offerValue(Map? o, num price) {
  if (o == null) return 0;
  final v = o['discount_type'] == 'percent'
      ? price * toNum(o['discount_value']) / 100
      : toNum(o['discount_value']);
  return v > price ? price : v;
}

// ---------------------------------------------------------------- home: stores + search

class StoresPage extends StatefulWidget {
  const StoresPage({super.key});
  @override
  State<StoresPage> createState() => _StoresPageState();
}

class _StoresPageState extends State<StoresPage> {
  String search = '';
  String? area;

  @override
  Widget build(BuildContext context) {
    return Loader<
        (
          List<Map<String, dynamic>>,
          List<Map<String, dynamic>>,
          List<Map<String, dynamic>>
        )>(
      realtimeTables: const ['merchants', 'products', 'offers'],
      load: () async {
        final m = List<Map<String, dynamic>>.from(await sb
            .from('merchants')
            .select('id, name, logo_url, area, description, is_open')
            .eq('suspended', false)
            .eq('frozen', false)
            .order('name'));
        final p = List<Map<String, dynamic>>.from(await sb
            .from('products')
            .select()
            .eq('available', true)
            .order('price'));
        final o = List<Map<String, dynamic>>.from(
            await sb.from('offers').select().eq('active', true));
        return (m, p, o);
      },
      builder: (context, data, _) {
        final (stores, products, offers) = data;
        final b = brandOf(context);
        final tone = {
          for (var i = 0; i < stores.length; i++)
            stores[i]['id']: storeTones[i % storeTones.length]
        };
        final byId = {for (final m in stores) m['id']: m};
        final areas =
            <String>{for (final m in stores) '${m['area'] ?? ''}'}.toList()
              ..removeWhere((a) => a.isEmpty);
        final q = search.trim();
        bool inArea(Map m) => area == null || m['area'] == area;
        final shownStores = stores.where((m) {
          if (!inArea(m)) return false;
          if (q.isEmpty) return true;
          return '${m['name']}'.contains(q) ||
              '${m['area'] ?? ''}'.contains(q) ||
              '${m['description'] ?? ''}'.contains(q) ||
              products.any((p) =>
                  p['merchant_id'] == m['id'] &&
                  ('${p['name']}'.contains(q) ||
                      '${p['category'] ?? ''}'.contains(q)));
        }).toList();
        final shownProducts = q.isEmpty
            ? <Map<String, dynamic>>[]
            : products.where((p) {
                final m = byId[p['merchant_id']];
                if (m == null || !inArea(m)) return false;
                return '${p['name']}'.contains(q) ||
                    '${p['category'] ?? ''}'.contains(q) ||
                    '${m['name']}'.contains(q) ||
                    '${m['area'] ?? ''}'.contains(q);
              }).toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          PageHero(
            icon: Icons.storefront_outlined,
            title: 'أهلاً بك',
            subtitle: 'اختر الملحمة واطلب ذبيحتك، ونوصلها لباب بيتك',
            stats: [
              ('الملاحم', '${stores.length}'),
              ('الأصناف', '${products.length}'),
              ('المناطق', '${areas.length}'),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث عن ملحمة أو صنف أو منطقة'),
            onChanged: (v) => setState(() => search = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              TonePill(
                  label: 'كل المناطق',
                  icon: Icons.place_outlined,
                  colors: b.stops.sublist(1),
                  selected: area == null,
                  onTap: () => setState(() => area = null)),
              for (final a in areas)
                TonePill(
                    label: a,
                    count: stores.where((m) => m['area'] == a).length,
                    colors: b.stops.sublist(1),
                    selected: area == a,
                    onTap: () => setState(() => area = a)),
            ]),
          ),
          if (shownProducts.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Title(Icons.set_meal_outlined, 'الأصناف المطابقة',
                '${shownProducts.length}'),
            const SizedBox(height: 10),
            ProductGrid(
              products: shownProducts,
              offers: offers,
              toneOf: (p) => tone[p['merchant_id']] ?? storeTones[0],
              storeOf: (p) => byId[p['merchant_id']]!,
              showStore: true,
            ),
          ],
          const SizedBox(height: 16),
          _Title(Icons.storefront_outlined, 'الملاحم', '${shownStores.length}'),
          const SizedBox(height: 10),
          if (shownStores.isEmpty)
            const Empty('لا توجد ملاحم تطابق البحث',
                icon: Icons.storefront_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 300).floor().clamp(2, 5);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 236),
              itemCount: shownStores.length,
              itemBuilder: (context, i) {
                final m = shownStores[i];
                final ps =
                    products.where((p) => p['merchant_id'] == m['id']).toList();
                return _StoreCard(
                  m: m,
                  colors: tone[m['id']]!,
                  count: ps.length,
                  from: ps.isEmpty
                      ? null
                      : ps.map((p) => toNum(p['price'])).reduce(
                          (a, b) => a < b ? a : b),
                  hasOffer: offers.any((o) => o['merchant_id'] == m['id']),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              StorePage(store: m, colors: tone[m['id']]!))),
                );
              },
            );
          }),
        ]);
      },
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.icon, this.text, this.count);
  final IconData icon;
  final String text;
  final String count;
  @override
  Widget build(BuildContext context) {
    final b = brandOf(context);
    return Row(children: [
      GradientBadge(colors: b.stops.sublist(1), icon: icon, size: 32),
      const SizedBox(width: 8),
      Text(text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(width: 6),
      Text(count, style: const TextStyle(color: Colors.black45)),
    ]);
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard(
      {required this.m,
      required this.colors,
      required this.count,
      required this.from,
      required this.hasOffer,
      required this.onTap});
  final Map<String, dynamic> m;
  final List<Color> colors;
  final int count;
  final num? from;
  final bool hasOffer;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final open = m['is_open'] == true;
    final cs = open ? colors : [Colors.blueGrey.shade500, Colors.blueGrey.shade300];
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open ? onTap : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 112,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: cs)),
            child: Stack(children: [
              PositionedDirectional(
                  end: -24,
                  top: -24,
                  child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: .1)))),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: ClipOval(child: StoreLogo(m['logo_url'], size: 58)),
                ),
              ),
              PositionedDirectional(
                top: 8,
                start: 8,
                child: _pill(open ? 'مفتوح' : 'مغلق حالياً',
                    Colors.black.withValues(alpha: .22), Colors.white),
              ),
              if (hasOffer)
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: _pill('عروض', Colors.white, cs.first,
                      icon: Icons.local_offer),
                ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15.5)),
                    Row(children: [
                      Icon(Icons.place_outlined, size: 14, color: cs.first),
                      const SizedBox(width: 3),
                      Text('${m['area'] ?? ''}',
                          style: TextStyle(fontSize: 12, color: cs.first)),
                    ]),
                    if ('${m['description'] ?? ''}'.isNotEmpty)
                      Text('${m['description']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    const Spacer(),
                    Text('$count صنف',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                    if (from != null)
                      Text('يبدأ من ${bhd(from)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: cs.first)),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pill(String t, Color bg, Color fg, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3)
          ],
          Text(t,
              style: TextStyle(
                  color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

// ---------------------------------------------------------------- product grid (shared)

class ProductGrid extends StatelessWidget {
  const ProductGrid(
      {super.key,
      required this.products,
      required this.offers,
      required this.toneOf,
      required this.storeOf,
      this.showStore = false});
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> offers;
  final List<Color> Function(Map p) toneOf;
  final Map<String, dynamic> Function(Map p) storeOf;
  final bool showStore;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 220).floor().clamp(2, 6);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: showStore ? 262 : 244),
        itemCount: products.length,
        itemBuilder: (context, i) {
          final p = products[i];
          final colors = toneOf(p);
          return ProductTile(
            p: p,
            colors: colors,
            offer: offerFor(offers, p),
            storeName: showStore ? '${storeOf(p)['name']}' : null,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProductPage(
                        store: storeOf(p),
                        product: p,
                        offer: offerFor(offers, p),
                        colors: colors))),
          );
        },
      );
    });
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile(
      {super.key,
      required this.p,
      required this.colors,
      required this.onTap,
      this.offer,
      this.storeName});
  final Map<String, dynamic> p;
  final List<Color> colors;
  final VoidCallback onTap;
  final Map<String, dynamic>? offer;
  final String? storeName;
  @override
  Widget build(BuildContext context) {
    final img = p['image_url'];
    final price = toNum(p['price']);
    final off = offerValue(offer, price);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 124,
            child: Stack(fit: StackFit.expand, children: [
              Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                          colors: colors))),
              if (img is String && img.isNotEmpty)
                Image.network(img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox())
              else ...[
                PositionedDirectional(
                    start: -20,
                    bottom: -30,
                    child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .1)))),
                Center(
                    child: Icon(Icons.set_meal_outlined,
                        size: 54, color: Colors.white.withValues(alpha: .92))),
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
              if (off > 0)
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999)),
                    child: Text('خصم ${bhd(off)}',
                        style: TextStyle(
                            color: colors.first,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    if (storeName != null)
                      Text(storeName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: colors.first,
                              fontWeight: FontWeight.w600)),
                    if ('${p['description'] ?? ''}'.isNotEmpty)
                      Text('${p['description']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    const Spacer(),
                    Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (off > 0)
                                Text(bhd(price),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black38,
                                        decoration:
                                            TextDecoration.lineThrough)),
                              Text(bhd(price - off),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: colors.first)),
                            ]),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: colors),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward,
                            size: 17, color: Colors.white),
                      ),
                    ]),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- one store

class StorePage extends StatefulWidget {
  const StorePage({super.key, required this.store, required this.colors});
  final Map<String, dynamic> store;
  final List<Color> colors;
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  String? cat;
  String search = '';

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final colors = widget.colors;
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
              .select('*, products(name)')
              .eq('merchant_id', store['id'])
              .eq('active', true);
          return (
            List<Map<String, dynamic>>.from(p),
            List<Map<String, dynamic>>.from(o)
          );
        },
        builder: (context, data, _) {
          final (products, offers) = data;
          final cats =
              <String>{for (final p in products) '${p['category'] ?? ''}'}
                  .toList();
          final q = search.trim();
          final shown = products.where((p) {
            if (cat != null && p['category'] != cat) return false;
            return q.isEmpty ||
                '${p['name']}'.contains(q) ||
                '${p['description'] ?? ''}'.contains(q);
          }).toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(18),
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
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: ClipOval(child: StoreLogo(store['logo_url'], size: 64)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store['name'],
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        Row(children: [
                          const Icon(Icons.place_outlined,
                              size: 15, color: Colors.white70),
                          const SizedBox(width: 3),
                          Text(store['area'] ?? '',
                              style: const TextStyle(color: Colors.white70)),
                          const SizedBox(width: 10),
                          Text('${products.length} صنف',
                              style: const TextStyle(color: Colors.white70)),
                        ]),
                        if ('${store['description'] ?? ''}'.isNotEmpty)
                          Text('${store['description']}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                      ]),
                ),
              ]),
            ),
            if (offers.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 64,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final o in offers)
                    Container(
                      margin: const EdgeInsetsDirectional.only(end: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: colors.first.withValues(alpha: .07),
                        border: Border.all(
                            color: colors.first.withValues(alpha: .35)),
                      ),
                      child: Row(children: [
                        Icon(Icons.local_offer, color: colors.first),
                        const SizedBox(width: 8),
                        Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${o['title']}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: colors.first)),
                              Text(o['products']?['name'] ?? 'كل الأصناف',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                            ]),
                      ]),
                    ),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'ابحث في أصناف الملحمة'),
              onChanged: (v) => setState(() => search = v),
            ),
            const SizedBox(height: 10),
            if (cats.length > 1)
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  TonePill(
                      label: 'الكل',
                      count: products.length,
                      colors: colors,
                      selected: cat == null,
                      onTap: () => setState(() => cat = null)),
                  for (final c in cats)
                    TonePill(
                        label: c,
                        count: products.where((p) => p['category'] == c).length,
                        colors: colors,
                        selected: cat == c,
                        onTap: () => setState(() => cat = c)),
                ]),
              ),
            const SizedBox(height: 10),
            if (shown.isEmpty)
              const Empty('لا توجد أصناف متاحة', icon: Icons.set_meal_outlined),
            ProductGrid(
              products: shown,
              offers: offers,
              toneOf: (_) => colors,
              storeOf: (_) => store,
            ),
          ]);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- product: buy or reserve

class ProductPage extends StatelessWidget {
  const ProductPage(
      {super.key,
      required this.store,
      required this.product,
      required this.colors,
      this.offer});
  final Map<String, dynamic> store;
  final Map<String, dynamic> product;
  final Map<String, dynamic>? offer;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final price = toNum(p['price']);
    final off = offerValue(offer, price);
    final img = p['image_url'];
    void go(String kind) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => OrderPage(
                store: store,
                product: p,
                offer: offer,
                colors: colors,
                kind: kind)));
    Widget choice(String kind, IconData icon, String title, String body,
            List<Color> cs) =>
        InkWell(
          onTap: () => go(kind),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: cs),
              boxShadow: [
                BoxShadow(
                    color: cs.first.withValues(alpha: .3),
                    blurRadius: 14,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(body,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              height: 1.5)),
                    ]),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white),
            ]),
          ),
        );
    return Scaffold(
      appBar: GradientAppBar(title: Text('${p['name']}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              height: 210,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: colors),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(fit: StackFit.expand, children: [
                if (img is String && img.isNotEmpty)
                  Image.network(img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox())
                else ...[
                  PositionedDirectional(
                      end: -40,
                      top: -40,
                      child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: .1)))),
                  Center(
                      child: Icon(Icons.set_meal_outlined,
                          size: 96,
                          color: Colors.white.withValues(alpha: .92))),
                ],
                PositionedDirectional(
                  bottom: 12,
                  start: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .25),
                        borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      ClipOval(child: StoreLogo(store['logo_url'], size: 22)),
                      const SizedBox(width: 6),
                      Text('${store['name']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p['name']}',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      Text('${p['category'] ?? ''}',
                          style: TextStyle(color: colors.first)),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (off > 0)
                  Text(bhd(price),
                      style: const TextStyle(
                          color: Colors.black38,
                          decoration: TextDecoration.lineThrough)),
                Text(bhd(price - off),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: colors.first)),
              ]),
            ]),
            if ('${p['description'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${p['description']}',
                  style: const TextStyle(color: Colors.black54, height: 1.6)),
            ],
            if (offer != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: colors.first.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(Icons.local_offer, color: colors.first),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('${offer!['title']}',
                          style: TextStyle(
                              color: colors.first,
                              fontWeight: FontWeight.w700))),
                ]),
              ),
            ],
            const SizedBox(height: 22),
            const Text('كيف تبي تطلب؟',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            choice(
                'purchase',
                Icons.shopping_bag_outlined,
                'شراء',
                'اختر طريقة التقطيع والتغليف وموعد الذبح والتسليم، وادفع في نفس الصفحة',
                colors),
            const SizedBox(height: 12),
            choice(
                'reservation',
                Icons.event_available_outlined,
                'حجز',
                'احجز الذبيحة بموعد الذبح والتوصيل، وبعدها تنتقل لصفحة الدفع',
                [Color.lerp(colors.first, Colors.black, .25)!, colors.first]),
          ]),
        ),
      ),
    );
  }
}
