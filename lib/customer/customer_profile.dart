import 'package:flutter/material.dart' hide Text;

import 'package:latlong2/latlong.dart';

import '../core/address_map.dart';
import '../core/brand.dart';
import '../core/common.dart';
import '../core/ttext.dart';
import '../core/i18n.dart';

typedef _ProfileData = (
  Map<String, dynamic>?,
  Map<String, dynamic>?,
  List<Map<String, dynamic>>,
  List<Map<String, dynamic>>
);

/// The customer's own info: view and edit name, area and delivery address.
/// The phone is the login, so it is shown read-only.
class CustomerProfilePage extends StatelessWidget {
  const CustomerProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: Text('معلوماتي')),
      body: Loader<_ProfileData>(
        load: () async {
          final p = await sb
              .from('profiles')
              .select('full_name, phone, area, cpr, email, created_at')
              .eq('id', myId!)
              .maybeSingle();
          final a = await sb
              .from('customer_addresses')
              .select()
              .eq('user_id', myId!)
              .order('created_at', ascending: false)
              .limit(1);
          final z = await sb
              .from('delivery_zones')
              .select('name')
              .eq('active', true)
              .order('name');
          final o = await sb
              .from('orders')
              .select('status, total')
              .eq('customer_id', myId!);
          return (
            p,
            (a as List).isEmpty ? null : Map<String, dynamic>.from(a.first),
            List<Map<String, dynamic>>.from(z),
            List<Map<String, dynamic>>.from(o),
          );
        },
        builder: (context, data, reload) => _ProfileForm(
            key: ValueKey(data.hashCode), data: data, reload: reload),
      ),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({super.key, required this.data, required this.reload});
  final _ProfileData data;
  final Future<void> Function() reload;
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: '${p?['full_name'] ?? ''}');
  late final house = TextEditingController(text: '${addr?['house'] ?? ''}');
  late final road = TextEditingController(text: '${addr?['road'] ?? ''}');
  late final block = TextEditingController(text: '${addr?['block'] ?? ''}');
  late final note = TextEditingController(text: '${addr?['note'] ?? ''}');
  late final flat = TextEditingController(text: '${addr?['flat'] ?? ''}');
  late final cpr = TextEditingController(text: '${p?['cpr'] ?? ''}');
  late final email = TextEditingController(text: '${p?['email'] ?? ''}');
  String? area;
  String? city;
  LatLng? pin;
  bool locating = false;
  bool editing = false;
  bool saving = false;

  Map<String, dynamic>? get p => widget.data.$1;
  Map<String, dynamic>? get addr => widget.data.$2;
  List<String> get zones => [
        for (final z in widget.data.$3) '${z['name']}',
      ];

  @override
  void initState() {
    super.initState();
    final a = '${addr?['area'] ?? p?['area'] ?? ''}';
    area = a.isEmpty ? null : a;
    final c = '${addr?['city'] ?? ''}';
    city = c.isEmpty ? null : c;
    final lat = addr?['lat'], lng = addr?['lng'];
    if (lat is num && lng is num) pin = LatLng(lat.toDouble(), lng.toDouble());
  }

  Future<void> locate() async {
    setState(() => locating = true);
    final r = await geocodeBahrain(
        building: house.text.trim(),
        block: block.text.trim(),
        road: road.text.trim(),
        area: area,
        city: city);
    if (!mounted) return;
    setState(() {
      locating = false;
      if (r != null) pin = r;
    });
    if (r == null)
      toast(context, 'ما قدرنا نحدد العنوان، اضغط على الخريطة', error: true);
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    final ok = await guard(context, () async {
      await sb.from('profiles').update({
        'full_name': name.text.trim(),
        'area': area,
        'cpr': cpr.text.trim().isEmpty ? null : cpr.text.trim(),
        'email': email.text.trim().isEmpty ? null : email.text.trim(),
      }).eq('id', myId!);
      final row = {
        'house': house.text.trim(),
        'road': road.text.trim(),
        'block': block.text.trim(),
        'area': area,
        'note': note.text.trim(),
        'city': city,
        'flat': flat.text.trim(),
        'lat': pin?.latitude,
        'lng': pin?.longitude,
      };
      if (addr != null) {
        await sb.from('customer_addresses').update(row).eq('id', addr!['id']);
      } else if (row.values.any((v) => '${v ?? ''}'.isNotEmpty)) {
        await sb.from('customer_addresses').insert({...row, 'user_id': myId});
      }
      return true;
    }, ok: 'تم حفظ معلوماتك');
    if (!mounted) return;
    setState(() => saving = false);
    if (ok == true) {
      setState(() => editing = false);
      await widget.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = brandOf(context);
    final orders = widget.data.$4;
    final delivered = orders.where((o) => o['status'] == 'delivered');
    final fullName = '${p?['full_name'] ?? ''}';
    final phone = '${p?['phone'] ?? ''}';
    final addressText = [
      if ('${addr?['flat'] ?? ''}'.isNotEmpty) 'شقة ${addr!['flat']}',
      if ('${addr?['house'] ?? ''}'.isNotEmpty) 'مبنى ${addr!['house']}',
      if ('${addr?['road'] ?? ''}'.isNotEmpty) 'طريق ${addr!['road']}',
      if ('${addr?['block'] ?? ''}'.isNotEmpty) 'مجمع ${addr!['block']}',
      if ((area ?? '').isNotEmpty) area!,
      if ((city ?? '').isNotEmpty) city!,
    ].join(' · ');

    return Form(
      key: form,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: avatar, name, phone and order totals.
                  GradientCard(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                                colors: [b.accent, Colors.white, b.accent])),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: b.dark,
                          child: Text(
                              fullName.isEmpty
                                  ? '?'
                                  : fullName.characters.first,
                              style: TextStyle(
                                  color: b.accent,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(fullName.isEmpty ? 'عميل' : fullName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.phone_iphone,
                            size: 15, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(phone,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(color: Colors.white70)),
                      ]),
                      if (p?['created_at'] != null)
                        Text('عميل منذ ${dateText(p!['created_at'])}',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 14),
                      Row(children: [
                        _stat('الطلبات', '${orders.length}', b.accent),
                        _stat('المكتملة', '${delivered.length}', b.accent),
                        _stat(
                            'مشترياتي',
                            bhd(delivered.fold<num>(
                                0, (a, o) => a + toNum(o['total']))),
                            b.accent),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  GradientHeaderCard(
                    title: 'البيانات الشخصية',
                    subtitle: 'الاسم والمنطقة',
                    icon: Icons.badge_outlined,
                    colors: G.violet,
                    trailing: editing
                        ? null
                        : TextButton.icon(
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor:
                                    Colors.white.withValues(alpha: .18)),
                            onPressed: () => setState(() => editing = true),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('تعديل')),
                    child: editing
                        ? Column(children: [
                            TextFormField(
                              controller: name,
                              decoration:
                                  InputDecoration(labelText: tr('الاسم *')),
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? tr('اكتب اسمك')
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              initialValue: phone,
                              enabled: false,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                  labelText: tr('رقم الهاتف'),
                                  prefixIcon: Icon(Icons.lock_outline),
                                  helperText: tr(
                                      'رقم الهاتف هو اسم الدخول، ولتغييره تواصل مع الإدارة')),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: cpr,
                              keyboardType: TextInputType.number,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                  labelText: tr('الرقم الشخصي')),
                              validator: (v) {
                                final d =
                                    (v ?? '').replaceAll(RegExp(r'\D'), '');
                                return d.isEmpty || d.length == 9
                                    ? null
                                    : tr('الرقم الشخصي 9 أرقام');
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              textDirection: TextDirection.ltr,
                              decoration: InputDecoration(
                                  labelText: tr('البريد الإلكتروني')),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue:
                                  bahrainCities.contains(city) ? city : null,
                              isExpanded: true,
                              decoration:
                                  InputDecoration(labelText: tr('المدينة')),
                              items: [
                                for (final c in bahrainCities)
                                  DropdownMenuItem(value: c, child: Text(c)),
                              ],
                              onChanged: (v) => setState(() => city = v),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: zones.contains(area) ? area : null,
                              decoration:
                                  InputDecoration(labelText: tr('المنطقة')),
                              items: [
                                for (final z in zones)
                                  DropdownMenuItem(value: z, child: Text(z)),
                              ],
                              onChanged: (v) => setState(() => area = v),
                            ),
                          ])
                        : Column(children: [
                            _row(Icons.person_outline, 'الاسم',
                                fullName.isEmpty ? '-' : fullName, G.violet),
                            _row(Icons.phone_iphone, 'رقم الهاتف', phone,
                                G.violet,
                                ltr: true),
                            _row(Icons.credit_card_outlined, 'الرقم الشخصي',
                                cpr.text.isEmpty ? '-' : cpr.text, G.violet,
                                ltr: true),
                            _row(Icons.alternate_email, 'البريد الإلكتروني',
                                email.text.isEmpty ? '-' : email.text, G.violet,
                                ltr: true),
                            _row(
                                Icons.location_city_outlined,
                                'المدينة والمنطقة',
                                [city, area]
                                        .where((x) => (x ?? '').isNotEmpty)
                                        .join(' · ')
                                        .isEmpty
                                    ? '-'
                                    : [city, area]
                                        .where((x) => (x ?? '').isNotEmpty)
                                        .join(' · '),
                                G.violet),
                          ]),
                  ),
                  const SizedBox(height: 14),
                  GradientHeaderCard(
                    title: 'عنوان التوصيل',
                    subtitle: 'يُعبّأ تلقائياً عند الطلب',
                    icon: Icons.home_outlined,
                    colors: G.teal,
                    child: editing
                        ? Column(children: [
                            Row(children: [
                              Expanded(
                                  child: Field('المبنى', house,
                                      keyboard: TextInputType.number)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Field('الشقة', flat,
                                      keyboard: TextInputType.number)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Field('طريق', road,
                                      keyboard: TextInputType.number)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Field('مجمع', block,
                                      keyboard: TextInputType.number)),
                            ]),
                            const SizedBox(height: 10),
                            Field('ملاحظة للمندوب', note, maxLines: 2),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: G.teal.first),
                                  onPressed: locating
                                      ? null
                                      : () async {
                                          setState(() => locating = true);
                                          try {
                                            final p = await currentLocation();
                                            if (mounted)
                                              setState(() => pin = p);
                                          } catch (e) {
                                            if (context.mounted) {
                                              toast(context, errText(e),
                                                  error: true);
                                            }
                                          }
                                          if (mounted) {
                                            setState(() => locating = false);
                                          }
                                        },
                                  icon: const Icon(Icons.my_location, size: 18),
                                  label: const Text('موقعي الحالي'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: locating ? null : locate,
                                  icon: const Icon(Icons.travel_explore,
                                      size: 18),
                                  label: const Text('من العنوان'),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            AddressMap(
                                point: pin,
                                height: 220,
                                color: G.teal.first,
                                onPick: (p) => setState(() => pin = p)),
                            const SizedBox(height: 6),
                            const Text('اضغط على الخريطة لتعديل موقع التوصيل',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ])
                        : Column(children: [
                            _row(
                                Icons.signpost_outlined,
                                'العنوان',
                                addressText.isEmpty
                                    ? 'لم يُحفظ بعد'
                                    : addressText,
                                G.teal),
                            if ('${addr?['note'] ?? ''}'.isNotEmpty)
                              _row(Icons.sticky_note_2_outlined, 'ملاحظة',
                                  '${addr!['note']}', G.teal),
                            if (pin != null) ...[
                              const SizedBox(height: 8),
                              AddressMap(
                                  point: pin, height: 190, color: G.teal.first),
                            ],
                          ]),
                  ),
                  if (editing) ...[
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => setState(() {
                                      editing = false;
                                      name.text = fullName;
                                    }),
                            child: const Text('إلغاء')),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                              gradient:
                                  LinearGradient(colors: b.stops.sublist(1)),
                              borderRadius: BorderRadius.circular(14)),
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                minimumSize: const Size.fromHeight(48)),
                            onPressed: saving ? null : save,
                            icon: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_outlined),
                            label: const Text('حفظ التعديلات'),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ]),
          ),
        ),
        const _SupportCard(),
      ]),
    );
  }

  Widget _stat(String k, String v, Color accent) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: .2))),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(v,
                    maxLines: 1,
                    style: TextStyle(
                        color: accent,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            Text(k,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
      );

  Widget _row(IconData icon, String k, String v, List<Color> tone,
          {bool ltr = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: tone.first.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: tone.first),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text(v,
                  textDirection: ltr ? TextDirection.ltr : null,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );
}

/// Support phone and WhatsApp set by the admin in Settings.
class _SupportCard extends StatelessWidget {
  const _SupportCard();
  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: sb
            .from('platform_settings')
            .select('support_phone, support_whatsapp')
            .eq('id', 1)
            .maybeSingle(),
        builder: (context, snap) {
          final s = snap.data;
          final phone = '${s?['support_phone'] ?? ''}';
          final whats = '${s?['support_whatsapp'] ?? ''}';
          if (phone.isEmpty && whats.isEmpty) return const SizedBox.shrink();
          Widget row(IconData i, String label, String v) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(i, size: 18, color: G.violet.first),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(color: Colors.black54)),
                  const Spacer(),
                  SelectableText(v,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: GradientHeaderCard(
                  title: 'التواصل والدعم',
                  subtitle: 'فريق ذبائح في خدمتك',
                  icon: Icons.support_agent_outlined,
                  colors: G.violet,
                  child: Column(children: [
                    if (phone.isNotEmpty)
                      row(Icons.call_outlined, 'هاتف الدعم', phone),
                    if (whats.isNotEmpty)
                      row(Icons.chat_outlined, 'واتساب الدعم', whats),
                  ]),
                ),
              ),
            ),
          );
        },
      );
}
