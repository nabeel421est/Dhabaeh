import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import 'package:latlong2/latlong.dart';

import '../core/bg_remove.dart';
import '../core/brand.dart';
import '../core/common.dart';
import '../core/merchant_extras.dart';
import '../customer/customer_shell.dart' show StoreLogo;
import '../merchant/merchant_store.dart' show planLook;
import '../core/ttext.dart';
import '../core/i18n.dart';

class AdminMerchants extends StatelessWidget {
  const AdminMerchants({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<(List<Map<String, dynamic>>, Map<String, num>)>(
      realtimeTables: const ['merchants', 'wallet_ledger', 'merchant_details'],
      load: () async {
        final m = await sb
            .from('merchants')
            .select(
                '*, merchant_details(owner_name, owner_phone, cr_expiry, health_expiry, cpr_expiry)')
            .order('created_at');
        final w = await sb.from('wallet_ledger').select('merchant_id, amount');
        final bal = <String, num>{};
        for (final r in w) {
          bal[r['merchant_id']] =
              (bal[r['merchant_id']] ?? 0) + toNum(r['amount']);
        }
        return (List<Map<String, dynamic>>.from(m), bal);
      },
      builder: (context, data, reload) {
        final (list, bal) = data;
        final suspended = list.where((m) => m['suspended'] == true).length;
        final frozen = list.where((m) => m['frozen'] == true).length;
        final totalBal = bal.values.fold<num>(0, (a, v) => a + v);
        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon: Icons.storefront_outlined,
            title: 'التجار',
            subtitle: 'المسالخ المسجّلة، اشتراكاتها وأرصدتها',
            stats: [
              ('المتاجر', '${list.length}'),
              ('فعّال', '${list.length - suspended - frozen}'),
              ('موقوف', '$suspended'),
              ('مجمّد', '$frozen'),
              ('الأرصدة', bhd(totalBal)),
            ],
            action: HeroButton(
              icon: Icons.add_business_outlined,
              label: 'إضافة تاجر',
              onPressed: () async {
                final added = await showDialog<bool>(
                    context: context,
                    builder: (_) => const AddMerchantDialog());
                if (added == true) await reload();
              },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE1EAF1))),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 18, color: Colors.black45),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                    'إيقاف: يختفي المتجر من تطبيق العميل ولا يستقبل طلبات جديدة. تجميد: يُقفل المتجر وتُجمَّد محفظته فلا يُصرف منها.',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const _ExpiringDocs(),
          const SizedBox(height: 4),
          if (list.isEmpty) const Empty('لا يوجد تجار بعد'),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 360).floor().clamp(1, 3);
            final w = (c.maxWidth - 14 * (cols - 1)) / cols;
            return Wrap(spacing: 14, runSpacing: 14, children: [
              for (final m in list)
                SizedBox(
                    width: w,
                    child:
                        _merchantCard(context, m, bal[m['id']] ?? 0, reload)),
            ]);
          }),
        ]);
      },
    );
  }

  (String, List<Color>) _state(Map<String, dynamic> m) => m['frozen'] == true
      ? ('مجمّد', const [Color(0xFF1C4790), Color(0xFF5FA6F2)])
      : m['suspended'] == true
          ? ('موقوف', const [Color(0xFF8E2442), Color(0xFFE07A86)])
          : m['plan'] == 'trial'
              ? ('تجريبي', const [Color(0xFF9A4A12), Color(0xFFF2A65A)])
              : ('فعّال', const [Color(0xFF0D6152), Color(0xFF3CC4A0)]);

  Widget _merchantCard(BuildContext context, Map<String, dynamic> m,
      num balance, Future<void> Function() reload) {
    final (label, colors) = _state(m);
    // Worst document state: red flag when one expired, amber within 10 days.
    final det = Map<String, dynamic>.from(m['merchant_details'] ?? {});
    int? worst;
    for (final k in ['cr_expiry', 'health_expiry', 'cpr_expiry']) {
      final dt = DateTime.tryParse('${det[k] ?? ''}');
      if (dt == null) continue;
      final now = DateTime.now();
      final left = dt.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (worst == null || left < worst) worst = left;
    }
    final flag = worst == null || worst > 10
        ? null
        : worst < 0
            ? (G.ruby.first, 'وثيقة منتهية')
            : (G.amber.first, 'وثيقة قربت تنتهي');
    Widget info(IconData i, String k, String v) => Expanded(
          child: Row(children: [
            Icon(i, size: 18, color: colors.first),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45)),
                    Text(v,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
            ),
          ]),
        );
    Widget act(IconData i, String tip, VoidCallback onTap, {Color? color}) =>
        IconButton(
          tooltip: tr(tip),
          onPressed: onTap,
          style: IconButton.styleFrom(
              backgroundColor: (color ?? colors.first).withValues(alpha: .08)),
          icon: Icon(i, size: 20, color: color ?? colors.first),
        );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: colors)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: StoreLogo(m['logo_url'], size: 44),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    Text(m['area'] ?? '',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ]),
            ),
            if (flag != null)
              Tooltip(
                message: tr(flag.$2),
                child: Container(
                  margin: const EdgeInsetsDirectional.only(end: 6),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: flag.$1.withValues(alpha: .5), blurRadius: 8)
                      ]),
                  child: Icon(Icons.flag, size: 18, color: flag.$1),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(999)),
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Column(children: [
            Row(children: [
              info(Icons.person_outline, 'المالك',
                  '${m['merchant_details']?['owner_name'] ?? ''}'),
              info(Icons.phone_outlined, 'جوال المالك',
                  '${m['merchant_details']?['owner_phone'] ?? ''}'),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              info(Icons.workspace_premium_outlined, 'الاشتراك',
                  '${planLabels[m['plan']]} حتى ${dateText(m['plan_ends'])}'),
              info(Icons.account_balance_wallet_outlined, 'رصيد المحفظة',
                  bhd(balance)),
            ]),
          ]),
        ),
        const Divider(height: 18),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          child: Row(children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: colors.first,
                  minimumSize: const Size(0, 40)),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MerchantAdminPage(merchantId: m['id']))),
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('إدارة'),
            ),
            const Spacer(),
            act(Icons.edit_outlined, 'تعديل', () async {
              await rename(context, m);
              await reload();
            }),
            const SizedBox(width: 4),
            act(
                m['suspended'] == true
                    ? Icons.play_circle_outline
                    : Icons.pause_circle_outline,
                m['suspended'] == true ? 'تفعيل' : 'إيقاف', () async {
              await guard(
                  context,
                  () => sb
                      .from('merchants')
                      .update({'suspended': !(m['suspended'] == true)}).eq(
                          'id', m['id']),
                  ok: m['suspended'] == true
                      ? 'تم تفعيل المتجر'
                      : 'تم إيقاف المتجر');
              await reload();
            }),
            const SizedBox(width: 4),
            act(m['frozen'] == true ? Icons.lock_open_outlined : Icons.ac_unit,
                m['frozen'] == true ? 'فك التجميد' : 'تجميد', () async {
              await guard(
                  context,
                  () => sb.from('merchants').update(
                      {'frozen': !(m['frozen'] == true)}).eq('id', m['id']),
                  ok: m['frozen'] == true
                      ? 'تم فك التجميد'
                      : 'تم تجميد المتجر');
              await reload();
            }),
            const SizedBox(width: 4),
            act(Icons.delete_outline, 'حذف', () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text('حذف ${m['name']} نهائياً؟'),
                  content: const Text(
                      'تُحذف منتجاته وموظفوه ولا يمكن التراجع. يشترط أن يكون رصيد محفظته صفراً وألا يكون له أي طلبات.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('إلغاء')),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB42318)),
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('تأكيد الحذف')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await guard(context,
                    () => sb.from('merchants').delete().eq('id', m['id']),
                    ok: 'تم حذف المتجر');
                await reload();
              }
            }, color: const Color(0xFFB42318)),
          ]),
        ),
      ]),
    );
  }

  Future<void> rename(BuildContext context, Map<String, dynamic> m) async {
    final name = TextEditingController(text: m['name']);
    final phone = TextEditingController(text: m['store_phone']);
    final area = TextEditingController(text: m['area']);
    final block = TextEditingController();
    String? city = m['address_city'];
    PlatformFile? logo, original;
    bool cut = true, busy = false;
    LatLng? pin = m['lat'] == null
        ? null
        : LatLng(toNum(m['lat']).toDouble(), toNum(m['lng']).toDouble());
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, set) {
        Future<void> apply() async {
          if (original == null) return;
          if (!cut) return set(() => logo = original);
          set(() => busy = true);
          final r = await cutoutFile(original!);
          if (!c.mounted) return;
          set(() {
            busy = false;
            logo = r ?? original;
            if (r == null) cut = false;
          });
        }

        final isCut = logo?.name.endsWith('-cut.png') == true;
        return AlertDialog(
          title: const Text('تعديل المتجر'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: busy
                        ? null
                        : () async {
                            final r = await FilePicker.platform.pickFiles(
                                withData: true,
                                type: FileType.custom,
                                allowedExtensions: [
                                  'png',
                                  'jpg',
                                  'jpeg',
                                  'webp'
                                ]);
                            final f = r?.files.first;
                            if (f?.bytes == null) return;
                            set(() {
                              original = f;
                              logo = f;
                            });
                            await apply();
                          },
                    child: Container(
                      width: 84,
                      height: 84,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: const Color(0xFFE2B866), width: 2)),
                      child: busy
                          ? const Center(
                              child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 3)))
                          : logo?.bytes != null
                              ? Padding(
                                  padding: EdgeInsets.all(isCut ? 6 : 0),
                                  child: Image.memory(logo!.bytes!,
                                      fit:
                                          isCut ? BoxFit.contain : BoxFit.cover,
                                      width: 84,
                                      height: 84))
                              : StoreLogo(m['logo_url'], size: 84),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('شعار المتجر',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const Text('اضغط على الشعار لتغييره',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                          Row(children: [
                            Switch(
                                value: cut,
                                onChanged: busy
                                    ? null
                                    : (v) async {
                                        set(() => cut = v);
                                        await apply();
                                      }),
                            const Flexible(
                                child: Text('إزالة الخلفية تلقائياً',
                                    style: TextStyle(fontSize: 12.5))),
                          ]),
                        ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Field('اسم المتجر', name, required: true),
                const SizedBox(height: 10),
                Field('هاتف المتجر', phone, required: true, ltr: true),
                const SizedBox(height: 10),
                Field('المنطقة', area, required: true),
                const SizedBox(height: 12),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                      'موقع المتجر: اختر المدينة ثم المجمع، ثم اضغط على الخريطة لضبطه. يُستخدم لعرض الطلب على أقرب مندوب.',
                      style: TextStyle(fontSize: 12.5, color: Colors.black54)),
                ),
                const SizedBox(height: 8),
                StoreLocator(
                  city: city,
                  block: block,
                  pin: pin,
                  onCity: (v) => set(() => city = v),
                  onPin: (p) => set(() => pin = p),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: busy ? null : () => Navigator.pop(c, true),
                child: const Text('حفظ')),
          ],
        );
      }),
    );
    if (ok == true && context.mounted) {
      await guard(context, () async {
        String? url;
        if (logo?.bytes != null) {
          final path = 'logos/${safeFileName(logo!.name)}';
          await sb.storage.from('media').uploadBinary(path, logo!.bytes!,
              fileOptions: FileOptions(contentType: mimeOf(logo!.name)));
          url = sb.storage.from('media').getPublicUrl(path);
        }
        await sb.from('merchants').update({
          'name': name.text.trim(),
          'store_phone': normPhone(phone.text),
          'area': area.text.trim(),
          'address_city': city,
          if (url != null) 'logo_url': url,
          if (pin != null) 'lat': pin!.latitude,
          if (pin != null) 'lng': pin!.longitude,
        }).eq('id', m['id']);
      }, ok: 'تم الحفظ');
    }
  }
}

/// Add-merchant popup: store, owner, licences, address, bank details and documents.
class AddMerchantDialog extends StatefulWidget {
  const AddMerchantDialog({super.key});
  @override
  State<AddMerchantDialog> createState() => _AddMerchantDialogState();
}

class _AddMerchantDialogState extends State<AddMerchantDialog> {
  final form = GlobalKey<FormState>();
  final c = {
    for (final k in [
      'name',
      'owner_name',
      'owner_cpr',
      'cr_number',
      'vat_number',
      'health_license',
      'owner_phone',
      'store_phone',
      'shop_no',
      'building',
      'road',
      'block',
      'address_area',
      'address_note',
      'iban',
      'account_name',
      'bank_name',
      'owner_password',
      'description',
    ])
      k: TextEditingController()
  };
  PlatformFile? logo;
  PlatformFile? logoOriginal;
  bool logoCut = true; // remove the logo background automatically
  bool logoBusy = false;
  final docs = <String, PlatformFile?>{
    'doc_id_path': null,
    'doc_cr_path': null,
    'doc_tax_path': null,
    'doc_health_path': null
  };
  static const docLabels = {
    'doc_id_path': 'هوية التاجر',
    'doc_cr_path': 'السجل التجاري',
    'doc_tax_path': 'الشهادة الضريبية',
    'doc_health_path': 'الشهادة الصحية'
  };
  static const docRequired = {'doc_id_path', 'doc_cr_path', 'doc_health_path'};
  String plan = 'trial';
  bool tried = false;
  bool busy = false;
  // Expiry dates of the official documents.
  final expiry = <String, DateTime?>{
    'cpr_expiry': null,
    'cr_expiry': null,
    'health_expiry': null
  };
  Map<String, dynamic> hours = defaultHours();
  String? city;
  LatLng? pin;

  Future<PlatformFile?> pick(List<String> ext) async {
    final r = await FilePicker.platform.pickFiles(
        withData: true, type: FileType.custom, allowedExtensions: ext);
    return r?.files.first;
  }

  Future<void> applyLogo() async {
    final o = logoOriginal;
    if (o == null) return;
    if (!logoCut) return setState(() => logo = o);
    setState(() => logoBusy = true);
    final cut = await cutoutFile(o);
    if (!mounted) return;
    setState(() {
      logoBusy = false;
      logo = cut ?? o;
      if (cut == null) logoCut = false;
    });
  }

  Future<void> save() async {
    if (logoBusy) return;
    setState(() => tried = true);
    final okForm = form.currentState!.validate();
    final missingDocs = docRequired.any((k) => docs[k] == null);
    final missingDates = expiry.values.any((d) => d == null);
    if (!okForm ||
        logo == null ||
        missingDocs ||
        missingDates ||
        city == null) {
      toast(context, 'أكمل الحقول والمستندات الإجبارية', error: true);
      return;
    }
    setState(() => busy = true);
    final r = await guard(context, () async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final logoPath = 'logos/${safeFileName(logo!.name)}';
      await sb.storage.from('media').uploadBinary(logoPath, logo!.bytes!,
          fileOptions: FileOptions(contentType: mimeOf(logo!.name)));
      final payload = <String, dynamic>{
        for (final e in c.entries) e.key: e.value.text.trim(),
        'logo_url': sb.storage.from('media').getPublicUrl(logoPath),
        'plan': plan,
      };
      for (final e in docs.entries) {
        if (e.value == null) continue;
        final path = 'merchants/$stamp/${e.key}-${safeFileName(e.value!.name)}';
        await sb.storage.from('docs').uploadBinary(path, e.value!.bytes!,
            fileOptions: FileOptions(contentType: mimeOf(e.value!.name)));
        payload[e.key] = path;
      }
      payload.remove('owner_password');
      if ('${payload['address_area']}'.isEmpty) payload['address_area'] = city;
      final res = await usersFn({
        'action': 'admin_create_merchant',
        'merchant': payload,
        'owner_password': c['owner_password']!.text
      });
      final mid = res['merchant_id'];
      if (mid != null) {
        await sb.from('merchants').update({
          'work_hours': hours,
          'address_city': city,
          if (pin != null) 'lat': pin!.latitude,
          if (pin != null) 'lng': pin!.longitude,
        }).eq('id', mid);
        await sb.from('merchant_details').update({
          for (final e in expiry.entries)
            e.key: e.value == null ? null : isoDate(e.value!),
        }).eq('merchant_id', mid);
      }
      return res;
    }, ok: 'تمت إضافة التاجر');
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) Navigator.pop(context, true);
  }

  static const _icons = {
    'name': Icons.storefront_outlined,
    'store_phone': Icons.call_outlined,
    'owner_name': Icons.person_outline,
    'owner_phone': Icons.phone_iphone_outlined,
    'owner_password': Icons.lock_outline,
    'owner_cpr': Icons.badge_outlined,
    'cr_number': Icons.assignment_outlined,
    'health_license': Icons.health_and_safety_outlined,
    'vat_number': Icons.receipt_long_outlined,
    'shop_no': Icons.store_mall_directory_outlined,
    'building': Icons.apartment_outlined,
    'road': Icons.add_road_outlined,
    'block': Icons.grid_view_outlined,
    'address_area': Icons.location_on_outlined,
    'address_note': Icons.notes_outlined,
    'iban': Icons.tag,
    'account_name': Icons.account_circle_outlined,
    'bank_name': Icons.account_balance_outlined,
  };
  static const _docIcons = {
    'doc_id_path': Icons.badge_outlined,
    'doc_cr_path': Icons.assignment_outlined,
    'doc_tax_path': Icons.receipt_long_outlined,
    'doc_health_path': Icons.health_and_safety_outlined,
  };
  bool hidePass = true;

  /// One form field styled in the section's colors.
  Widget f(String k, String label, List<Color> tone,
      {bool req = true,
      String? note,
      bool ltr = false,
      TextInputType? kb,
      bool full = false}) {
    final isPass = k == 'owner_password';
    return _Cell(
      full: full,
      child: TextFormField(
        controller: c[k],
        keyboardType: kb,
        obscureText: isPass && hidePass,
        textDirection: ltr ? TextDirection.ltr : null,
        validator:
            req ? (v) => (v ?? '').trim().isEmpty ? tr('مطلوب') : null : null,
        decoration: InputDecoration(
          labelText: tr(req ? '$label *' : label),
          helperText: tr(note),
          prefixIcon: Icon(_icons[k] ?? Icons.edit_outlined, color: tone.first),
          suffixIcon: isPass
              ? IconButton(
                  icon: Icon(hidePass
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => hidePass = !hidePass))
              : null,
          filled: true,
          fillColor: tone.first.withValues(alpha: .04),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tone.first.withValues(alpha: .18))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tone.first, width: 1.6)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  /// An expiry date field for one official document.
  Widget date(String k, String label, List<Color> tone) => _Cell(
        child: DateField(
          label: label,
          value: expiry[k],
          color: tone.first,
          showError: tried,
          onPick: (d) => setState(() => expiry[k] = d),
        ),
      );

  /// A section card: gradient band on top, two-column fields below.
  Widget section(String title, String sub, IconData icon, List<Color> tone,
          List<Widget> kids) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GradientHeaderCard(
          title: title,
          subtitle: sub,
          icon: icon,
          colors: tone,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(builder: (context, box) {
              final two = box.maxWidth >= 520;
              final w = two ? (box.maxWidth - 12) / 2 : box.maxWidth;
              return Wrap(spacing: 12, runSpacing: 14, children: [
                for (final k in kids)
                  SizedBox(
                      width: k is _Cell && k.full ? box.maxWidth : w, child: k),
              ]);
            }),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hero = roleGradients['merchant_owner']!;
    final docsDone = docs.values.where((d) => d != null).length;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      backgroundColor: const Color(0xFFF6F8FA),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 900),
        child: Column(children: [
          // Hero header with the logo picker built in.
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [hero.last, hero.first, const Color(0xFF083D33)]),
            ),
            child: Row(children: [
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () async {
                  final p = await pick(['png', 'jpg', 'jpeg', 'webp']);
                  if (p == null) return;
                  setState(() {
                    logo = p;
                    logoOriginal = p;
                  });
                  await applyLogo();
                },
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: logo != null && logo!.name.endsWith('-cut.png')
                        ? Colors.white
                        : Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: tried && logo == null
                            ? const Color(0xFFFFB4A8)
                            : const Color(0xFFF2D58A),
                        width: 2),
                    image: logo?.bytes == null
                        ? null
                        : DecorationImage(
                            image: MemoryImage(logo!.bytes!),
                            fit: logo!.name.endsWith('-cut.png')
                                ? BoxFit.contain
                                : BoxFit.cover),
                  ),
                  child: logoBusy
                      ? const Center(
                          child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3, color: Color(0xFF0F5C4D))))
                      : logo == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      color: Colors.white, size: 28),
                                  SizedBox(height: 2),
                                  Text('الشعار *',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 11)),
                                ])
                          : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إضافة تاجر',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                          tried && logo == null
                              ? 'ارفع شعار المتجر، يظهر للعملاء'
                              : 'متجر جديد مع حساب مالكه ومستنداته',
                          style: TextStyle(
                              color: tried && logo == null
                                  ? const Color(0xFFFFD2CB)
                                  : Colors.white.withValues(alpha: .85),
                              fontSize: 13)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: logoBusy
                              ? null
                              : () async {
                                  setState(() => logoCut = !logoCut);
                                  await applyLogo();
                                },
                          child: _hp(
                              logoCut
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              logoBusy
                                  ? 'جاري إزالة خلفية الشعار…'
                                  : 'إزالة خلفية الشعار'),
                        ),
                        _hp(Icons.storefront_outlined, 'المتجر'),
                        _hp(Icons.place_outlined, 'العنوان'),
                        _hp(Icons.account_balance_outlined, 'البنك'),
                        _hp(Icons.folder_outlined, 'المستندات $docsDone/4'),
                        _hp(planLook[plan]!.$1, planLabels[plan] ?? ''),
                      ]),
                    ]),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          Expanded(
            child: Form(
              key: form,
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  children: [
                    section(
                        'بيانات المتجر والمالك',
                        'المالك يدخل التطبيق برقم هاتفه',
                        Icons.storefront_outlined,
                        G.emerald, [
                      f('name', 'اسم المتجر', G.emerald, note: 'يظهر للعملاء'),
                      f('store_phone', 'هاتف المتجر', G.emerald,
                          ltr: true, kb: TextInputType.phone),
                      f('owner_name', 'اسم مالك المتجر', G.emerald,
                          note: 'لا يظهر للعملاء'),
                      f('owner_phone', 'هاتف مالك المتجر', G.emerald,
                          ltr: true,
                          kb: TextInputType.phone,
                          note: 'يدخل به المالك للتطبيق'),
                      f('owner_cpr', 'الرقم الشخصي للتاجر', G.emerald,
                          kb: TextInputType.number),
                      date(
                          'cpr_expiry', 'تاريخ انتهاء الرقم الشخصي', G.emerald),
                      f('owner_password', 'كلمة مرور مبدئية للمالك', G.emerald,
                          note: 'إذا كان الرقم غير مسجّل'),
                    ]),
                    section(
                        'السجلات الرسمية',
                        'السجل التجاري والترخيص الصحي وتواريخ انتهائها',
                        Icons.verified_outlined,
                        G.teal, [
                      f('cr_number', 'رقم السجل التجاري', G.teal),
                      date('cr_expiry', 'تاريخ انتهاء السجل التجاري', G.teal),
                      f('health_license', 'رقم الترخيص الصحي', G.teal),
                      date('health_expiry', 'تاريخ انتهاء الترخيص الصحي',
                          G.teal),
                      f('vat_number', 'الرقم الضريبي', G.teal,
                          req: false, note: 'اختياري'),
                      _Cell(
                        full: true,
                        child: Text(
                            'تُنبَّه الإدارة قبل 10 أيام من انتهاء أي وثيقة، ويظهر علم أحمر في تطبيق التاجر عند الانتهاء.',
                            style:
                                TextStyle(fontSize: 12.5, color: G.teal.first)),
                      ),
                    ]),
                    section(
                        'أوقات العمل الرسمية',
                        'مواعيد فتح وإغلاق المحل لكل يوم',
                        Icons.schedule_outlined,
                        G.sapphire, [
                      _Cell(
                        full: true,
                        child: WorkHoursEditor(
                            value: hours,
                            onChanged: (v) => setState(() => hours = v)),
                      ),
                    ]),
                    section(
                        'عنوان المتجر',
                        'اختر المدينة ثم المجمع، وحدد المحل على الخريطة',
                        Icons.place_outlined,
                        G.amber, [
                      _Cell(
                        full: true,
                        child: StoreLocator(
                          city: city,
                          block: c['block']!,
                          road: c['road'],
                          building: c['building'],
                          pin: pin,
                          onCity: (v) => setState(() => city = v),
                          onPin: (p) => setState(() => pin = p),
                        ),
                      ),
                      if (tried && city == null)
                        _Cell(
                            full: true,
                            child: Text('اختر المدينة',
                                style: TextStyle(color: G.ruby.first))),
                      f('shop_no', 'رقم المحل', G.amber),
                      f('building', 'المبنى', G.amber),
                      f('road', 'الطريق', G.amber),
                      f('address_area', 'المنطقة أو الحي', G.amber,
                          req: false, note: 'اختياري'),
                      f('address_note', 'وصف إضافي للعنوان', G.amber,
                          req: false, note: 'اختياري', full: true),
                    ]),
                    section(
                        'البيانات البنكية',
                        'تُحوَّل مستحقات التاجر من محفظته إلى هذا الحساب',
                        Icons.account_balance_outlined,
                        G.sapphire, [
                      f('iban', 'رقم الحساب IBAN', G.sapphire,
                          ltr: true, full: true),
                      f('account_name', 'اسم الحساب', G.sapphire),
                      f('bank_name', 'اسم البنك', G.sapphire),
                    ]),
                    section('المستندات المرفقة', 'صورة أو PDF، للإدارة فقط',
                        Icons.folder_outlined, G.violet, [
                      for (final k in docs.keys)
                        _DocPick(
                          label: docLabels[k]!,
                          icon: _docIcons[k]!,
                          file: docs[k]?.name,
                          required: docRequired.contains(k),
                          missing: tried &&
                              docRequired.contains(k) &&
                              docs[k] == null,
                          onTap: () async {
                            final p = await pick(['png', 'jpg', 'jpeg', 'pdf']);
                            if (p != null) setState(() => docs[k] = p);
                          },
                        ),
                    ]),
                    section(
                        'خطة البداية',
                        'يمكن تغييرها لاحقاً من إدارة المتجر',
                        Icons.workspace_premium_outlined,
                        G.gold, [
                      for (final e in planLabels.entries)
                        _PlanChoice(
                          label: e.value,
                          look: planLook[e.key] ?? planLook['monthly']!,
                          current: plan == e.key,
                          hint: plan == e.key
                              ? 'الخطة المختارة'
                              : 'اضغط للاختيار',
                          onTap: () => setState(() => plan = e.key),
                        ),
                    ]),
                  ]),
            ),
          ),
          // Sticky footer
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                  top: BorderSide(color: hero.first.withValues(alpha: .12))),
            ),
            child: Row(children: [
              Expanded(
                flex: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: [hero.first, hero.last]),
                    boxShadow: [
                      BoxShadow(
                          color: hero.first.withValues(alpha: .35),
                          blurRadius: 14,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: busy ? null : save,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_business_outlined),
                    label: Text(busy ? 'جارٍ الحفظ…' : 'حفظ وإضافة التاجر',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: hero.first,
                    side: BorderSide(color: hero.first.withValues(alpha: .4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  static Widget _hp(IconData i, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: .3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(t,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Admin list: documents that expired or expire within 10 days, with a
/// button to ask the store for the renewed copy.
class _ExpiringDocs extends StatelessWidget {
  const _ExpiringDocs();
  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
        realtimeTables: const ['merchant_details'],
        load: () async => List<Map<String, dynamic>>.from(
            await sb.rpc('admin_expiring_docs') ?? []),
        builder: (context, rows, reload) {
          if (rows.isEmpty) return const SizedBox.shrink();
          final expired = rows.where((r) => toNum(r['days_left']) < 0).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GradientHeaderCard(
              title: 'وثائق تحتاج تجديد',
              subtitle: expired > 0
                  ? '${tr('منتهية')}: $expired · ${tr('تنتهي خلال 10 أيام')}: ${rows.length - expired}'
                  : '${tr('تنتهي خلال 10 أيام')}: ${rows.length}',
              icon: Icons.flag,
              colors: expired > 0 ? G.ruby : G.amber,
              child: Column(children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Icon(Icons.flag,
                          color: toNum(r['days_left']) < 0
                              ? G.ruby.first
                              : G.amber.first),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${r['merchant_name']} · ${tr('${r['label']}')}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  '${expiryState(r['expiry']).$1} (${dateText(r['expiry'])})',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                            ]),
                      ),
                      TextButton.icon(
                        onPressed: () => guard(
                            context,
                            () => sb.rpc('admin_request_doc_renewal', params: {
                                  'p_merchant': r['merchant_id'],
                                  'p_doc': r['doc']
                                }),
                            ok: 'تم إرسال طلب التجديد للتاجر'),
                        icon: const Icon(Icons.send_outlined, size: 18),
                        label: const Text('طلب التجديد'),
                      ),
                    ]),
                  ),
              ]),
            ),
          );
        },
      );
}

/// Coloured pill with a document's expiry state.
class _ExpiryPill extends StatelessWidget {
  const _ExpiryPill(this.date);
  final dynamic date;
  @override
  Widget build(BuildContext context) {
    final st = expiryState(date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: st.$2.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: st.$2.withValues(alpha: .35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.flag, size: 14, color: st.$2),
        const SizedBox(width: 4),
        Text(st.$1,
            style: TextStyle(
                color: st.$2, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Marks a field that spans both columns of a section.
class _Cell extends StatelessWidget {
  const _Cell({required this.child, this.full = false});
  final Widget child;
  final bool full;
  @override
  Widget build(BuildContext context) => child;
}

/// A document upload tile: violet tint when empty, emerald gradient once a file is chosen.
class _DocPick extends StatelessWidget {
  const _DocPick(
      {required this.label,
      required this.icon,
      required this.file,
      required this.required,
      required this.missing,
      required this.onTap});
  final String label;
  final IconData icon;
  final String? file;
  final bool required, missing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final done = file != null;
    final g = done ? G.emerald : G.violet;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: done
              ? LinearGradient(colors: g)
              : LinearGradient(colors: [
                  g.first.withValues(alpha: .05),
                  g.last.withValues(alpha: .12)
                ]),
          border: Border.all(
              color: missing
                  ? const Color(0xFFB42318)
                  : done
                      ? Colors.transparent
                      : g.first.withValues(alpha: .25),
              width: missing ? 1.6 : 1),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: done
                  ? Colors.white.withValues(alpha: .22)
                  : g.first.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: done ? Colors.white : g.first, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$label${required ? ' *' : ''}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: done ? Colors.white : Colors.black87)),
              Text(
                  file ??
                      (missing
                          ? 'مطلوب، اضغط للرفع'
                          : required
                              ? 'اضغط للرفع'
                              : 'اختياري، اضغط للرفع'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: file != null ? TextDirection.ltr : null,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: done
                          ? Colors.white.withValues(alpha: .85)
                          : missing
                              ? const Color(0xFFB42318)
                              : Colors.black54)),
            ]),
          ),
          Icon(done ? Icons.check_circle : Icons.cloud_upload_outlined,
              color: done ? Colors.white : g.first.withValues(alpha: .6)),
        ]),
      ),
    );
  }
}

class MerchantAdminPage extends StatelessWidget {
  const MerchantAdminPage({super.key, required this.merchantId});
  final String merchantId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: const Text('إدارة المتجر')),
      body: Loader<Map<String, dynamic>>(
        realtimeTables: const ['merchants', 'wallet_ledger'],
        load: () async {
          final m = await sb
              .from('merchants')
              .select('*, merchant_details(*)')
              .eq('id', merchantId)
              .single();
          final w = await sb
              .from('wallet_ledger')
              .select()
              .eq('merchant_id', merchantId)
              .order('created_at', ascending: false);
          final staff = await sb
              .from('merchant_staff')
              .select('title, perms, profiles(full_name, phone)')
              .eq('merchant_id', merchantId);
          return {...m, 'ledger': w, 'staff': staff};
        },
        builder: (context, m, reload) {
          final d = Map<String, dynamic>.from(m['merchant_details'] ?? {});
          final ledger = List<Map<String, dynamic>>.from(m['ledger']);
          final staff = List<Map<String, dynamic>>.from(m['staff']);
          final bal = ledger.fold<num>(0, (a, r) => a + toNum(r['amount']));
          final perms = Map<String, dynamic>.from(m['perms'] ?? {});
          final amount = TextEditingController(
              text: bal > 0 ? bal.toStringAsFixed(3) : '');
          final ref = TextEditingController();
          final ends = DateTime.tryParse('${m['plan_ends']}');
          final daysLeft =
              ends == null ? null : ends.difference(DateTime.now()).inDays + 1;
          final frozen = m['frozen'] == true,
              suspended = m['suspended'] == true;

          Widget row(IconData icon, String k, String v, List<Color> c,
                  {bool ltr = false}) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: c.first.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, size: 18, color: c.first),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                          Text(v.trim().isEmpty || v == 'null' ? '-' : v,
                              textDirection: ltr ? TextDirection.ltr : null,
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w600)),
                        ]),
                  ),
                  if (_expKey(k) != null) _ExpiryPill(d[_expKey(k)]),
                ]),
              );

          // ------------------------------------------------ hero
          final heroTone = suspended
              ? G.ruby
              : frozen
                  ? G.sapphire
                  : G.emerald;
          final hero = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [heroTone.first, heroTone.last]),
              boxShadow: [
                BoxShadow(
                    color: heroTone.first.withValues(alpha: .35),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Wrap(
              spacing: 20,
              runSpacing: 16,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(colors: [
                          const Color(0xFFE2B866),
                          Colors.white,
                          const Color(0xFFE2B866)
                        ])),
                    child: StoreLogo(m['logo_url'], size: 68),
                  ),
                  const SizedBox(width: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${m['name']}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800)),
                          Text('${m['area'] ?? ''} · ${m['store_phone'] ?? ''}',
                              style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            _heroPill(
                                suspended
                                    ? 'موقوف'
                                    : m['is_open'] == true
                                        ? 'مفتوح للطلبات'
                                        : 'مغلق حالياً',
                                suspended
                                    ? Icons.block
                                    : Icons.storefront_outlined),
                            if (frozen)
                              _heroPill('المحفظة مجمّدة', Icons.ac_unit),
                            _heroPill(
                                'باقة ${planLabels[m['plan']] ?? ''}',
                                (planLook[m['plan']] ?? planLook['monthly']!)
                                    .$1),
                          ]),
                        ]),
                  ),
                ]),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _heroStat('رصيد المحفظة', bhd(bal)),
                  _heroStat('متبقي على الاشتراك',
                      daysLeft == null ? '-' : '$daysLeft يوم'),
                  _heroStat('الموظفون', '${staff.length}'),
                ]),
              ],
            ),
          );

          // ------------------------------------------------ cards
          final info = GradientHeaderCard(
            title: 'بيانات المتجر والمالك',
            subtitle: 'السجلات الرسمية والعنوان والحساب البنكي',
            icon: Icons.badge_outlined,
            colors: G.sapphire,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  row(
                      Icons.person_outline,
                      'المالك',
                      '${d['owner_name'] ?? ''} · ${d['owner_phone'] ?? ''}',
                      G.sapphire),
                  row(Icons.credit_card_outlined, 'الرقم الشخصي',
                      '${d['owner_cpr'] ?? ''}', G.sapphire,
                      ltr: true),
                  row(Icons.assignment_outlined, 'السجل التجاري',
                      '${d['cr_number'] ?? ''}', G.sapphire),
                  row(Icons.health_and_safety_outlined, 'الترخيص الصحي',
                      '${d['health_license'] ?? ''}', G.sapphire),
                  row(Icons.receipt_long_outlined, 'الرقم الضريبي',
                      '${d['vat_number'] ?? '-'}', G.sapphire),
                  row(
                      Icons.location_on_outlined,
                      'العنوان',
                      'محل ${d['shop_no'] ?? ''}، مبنى ${d['building'] ?? ''}، طريق ${d['road'] ?? ''}، مجمع ${d['block'] ?? ''}، ${d['address_area'] ?? ''}',
                      G.sapphire),
                  row(
                      Icons.account_balance_outlined,
                      'البنك',
                      '${d['bank_name'] ?? ''} · ${d['account_name'] ?? ''}',
                      G.sapphire),
                  row(Icons.numbers, 'IBAN', '${d['iban'] ?? ''}', G.sapphire,
                      ltr: true),
                  const SizedBox(height: 4),
                  const Text('المستندات',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final k in _docNames.keys)
                      _DocTile(
                        label: _docNames[k]!,
                        available: d[k] != null,
                        onTap: d[k] == null
                            ? null
                            : () async {
                                final url = await guard(
                                    context,
                                    () => sb.storage
                                        .from('docs')
                                        .createSignedUrl(d[k], 600));
                                if (url != null && context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: Text(_docNames[k]!),
                                      content: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            maxWidth: 560, maxHeight: 640),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Image.network(url,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) =>
                                                  SelectableText(url)),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(c),
                                            child: const Text('إغلاق'))
                                      ],
                                    ),
                                  );
                                }
                              },
                      ),
                  ]),
                ]),
          );

          final plan = GradientHeaderCard(
            title: 'الاشتراك',
            subtitle:
                'الباقة الحالية ${planLabels[m['plan']] ?? ''} · تنتهي ${dateText(m['plan_ends'])}',
            icon: Icons.workspace_premium_outlined,
            colors: G.gold,
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth < 420 ? c.maxWidth : (c.maxWidth - 16) / 3;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in planLabels.entries)
                  SizedBox(
                    width: w,
                    child: _PlanChoice(
                      label: p.value,
                      look: planLook[p.key] ?? planLook['monthly']!,
                      current: m['plan'] == p.key,
                      onTap: () async {
                        await guard(
                            context,
                            () => sb.rpc('admin_set_plan', params: {
                                  'p_merchant': merchantId,
                                  'p_plan': p.key
                                }),
                            ok: 'تم تحديث الخطة');
                        await reload();
                      },
                    ),
                  ),
              ]);
            }),
          );

          final permsCard = GradientHeaderCard(
            title: 'صلاحيات التاجر',
            subtitle: 'التاجر يوزّع على موظفيه من هذه الصلاحيات فقط',
            icon: Icons.tune,
            colors: G.violet,
            child: Column(children: [
              for (final e in merchantPermLabels.entries)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: perms[e.key] == true
                        ? G.violet.first.withValues(alpha: .07)
                        : null,
                    border: Border.all(
                        color: G.violet.first
                            .withValues(alpha: perms[e.key] == true ? .3 : .1)),
                  ),
                  child: SwitchListTile(
                    dense: true,
                    activeThumbColor: G.violet.first,
                    title: Text(e.value,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: perms[e.key] == true,
                    onChanged: (v) async {
                      await guard(
                          context,
                          () => sb.from('merchants').update({
                                'perms': {...perms, e.key: v}
                              }).eq('id', merchantId));
                      await reload();
                    },
                  ),
                ),
            ]),
          );

          final wallet = GradientHeaderCard(
            title: 'محفظة التاجر',
            subtitle: 'الرصيد بعد العمولة ورسوم التوصيل',
            icon: Icons.account_balance_wallet_outlined,
            colors: G.emerald,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(colors: [
                          G.emerald.first.withValues(alpha: .1),
                          G.emerald.last.withValues(alpha: .18)
                        ])),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الرصيد المتاح',
                                  style: TextStyle(color: Colors.black54)),
                              ShaderMask(
                                shaderCallback: (r) =>
                                    LinearGradient(colors: G.emerald)
                                        .createShader(r),
                                child: Text(bhd(bal),
                                    style: const TextStyle(
                                        fontSize: 28,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ]),
                      ),
                      if (frozen)
                        _softPill('مجمّدة', Icons.ac_unit, G.sapphire.first),
                    ]),
                  ),
                  if (frozen)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('لا يمكن الصرف حتى فك تجميد المتجر',
                          style: TextStyle(
                              color: G.sapphire.first,
                              fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: Field('مبلغ الصرف', amount,
                            ltr: true,
                            keyboard: const TextInputType.numberWithOptions(
                                decimal: true))),
                    const SizedBox(width: 8),
                    Expanded(child: Field('رقم الحوالة', ref)),
                  ]),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: G.emerald.first,
                        minimumSize: const Size.fromHeight(48)),
                    onPressed: frozen
                        ? null
                        : () async {
                            await guard(
                                context,
                                () => sb.rpc('admin_payout', params: {
                                      'p_merchant': merchantId,
                                      'p_amount':
                                          num.tryParse(amount.text) ?? 0,
                                      'p_ref': ref.text
                                    }),
                                ok: 'تم تسجيل الصرف');
                            await reload();
                          },
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: const Text('صرف وتحويل'),
                  ),
                  const SizedBox(height: 14),
                  const Text('آخر الحركات',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  if (ledger.isEmpty)
                    const Text('لا توجد حركات بعد',
                        style: TextStyle(color: Colors.black54)),
                  for (final r in ledger.take(30)) _LedgerRow(r: r),
                ]),
          );

          final staffCard = GradientHeaderCard(
            title: 'موظفو المتجر',
            subtitle: '${staff.length} موظف',
            icon: Icons.groups_outlined,
            colors: G.teal,
            child: Column(children: [
              if (staff.isEmpty)
                const Text('لا يوجد موظفون',
                    style: TextStyle(color: Colors.black54)),
              for (final s in staff)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    GradientBadge(
                        colors: G.teal,
                        text: '${s['profiles']?['full_name'] ?? '?'}'
                                .characters
                                .firstOrNull ??
                            '?',
                        size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${s['profiles']?['full_name'] ?? ''} · ${s['title'] ?? ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(
                                merchantPermLabels.entries
                                    .where((e) => s['perms']?[e.key] == true)
                                    .map((e) => e.value)
                                    .join('، '),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ]),
                    ),
                  ]),
                ),
            ]),
          );

          // ------------------------------------------------ documents & hours
          final soon = [
            for (final e in _expDocs)
              if (d[e.$2] != null &&
                  DateTime.parse('${d[e.$2]}')
                          .difference(DateTime.now())
                          .inDays <
                      10)
                e
          ];
          final hoursCard = GradientHeaderCard(
            title: 'أوقات العمل وصلاحية الوثائق',
            subtitle: 'تنبيه الإدارة قبل 10 أيام من انتهاء أي وثيقة',
            icon: Icons.schedule_outlined,
            colors: G.teal,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in _expDocs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Icon(e.$3, size: 18, color: G.teal.first),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e.$1)),
                        _ExpiryPill(d[e.$2]),
                      ]),
                    ),
                  for (final e in soon)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: G.ruby.first),
                        onPressed: () => guard(
                            context,
                            () => sb.rpc('admin_request_doc_renewal', params: {
                                  'p_merchant': merchantId,
                                  'p_doc': e.$4
                                }),
                            ok: 'تم إرسال طلب التجديد للتاجر'),
                        icon: const Icon(Icons.send_outlined, size: 18),
                        label:
                            Text('${tr('اطلب من التاجر تجديد')} ${tr(e.$1)}'),
                      ),
                    ),
                  const Divider(height: 20),
                  const Text('أوقات العمل الرسمية',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  WorkHoursView(hours: m['work_hours']),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: G.teal.first),
                    onPressed: () async {
                      if (await _editDocsHours(context, m, d) == true) {
                        reload();
                      }
                    },
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: const Text('تعديل التواريخ وأوقات العمل'),
                  ),
                ]),
          );

          return LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 900;
            const gap = SizedBox(height: 14);
            return ListView(padding: const EdgeInsets.all(16), children: [
              hero,
              gap,
              DocAlertsBanner(
                  key: ValueKey(
                      '${d['cr_expiry']}${d['health_expiry']}${d['cpr_expiry']}'),
                  merchantId: merchantId),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: Column(
                          children: [info, gap, hoursCard, gap, staffCard])),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          children: [wallet, gap, plan, gap, permsCard])),
                ])
              else ...[
                wallet,
                gap,
                plan,
                gap,
                info,
                gap,
                hoursCard,
                gap,
                permsCard,
                gap,
                staffCard,
              ],
            ]);
          });
        },
      ),
    );
  }

  /// Official documents: label, expiry column, icon, doc code.
  static const _expDocs = [
    ('السجل التجاري', 'cr_expiry', Icons.assignment_outlined, 'cr'),
    (
      'الترخيص الصحي',
      'health_expiry',
      Icons.health_and_safety_outlined,
      'health'
    ),
    ('الرقم الشخصي للتاجر', 'cpr_expiry', Icons.credit_card_outlined, 'cpr'),
  ];
  static String? _expKey(String rowLabel) => switch (rowLabel) {
        'الرقم الشخصي' => 'cpr_expiry',
        'السجل التجاري' => 'cr_expiry',
        'الترخيص الصحي' => 'health_expiry',
        _ => null,
      };

  /// Edit the three expiry dates and the official working hours.
  static Future<bool?> _editDocsHours(
      BuildContext context, Map<String, dynamic> m, Map<String, dynamic> d) {
    final dates = {
      for (final e in _expDocs) e.$2: DateTime.tryParse('${d[e.$2] ?? ''}')
    };
    var hours = hoursOf(m['work_hours']);
    return showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('تواريخ الوثائق وأوقات العمل'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final e in _expDocs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DateField(
                      label: '${tr('تاريخ انتهاء')} ${tr(e.$1)}',
                      value: dates[e.$2],
                      color: G.teal.first,
                      onPick: (v) => set(() => dates[e.$2] = v),
                    ),
                  ),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('أوقات العمل الرسمية',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                WorkHoursEditor(
                    value: hours, onChanged: (v) => set(() => hours = v)),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final ok = await guard(c, () async {
                  await sb.from('merchant_details').update({
                    for (final e in dates.entries)
                      e.key: e.value == null ? null : isoDate(e.value!),
                  }).eq('merchant_id', m['id']);
                  await sb
                      .from('merchants')
                      .update({'work_hours': hours}).eq('id', m['id']);
                  return true;
                }, ok: 'تم الحفظ');
                if (ok == true && c.mounted) Navigator.pop(c, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _heroPill(String t, IconData i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: .3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(t,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  static Widget _heroStat(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .22))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(k,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(v,
                  style: const TextStyle(
                      color: Color(0xFFFFE6A8),
                      fontSize: 19,
                      fontWeight: FontWeight.w800)),
            ]),
      );

  static Widget _softPill(String t, IconData i, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: c.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 14, color: c),
          const SizedBox(width: 4),
          Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w700)),
        ]),
      );

  static const _docNames = {
    'doc_id_path': 'هوية التاجر',
    'doc_cr_path': 'السجل التجاري',
    'doc_tax_path': 'الشهادة الضريبية',
    'doc_health_path': 'الشهادة الصحية'
  };
}

class _DocTile extends StatelessWidget {
  const _DocTile(
      {required this.label, required this.available, required this.onTap});
  final String label;
  final bool available;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = available ? G.sapphire : [Colors.grey, Colors.grey.shade400];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: available
              ? LinearGradient(colors: [
                  c.first.withValues(alpha: .08),
                  c.last.withValues(alpha: .16)
                ])
              : null,
          border: Border.all(color: c.first.withValues(alpha: .25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(available ? Icons.description_outlined : Icons.do_not_disturb,
              size: 18, color: c.first),
          const SizedBox(width: 6),
          Text(available ? label : '$label (غير مرفق)',
              style: TextStyle(
                  color: c.first, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }
}

class _PlanChoice extends StatelessWidget {
  const _PlanChoice(
      {required this.label,
      required this.look,
      required this.current,
      required this.onTap,
      this.hint});
  final String label;
  final String? hint;
  final (IconData, List<Color>) look;
  final bool current;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final (icon, g) = look;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: current
              ? LinearGradient(colors: g)
              : LinearGradient(colors: [
                  g.first.withValues(alpha: .06),
                  g.last.withValues(alpha: .14)
                ]),
          border: Border.all(
              color: current
                  ? Colors.transparent
                  : g.first.withValues(alpha: .25)),
          boxShadow: current
              ? [
                  BoxShadow(
                      color: g.first.withValues(alpha: .3),
                      blurRadius: 12,
                      offset: const Offset(0, 5))
                ]
              : null,
        ),
        child: Row(children: [
          Icon(icon, color: current ? Colors.white : g.first),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: current ? Colors.white : g.first)),
              Text(hint ?? (current ? 'اضغط للتجديد' : 'اضغط للتحويل'),
                  style: TextStyle(
                      fontSize: 11.5,
                      color: current ? Colors.white70 : Colors.black54)),
            ]),
          ),
          if (current)
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
        ]),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.r});
  final Map<String, dynamic> r;
  @override
  Widget build(BuildContext context) {
    final a = toNum(r['amount']);
    final g = a >= 0 ? G.emerald : G.ruby;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: g.first.withValues(alpha: .1)),
          child: Icon(a >= 0 ? Icons.south_west : Icons.north_east,
              size: 16, color: g.first),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['note'] ?? r['kind']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(dateTimeText(r['created_at']),
                style: const TextStyle(fontSize: 11.5, color: Colors.black45)),
          ]),
        ),
        Text('${a >= 0 ? '+' : '−'}${bhd(a.abs())}',
            textDirection: TextDirection.ltr,
            style: TextStyle(fontWeight: FontWeight.w800, color: g.first)),
      ]),
    );
  }
}
