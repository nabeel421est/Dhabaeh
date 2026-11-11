import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../core/bg_remove.dart';
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
  String vis = 'all'; // all | shown | hidden

  @override
  Widget build(BuildContext context) {
    return Loader<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
      realtimeTables: const ['products', 'merchants', 'product_units'],
      load: () async {
        final p = await sb
            .from('products')
            .select(
                '*, merchants(id, name, logo_url), product_units(id, name, price, sku, sort)')
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
      builder: (context, data, reload) {
        final (products, merchants) = data;
        final colorOf = {
          for (var i = 0; i < merchants.length; i++)
            merchants[i]['id']: reportGradients[i % reportGradients.length]
        };
        final q = search.trim();
        final shown = products.where((p) {
          if (store != null && p['merchant_id'] != store) return false;
          if (vis == 'shown' && p['available'] != true) return false;
          if (vis == 'hidden' && p['available'] == true) return false;
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
            action: HeroButton(
              icon: Icons.add_box_outlined,
              label: 'إضافة منتج',
              onPressed: () async {
                if (await showProductEditor(context, merchants, colorOf,
                    store: store)) {
                  await reload();
                }
              },
            ),
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
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            TonePill(
                label: 'الكل',
                icon: Icons.apps,
                colors: G.violet,
                count: products.length,
                selected: vis == 'all',
                onTap: () => setState(() => vis = 'all')),
            TonePill(
                label: 'ظاهر للعملاء',
                icon: Icons.visibility_outlined,
                colors: G.emerald,
                count: products.where((p) => p['available'] == true).length,
                selected: vis == 'shown',
                onTap: () => setState(() => vis = 'shown')),
            TonePill(
                label: 'مخفي',
                icon: Icons.visibility_off_outlined,
                colors: G.ruby,
                count: products.where((p) => p['available'] != true).length,
                selected: vis == 'hidden',
                onTap: () => setState(() => vis = 'hidden')),
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
                  mainAxisExtent: 360),
              itemCount: shown.length,
              itemBuilder: (context, i) => _ProductTile(
                p: shown[i],
                colors: colorOf[shown[i]['merchant_id']] ?? reportGradients[0],
                onEdit: () async {
                  if (await showProductEditor(context, merchants, colorOf,
                      existing: shown[i])) {
                    await reload();
                  }
                },
                onToggle: () async {
                  final on = shown[i]['available'] == true;
                  await guard(
                      context,
                      () => sb
                          .from('products')
                          .update({'available': !on}).eq('id', shown[i]['id']),
                      ok: on
                          ? 'تم إخفاء المنتج عن العملاء'
                          : 'المنتج ظاهر للعملاء الآن');
                  await reload();
                },
              ),
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

/// A product card: gradient picture area in the store's colours, price, and an
/// action bar with edit and a show/hide switch. Hidden products are dimmed.
class _ProductTile extends StatelessWidget {
  const _ProductTile(
      {required this.p,
      required this.colors,
      required this.onEdit,
      required this.onToggle});
  final Map<String, dynamic> p;
  final List<Color> colors;
  final VoidCallback onEdit, onToggle;
  @override
  Widget build(BuildContext context) {
    final img = p['image_url'];
    final on = p['available'] == true;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: on
                ? colors.first.withValues(alpha: .15)
                : const Color(0xFFB83250).withValues(alpha: .25)),
        boxShadow: [
          BoxShadow(
              color: colors.first.withValues(alpha: on ? .14 : .05),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 170,
          child: Stack(fit: StackFit.expand, children: [
            Container(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: [colors.last, colors.first]))),
            PositionedDirectional(
                end: -24,
                top: -24,
                child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .12)))),
            PositionedDirectional(
                start: -16,
                bottom: -30,
                child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .08)))),
            if (img is String && img.isNotEmpty)
              ProductPhoto(url: img, colors: colors)
            else
              Center(
                  child: Icon(Icons.set_meal_outlined,
                      size: 56, color: Colors.white.withValues(alpha: .92))),
            if (!on)
              Container(
                color: Colors.black.withValues(alpha: .45),
                alignment: Alignment.center,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.visibility_off_outlined,
                        size: 15, color: Color(0xFFB83250)),
                    SizedBox(width: 5),
                    Text('مخفي عن العملاء',
                        style: TextStyle(
                            color: Color(0xFFB83250),
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            PositionedDirectional(
              top: 10,
              start: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .22),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .4)),
                    borderRadius: BorderRadius.circular(999)),
                child: Text('${p['category'] ?? ''}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15.5)),
              if ('${p['name_en'] ?? ''}'.isNotEmpty)
                Text('${p['name_en']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                        fontSize: 12,
                        color: colors.first.withValues(alpha: .8),
                        fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SizedBox(
                height: 24,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  _unitChip(
                      '${p['base_unit'] ?? 'ذبيحة'}', p['price'], colors, true),
                  for (final u in ([
                    ...(p['product_units'] as List? ?? [])
                  ]..sort(
                      (a, b) => toNum(a['sort']).compareTo(toNum(b['sort'])))))
                    _unitChip('${u['name']}', u['price'], colors, false),
                ]),
              ),
              if ('${p['description'] ?? ''}'.isNotEmpty &&
                  (p['product_units'] as List? ?? []).isEmpty)
                Text('${p['description']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54, height: 1.4)),
              const Spacer(),
              Row(children: [
                ClipOval(
                    child: StoreLogo(p['merchants']?['logo_url'], size: 22)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text('${p['merchants']?['name'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.first,
                            fontWeight: FontWeight.w700))),
                ShaderMask(
                  shaderCallback: (r) =>
                      LinearGradient(colors: colors).createShader(r),
                  child: Text(bhd(p['price']),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.white)),
                ),
              ]),
            ]),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: colors.first.withValues(alpha: .08)))),
          child: Row(children: [
            Expanded(
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: [
                      colors.first.withValues(alpha: .1),
                      colors.last.withValues(alpha: .18)
                    ]),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 16, color: colors.first),
                        const SizedBox(width: 5),
                        Text('تعديل',
                            style: TextStyle(
                                color: colors.first,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                        colors: on
                            ? G.emerald
                            : [Colors.grey.shade500, Colors.grey.shade400]),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            on
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 16,
                            color: Colors.white),
                        const SizedBox(width: 5),
                        Text(on ? 'ظاهر' : 'مخفي',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Add or edit a product for any store. Returns true when saved.
Future<bool> showProductEditor(BuildContext context,
    List<Map<String, dynamic>> merchants, Map<dynamic, List<Color>> colorOf,
    {Map<String, dynamic>? existing, String? store}) async {
  final p = existing;
  final form = GlobalKey<FormState>();
  final name = TextEditingController(text: p?['name'] ?? '');
  final category = TextEditingController(text: p?['category'] ?? 'ذبائح');
  final desc = TextEditingController(text: p?['description'] ?? '');
  final price = TextEditingController(text: p == null ? '' : '${p['price']}');
  String? mid = p?['merchant_id'] as String? ??
      store ??
      (merchants.isEmpty ? null : merchants.first['id'] as String);
  bool available = p == null ? true : p['available'] == true;
  PlatformFile? image;
  String? imageUrl = p?['image_url'] as String?;
  // Background removal: on by default for new photos; original kept for undo.
  bool autoBg = true;
  bool bgBusy = false;
  String? bgNote; // status line under the photo
  PlatformFile? original;
  const cats = ['ذبائح', 'لحوم مقطعة', 'دواجن', 'أضاحي', 'عروض'];
  final nameEn = TextEditingController(text: p?['name_en'] ?? '');
  final sku = TextEditingController(text: p?['sku'] ?? '');
  String baseUnit = (p?['base_unit'] as String?) ?? unitPresets.first;
  final units = <_UnitRow>[];
  if (p != null) {
    try {
      final rows = await sb
          .from('product_units')
          .select()
          .eq('product_id', p['id'])
          .order('sort');
      for (final u in rows) {
        units.add(_UnitRow(
            id: u['id'] as String,
            name: '${u['name'] ?? ''}',
            price: '${u['price'] ?? ''}',
            sku: '${u['sku'] ?? ''}'));
      }
    } catch (_) {}
  }
  if (!context.mounted) return false;
  final removed = <String>[];

  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final colors = colorOf[mid] ?? G.emerald;
      InputDecoration deco(String label, IconData icon,
              {String? suffix, String? hint}) =>
          InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: colors.first),
            suffixText: suffix,
            filled: true,
            fillColor: colors.first.withValues(alpha: .04),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: colors.first.withValues(alpha: .18))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colors.first, width: 1.6)),
          );
      final hasPic =
          image?.bytes != null || (imageUrl != null && imageUrl!.isNotEmpty);
      Future<void> cutBackground(Uint8List bytes, String name) async {
        set(() {
          bgBusy = true;
          bgNote = 'جاري إزالة الخلفية… (أول مرة قد تأخذ دقيقة أو دقيقتين لتحميل الأداة)';
        });
        final out = await removeImageBackground(bytes, mimeOf(name));
        if (!c.mounted) return;
        set(() {
          bgBusy = false;
          if (out == null) {
            bgNote = 'تعذرت إزالة الخلفية، سيتم حفظ الصورة كما هي';
          } else {
            final base = name.contains('.')
                ? name.substring(0, name.lastIndexOf('.'))
                : name;
            image = PlatformFile(
                name: '$base-cut.png', size: out.length, bytes: out);
            bgNote = 'تمت إزالة الخلفية';
          }
        });
      }

      return Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 860),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header doubles as a live preview of the product card.
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [colors.last, colors.first]),
              ),
              child: Row(children: [
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () async {
                    final r = await FilePicker.platform.pickFiles(
                        withData: true,
                        type: FileType.custom,
                        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp']);
                    final f = r?.files.first;
                    if (f == null || f.bytes == null) return;
                    set(() {
                      image = f;
                      original = f;
                      bgNote = null;
                    });
                    if (autoBg) await cutBackground(f.bytes!, f.name);
                  },
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(22),
                      border:
                          Border.all(color: const Color(0xFFF2D58A), width: 2),
                      image: image?.bytes != null
                          ? DecorationImage(
                              image: MemoryImage(image!.bytes!),
                              fit: BoxFit.cover)
                          : (imageUrl != null && imageUrl!.isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(imageUrl!),
                                  fit: BoxFit.cover)
                              : null,
                    ),
                    child: bgBusy
                        ? const Center(
                            child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                    strokeWidth: 3, color: Colors.white)))
                        : hasPic
                            ? null
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        color: Colors.white, size: 28),
                                    SizedBox(height: 2),
                                    Text('صورة المنتج',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5)),
                                  ]),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p == null ? 'إضافة منتج جديد' : 'تعديل المنتج',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                            name.text.trim().isEmpty
                                ? 'اسم المنتج يظهر هنا'
                                : name.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .9),
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          _pill(
                              Icons.sell_outlined,
                              price.text.trim().isEmpty
                                  ? 'السعر'
                                  : '${bhd(num.tryParse(price.text.trim()) ?? 0)} / $baseUnit'),
                          _pill(
                              Icons.category_outlined,
                              category.text.trim().isEmpty
                                  ? 'التصنيف'
                                  : category.text.trim()),
                          _pill(
                              available
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              available ? 'ظاهر' : 'مخفي'),
                        ]),
                      ]),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(c, false),
                    icon: const Icon(Icons.close, color: Colors.white)),
              ]),
            ),
            Flexible(
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: mid,
                          isExpanded: true,
                          decoration:
                              deco('المتجر *', Icons.storefront_outlined),
                          items: [
                            for (final m in merchants)
                              DropdownMenuItem(
                                  value: m['id'] as String,
                                  child: Row(children: [
                                    ClipOval(
                                        child:
                                            StoreLogo(m['logo_url'], size: 24)),
                                    const SizedBox(width: 8),
                                    Text('${m['name']}'),
                                  ]))
                          ],
                          onChanged:
                              p == null ? (v) => set(() => mid = v) : null,
                          validator: (v) => v == null ? 'اختر المتجر' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: name,
                          onChanged: (_) => set(() {}),
                          decoration: deco(
                              'اسم المنتج *', Icons.set_meal_outlined,
                              hint: 'مثال: خروف نعيمي'),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'اكتب اسم المنتج'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameEn,
                          textDirection: TextDirection.ltr,
                          decoration: deco(
                              'اسم المنتج بالإنجليزي', Icons.translate_outlined,
                              hint: 'e.g. Naimi Lamb'),
                        ),
                        const SizedBox(height: 16),
                        _UnitBox(
                          title: 'الوحدة الأساسية',
                          subtitle: 'السعر الذي يظهر أولاً للعميل',
                          icon: Icons.star_outline,
                          colors: colors,
                          child: LayoutBuilder(builder: (context, box) {
                            final w = box.maxWidth >= 480
                                ? (box.maxWidth - 20) / 3
                                : box.maxWidth;
                            return Wrap(spacing: 10, runSpacing: 10, children: [
                              SizedBox(
                                width: w,
                                child: DropdownButtonFormField<String>(
                                  initialValue: baseUnit,
                                  isExpanded: true,
                                  decoration: deco(
                                      'الوحدة *', Icons.straighten_outlined),
                                  items: [
                                    for (final u in {...unitPresets, baseUnit})
                                      DropdownMenuItem(value: u, child: Text(u))
                                  ],
                                  onChanged: (v) =>
                                      set(() => baseUnit = v ?? baseUnit),
                                ),
                              ),
                              SizedBox(
                                width: w,
                                child: TextFormField(
                                  controller: price,
                                  onChanged: (_) => set(() {}),
                                  textDirection: TextDirection.ltr,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: deco(
                                      'السعر *', Icons.sell_outlined,
                                      suffix: ' د.ب '),
                                  validator: _priceCheck,
                                ),
                              ),
                              SizedBox(
                                width: w,
                                child: TextFormField(
                                  controller: sku,
                                  textDirection: TextDirection.ltr,
                                  decoration: deco(
                                      'رقم الصنف', Icons.qr_code_2_outlined),
                                ),
                              ),
                            ]);
                          }),
                        ),
                        const SizedBox(height: 12),
                        _UnitBox(
                          title: 'وحدات إضافية',
                          subtitle: units.isEmpty
                              ? 'مثل نصف ذبيحة أو ربع ذبيحة أو كيلو، لكل وحدة سعرها ورقم صنفها'
                              : '${units.length} وحدة إضافية',
                          icon: Icons.layers_outlined,
                          colors: G.violet,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < units.length; i++)
                                  _UnitEditor(
                                    key: ObjectKey(units[i]),
                                    row: units[i],
                                    index: i + 1,
                                    taken: {
                                      baseUnit,
                                      for (final u in units)
                                        if (u != units[i]) u.name.text.trim()
                                    },
                                    deco: deco,
                                    onChanged: () => set(() {}),
                                    onDelete: () => set(() {
                                      final u = units.removeAt(i);
                                      if (u.id != null) removed.add(u.id!);
                                    }),
                                  ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(46),
                                    foregroundColor: G.violet.first,
                                    side: BorderSide(
                                        color: G.violet.first
                                            .withValues(alpha: .35),
                                        style: BorderStyle.solid),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  onPressed: () => set(() {
                                    final used = {
                                      baseUnit,
                                      for (final u in units) u.name.text.trim()
                                    };
                                    units.add(_UnitRow(
                                        name: unitPresets.firstWhere(
                                            (x) => !used.contains(x),
                                            orElse: () => '')));
                                  }),
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: const Text('إضافة وحدة',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800)),
                                ),
                              ]),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: category,
                          onChanged: (_) => set(() {}),
                          decoration:
                              deco('التصنيف *', Icons.category_outlined),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'اكتب التصنيف' : null,
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final k in cats)
                            TonePill(
                              label: k,
                              colors: colors,
                              selected: category.text.trim() == k,
                              onTap: () => set(() => category.text = k),
                            ),
                        ]),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: desc,
                          maxLines: 3,
                          decoration: deco('الوصف', Icons.notes_outlined,
                              hint: 'الوزن التقريبي، العمر، طريقة التقطيع…'),
                        ),
                        const SizedBox(height: 14),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                                colors: available
                                    ? [
                                        G.emerald.first.withValues(alpha: .08),
                                        G.emerald.last.withValues(alpha: .16)
                                      ]
                                    : [
                                        G.ruby.first.withValues(alpha: .06),
                                        G.ruby.last.withValues(alpha: .12)
                                      ]),
                            border: Border.all(
                                color: (available ? G.emerald : G.ruby)
                                    .first
                                    .withValues(alpha: .25)),
                          ),
                          child: SwitchListTile(
                            value: available,
                            activeThumbColor: Colors.white,
                            activeTrackColor: G.emerald.first,
                            secondary: Icon(
                                available
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: (available ? G.emerald : G.ruby).first),
                            title: Text(
                                available ? 'ظاهر للعملاء' : 'مخفي عن العملاء',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            subtitle: Text(available
                                ? 'يظهر في صفحة المتجر ويمكن طلبه'
                                : 'لا يظهر للعملاء حتى تعيد إظهاره'),
                            onChanged: (v) => set(() => available = v),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _BgCard(
                          colors: colors,
                          auto: autoBg,
                          busy: bgBusy,
                          note: bgNote,
                          onAuto: (v) async {
                            set(() => autoBg = v);
                            final o = original;
                            if (bgBusy || o?.bytes == null) return;
                            if (v) {
                              await cutBackground(o!.bytes!, o.name);
                            } else {
                              set(() {
                                image = o;
                                bgNote = 'تم الرجوع للصورة الأصلية';
                              });
                            }
                          },
                          onCutCurrent: (image == null &&
                                  imageUrl != null &&
                                  imageUrl!.isNotEmpty &&
                                  !bgBusy)
                              ? () async {
                                  try {
                                    final res =
                                        await http.get(Uri.parse(imageUrl!));
                                    if (res.statusCode != 200) throw 'x';
                                    final name =
                                        Uri.parse(imageUrl!).pathSegments.last;
                                    original = PlatformFile(
                                        name: name,
                                        size: res.bodyBytes.length,
                                        bytes: res.bodyBytes);
                                    await cutBackground(res.bodyBytes, name);
                                  } catch (_) {
                                    set(() =>
                                        bgNote = 'تعذر تحميل الصورة الحالية');
                                  }
                                }
                              : null,
                        ),
                        if (hasPic) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                  foregroundColor: G.ruby.first),
                              onPressed: () => set(() {
                                image = null;
                                original = null;
                                bgNote = null;
                                imageUrl = null;
                              }),
                              icon: const Icon(Icons.hide_image_outlined,
                                  size: 18),
                              label: const Text('إزالة الصورة'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ]),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: colors.first.withValues(alpha: .1))),
              ),
              child: Row(children: [
                Expanded(
                  flex: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient:
                          LinearGradient(colors: [colors.first, colors.last]),
                      boxShadow: [
                        BoxShadow(
                            color: colors.first.withValues(alpha: .35),
                            blurRadius: 14,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: bgBusy
                          ? null
                          : () {
                              if (form.currentState!.validate()) {
                                Navigator.pop(c, true);
                              }
                            },
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(p == null ? 'إضافة المنتج' : 'حفظ التعديلات',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: colors.first,
                      side:
                          BorderSide(color: colors.first.withValues(alpha: .4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('إلغاء'),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
    }),
  );
  if (ok != true || !context.mounted) return false;
  final r = await guard(context, () async {
    var url = imageUrl;
    if (image?.bytes != null) {
      final path = 'products/${safeFileName(image!.name)}';
      await sb.storage.from('media').uploadBinary(path, image!.bytes!,
          fileOptions: FileOptions(contentType: mimeOf(image!.name)));
      url = sb.storage.from('media').getPublicUrl(path);
    }
    final row = {
      'merchant_id': mid,
      'name': name.text.trim(),
      'name_en': nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
      'base_unit': baseUnit,
      'sku': sku.text.trim().isEmpty ? null : sku.text.trim(),
      'category': category.text.trim(),
      'description': desc.text.trim(),
      'price': num.tryParse(price.text.trim()) ?? 0,
      'available': available,
      'image_url': url,
    };
    String pid;
    if (p == null) {
      final ins = await sb.from('products').insert(row).select('id').single();
      pid = ins['id'] as String;
    } else {
      pid = p['id'] as String;
      await sb.from('products').update(row).eq('id', pid);
    }
    if (removed.isNotEmpty) {
      await sb.from('product_units').delete().inFilter('id', removed);
    }
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      final data = {
        'product_id': pid,
        'name': u.name.text.trim(),
        'price': num.tryParse(u.price.text.trim()) ?? 0,
        'sku': u.sku.text.trim().isEmpty ? null : u.sku.text.trim(),
        'sort': i,
      };
      if (u.id == null) {
        await sb.from('product_units').insert(data);
      } else {
        await sb.from('product_units').update(data).eq('id', u.id!);
      }
    }
    return true;
  }, ok: p == null ? 'تمت إضافة المنتج' : 'تم حفظ التعديلات');
  return r == true;
}

Widget _pill(IconData i, String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 13, color: Colors.white),
        const SizedBox(width: 4),
        Text(t,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ]),
    );

/// Unit names offered when adding a product.
const unitPresets = ['ذبيحة', 'نصف ذبيحة', 'ربع ذبيحة', 'كيلو'];

String? _priceCheck(String? v) {
  final n = num.tryParse((v ?? '').trim());
  return n == null || n <= 0 ? 'اكتب سعراً صحيحاً' : null;
}

class _UnitRow {
  _UnitRow({this.id, String name = '', String price = '', String sku = ''})
      : name = TextEditingController(text: name),
        price = TextEditingController(text: price),
        sku = TextEditingController(text: sku);
  final String? id;
  final TextEditingController name, price, sku;
}

/// A tinted box with a small gradient title, used for the unit sections.
class _UnitBox extends StatelessWidget {
  const _UnitBox(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.colors,
      required this.child});
  final String title, subtitle;
  final IconData icon;
  final List<Color> colors;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: [
            colors.first.withValues(alpha: .05),
            colors.last.withValues(alpha: .12)
          ]),
          border: Border.all(color: colors.first.withValues(alpha: .2)),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: colors.first)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

/// One extra unit: name (with quick picks), price and its own item number.
class _UnitEditor extends StatelessWidget {
  const _UnitEditor(
      {super.key,
      required this.row,
      required this.index,
      required this.taken,
      required this.deco,
      required this.onChanged,
      required this.onDelete});
  final _UnitRow row;
  final int index;
  final Set<String> taken;
  final InputDecoration Function(String, IconData,
      {String? suffix, String? hint}) deco;
  final VoidCallback onChanged, onDelete;
  @override
  Widget build(BuildContext context) {
    final g = G.violet;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: g.first.withValues(alpha: .15)),
        boxShadow: [
          BoxShadow(
              color: g.first.withValues(alpha: .06),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: g), shape: BoxShape.circle),
            child: Text('$index',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final u in unitPresets)
                if (!taken.contains(u))
                  TonePill(
                    label: u,
                    colors: g,
                    selected: row.name.text.trim() == u,
                    onTap: () {
                      row.name.text = u;
                      onChanged();
                    },
                  ),
            ]),
          ),
          IconButton(
            tooltip: 'حذف الوحدة',
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: G.ruby.first),
          ),
        ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, box) {
          final w =
              box.maxWidth >= 480 ? (box.maxWidth - 20) / 3 : box.maxWidth;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(
              width: w,
              child: TextFormField(
                controller: row.name,
                onChanged: (_) => onChanged(),
                decoration: deco('اسم الوحدة *', Icons.straighten_outlined),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'اكتب اسم الوحدة';
                  if (taken.contains(t)) return 'الوحدة مكررة';
                  return null;
                },
              ),
            ),
            SizedBox(
              width: w,
              child: TextFormField(
                controller: row.price,
                textDirection: TextDirection.ltr,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    deco('السعر *', Icons.sell_outlined, suffix: ' د.ب '),
                validator: _priceCheck,
              ),
            ),
            SizedBox(
              width: w,
              child: TextFormField(
                controller: row.sku,
                textDirection: TextDirection.ltr,
                decoration: deco('رقم صنف الوحدة', Icons.qr_code_2_outlined),
              ),
            ),
          ]);
        }),
      ]),
    );
  }
}

Widget _unitChip(String name, dynamic price, List<Color> colors, bool base) =>
    Container(
      margin: const EdgeInsetsDirectional.only(end: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: base
            ? LinearGradient(colors: colors)
            : LinearGradient(colors: [
                colors.first.withValues(alpha: .08),
                colors.last.withValues(alpha: .16)
              ]),
      ),
      child: Text('$name · ${bhd(price)}',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: base ? Colors.white : colors.first)),
    );

/// Switch + status for removing the product photo background.
class _BgCard extends StatelessWidget {
  const _BgCard(
      {required this.colors,
      required this.auto,
      required this.busy,
      required this.note,
      required this.onAuto,
      required this.onCutCurrent});
  final List<Color> colors;
  final bool auto, busy;
  final String? note;
  final ValueChanged<bool> onAuto;
  final VoidCallback? onCutCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [
          colors.first.withValues(alpha: .08),
          colors.last.withValues(alpha: .04)
        ]),
        border: Border.all(color: colors.first.withValues(alpha: .18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [colors.first, colors.last])),
            child:
                const Icon(Icons.auto_fix_high, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('إزالة خلفية الصورة تلقائياً',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              Text('تبقى صورة المنتج فقط بخلفية شفافة',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
          Switch(
              value: auto,
              activeTrackColor: colors.first,
              onChanged: busy ? null : onAuto),
        ]),
        if (busy) ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(
              color: colors.first,
              backgroundColor: colors.first.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(4)),
        ],
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(note!,
              style: TextStyle(
                  fontSize: 12.5,
                  color: colors.first,
                  fontWeight: FontWeight.w700)),
        ],
        if (onCutCurrent != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: colors.first),
              onPressed: onCutCurrent,
              icon: const Icon(Icons.content_cut, size: 18),
              label: const Text('إزالة الخلفية من الصورة الحالية'),
            ),
          ),
      ]),
    );
  }
}
