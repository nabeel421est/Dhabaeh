import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/common.dart';
import '../customer/customer_shell.dart' show StoreLogo;
import 'admin_money.dart' show reportGradients;

/// Every merchant's products in one grid. Each store has its own colour, a filter pill,
/// and the search matches product name, category or store name.
class AdminProducts extends StatefulWidget {
  const AdminProducts({super.key});
  @override
  State<AdminProducts> createState() => _AdminProductsState();
}

class _AdminProductsState extends State<AdminProducts> {
  String? store; // null = all stores
  String search = '';
  bool onlyAvailable = false;

  @override
  Widget build(BuildContext context) {
    return Loader<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
      realtimeTables: const ['products', 'merchants'],
      load: () async {
        final p = await sb
            .from('products')
            .select('*, merchants(id, name, logo_url)')
            .order('created_at', ascending: false);
        final m = await sb
            .from('merchants')
            .select('id, name, logo_url')
            .order('name');
        return (
          List<Map<String, dynamic>>.from(p),
          List<Map<String, dynamic>>.from(m)
        );
      },
      builder: (context, data, _) {
        final (products, merchants) = data;
        final colorOf = {
          for (var i = 0; i < merchants.length; i++)
            merchants[i]['id']: reportGradients[i % reportGradients.length]
        };
        final q = search.trim();
        final shown = products.where((p) {
          if (store != null && p['merchant_id'] != store) return false;
          if (onlyAvailable && p['available'] != true) return false;
          if (q.isEmpty) return true;
          return '${p['name']}'.contains(q) ||
              '${p['category']}'.contains(q) ||
              '${p['merchants']?['name']}'.contains(q);
        }).toList();
        final prices = products.map((p) => toNum(p['price'])).toList();
        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon: Icons.inventory_2_outlined,
            title: 'المنتجات',
            subtitle:
                'منتجات كل المسالخ في مكان واحد، فلترها حسب المتجر أو ابحث عن صنف',
            stats: [
              ('المنتجات', '${products.length}'),
              (
                'متاح',
                '${products.where((p) => p['available'] == true).length}'
              ),
              ('المتاجر', '${merchants.length}'),
              if (prices.isNotEmpty)
                (
                  'الأسعار',
                  '${bhd(prices.reduce((a, b) => a < b ? a : b))} - ${bhd(prices.reduce((a, b) => a > b ? a : b))}'
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'ابحث عن صنف أو متجر، مثل: نعيمي أو مسلخ الواحة'),
                onChanged: (v) => setState(() => search = v),
              ),
            ),
            const SizedBox(width: 10),
            FilterChip(
                label: const Text('المتاح فقط'),
                selected: onlyAvailable,
                onSelected: (v) => setState(() => onlyAvailable = v)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              _StorePill(
                name: 'كل المتاجر',
                count: products.length,
                colors: brandOf(context).stops.sublist(1),
                selected: store == null,
                onTap: () => setState(() => store = null),
              ),
              for (final m in merchants)
                _StorePill(
                  name: m['name'],
                  logo: m['logo_url'],
                  count:
                      products.where((p) => p['merchant_id'] == m['id']).length,
                  colors: colorOf[m['id']]!,
                  selected: store == m['id'],
                  onTap: () => setState(() => store = m['id']),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            const Empty('لا توجد منتجات تطابق البحث',
                icon: Icons.inventory_2_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 230).floor().clamp(2, 6);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 268),
              itemCount: shown.length,
              itemBuilder: (context, i) => _ProductTile(
                  p: shown[i],
                  colors:
                      colorOf[shown[i]['merchant_id']] ?? reportGradients[0]),
            );
          }),
        ]);
      },
    );
  }
}

class _StorePill extends StatelessWidget {
  const _StorePill(
      {required this.name,
      required this.count,
      required this.colors,
      required this.selected,
      required this.onTap,
      this.logo});
  final String name;
  final int count;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;
  final dynamic logo;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: selected ? LinearGradient(colors: colors) : null,
              color: selected ? null : Colors.white,
              border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : colors.first.withValues(alpha: .35)),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: colors.first.withValues(alpha: .3),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (logo != null || name != 'كل المتاجر')
                ClipOval(child: StoreLogo(logo, size: 30))
              else
                CircleAvatar(
                    radius: 15,
                    backgroundColor: selected
                        ? Colors.white24
                        : colors.first.withValues(alpha: .12),
                    child: Icon(Icons.apps,
                        size: 16,
                        color: selected ? Colors.white : colors.first)),
              const SizedBox(width: 8),
              Text(name,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : colors.first)),
              const SizedBox(width: 6),
              Text('$count',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: selected ? Colors.white70 : Colors.black38)),
            ]),
          ),
        ),
      );
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.p, required this.colors});
  final Map<String, dynamic> p;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) {
    final img = p['image_url'];
    final on = p['available'] == true;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 128,
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
                  end: -18,
                  top: -18,
                  child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: .1)))),
              Center(
                  child: Icon(Icons.set_meal_outlined,
                      size: 54, color: Colors.white.withValues(alpha: .9))),
            ],
            PositionedDirectional(
              top: 8,
              start: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .25),
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
                  child: const Text('غير متاح',
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
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: colors))),
                const SizedBox(width: 6),
                Expanded(
                    child: Text('${p['merchants']?['name'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.first,
                            fontWeight: FontWeight.w600))),
                Text(bhd(p['price']),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: colors.first)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}
