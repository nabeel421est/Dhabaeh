import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/common.dart';
import '../customer/customer_shell.dart' show StoreLogo;
import '../merchant/merchant_store.dart' show planLook;

class AdminMerchants extends StatelessWidget {
  const AdminMerchants({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<(List<Map<String, dynamic>>, Map<String, num>)>(
      realtimeTables: const ['merchants', 'wallet_ledger'],
      load: () async {
        final m = await sb
            .from('merchants')
            .select('*, merchant_details(owner_name, owner_phone)')
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
          const SizedBox(height: 16),
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
          tooltip: tip,
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تعديل المتجر'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Field('اسم المتجر', name, required: true),
          const SizedBox(height: 10),
          Field('هاتف المتجر', phone, required: true, ltr: true),
          const SizedBox(height: 10),
          Field('المنطقة', area, required: true),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await guard(
          context,
          () => sb.from('merchants').update({
                'name': name.text.trim(),
                'store_phone': normPhone(phone.text),
                'area': area.text.trim()
              }).eq('id', m['id']),
          ok: 'تم الحفظ');
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

  Future<PlatformFile?> pick(List<String> ext) async {
    final r = await FilePicker.platform.pickFiles(
        withData: true, type: FileType.custom, allowedExtensions: ext);
    return r?.files.first;
  }

  Future<void> save() async {
    setState(() => tried = true);
    final okForm = form.currentState!.validate();
    final missingDocs = docRequired.any((k) => docs[k] == null);
    if (!okForm || logo == null || missingDocs) {
      toast(context, 'أكمل الحقول والمستندات الإجبارية', error: true);
      return;
    }
    setState(() => busy = true);
    final r = await guard(context, () async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final logoPath = 'logos/$stamp-${logo!.name}';
      await sb.storage.from('media').uploadBinary(logoPath, logo!.bytes!);
      final payload = <String, dynamic>{
        for (final e in c.entries) e.key: e.value.text.trim(),
        'logo_url': sb.storage.from('media').getPublicUrl(logoPath),
        'plan': plan,
      };
      for (final e in docs.entries) {
        if (e.value == null) continue;
        final path = 'merchants/$stamp/${e.key}-${e.value!.name}';
        await sb.storage.from('docs').uploadBinary(path, e.value!.bytes!);
        payload[e.key] = path;
      }
      payload.remove('owner_password');
      return usersFn({
        'action': 'admin_create_merchant',
        'merchant': payload,
        'owner_password': c['owner_password']!.text
      });
    }, ok: 'تمت إضافة التاجر');
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) Navigator.pop(context, true);
  }

  Widget f(String k, String label,
          {bool req = true,
          String? note,
          bool ltr = false,
          TextInputType? kb}) =>
      SizedBox(
        width: 250,
        child: Field(label, c[k]!,
            required: req, note: note, ltr: ltr, keyboard: kb),
      );

  Widget head(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: Color(0xFF4B4380))),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 860),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(children: [
              const Expanded(
                  child: Text('إضافة تاجر',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700))),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
          ),
          Expanded(
            child: Form(
              key: form,
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    const Text('الحقول المعلّمة بـ * إجبارية',
                        style: TextStyle(color: Colors.black54, fontSize: 12)),
                    head('بيانات المتجر'),
                    Row(children: [
                      StoreLogo(null, size: 64),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.image_outlined),
                                label: Text(logo?.name ??
                                    'رفع شعار المتجر * (يظهر للعملاء)'),
                                onPressed: () async {
                                  final p = await pick(
                                      ['png', 'jpg', 'jpeg', 'webp']);
                                  if (p != null) setState(() => logo = p);
                                },
                              ),
                              if (tried && logo == null)
                                const Text('الشعار مطلوب',
                                    style: TextStyle(
                                        color: Color(0xFFB42318),
                                        fontSize: 12)),
                            ]),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      f('name', 'اسم المتجر', note: 'يظهر للعملاء'),
                      f('store_phone', 'هاتف المتجر',
                          ltr: true, kb: TextInputType.phone),
                      f('owner_name', 'اسم مالك المتجر',
                          note: 'لا يظهر للعملاء'),
                      f('owner_phone', 'هاتف مالك المتجر',
                          ltr: true,
                          kb: TextInputType.phone,
                          note: 'يدخل به المالك للتطبيق'),
                      f('owner_password', 'كلمة مرور مبدئية للمالك',
                          note: 'إذا كان الرقم غير مسجّل'),
                      f('owner_cpr', 'الرقم الشخصي للتاجر',
                          kb: TextInputType.number),
                      f('cr_number', 'رقم السجل التجاري'),
                      f('health_license', 'رقم الترخيص الصحي'),
                      f('vat_number', 'الرقم الضريبي',
                          req: false, note: 'اختياري'),
                    ]),
                    head('عنوان المتجر'),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      f('shop_no', 'رقم المحل'),
                      f('building', 'المبنى'),
                      f('road', 'الطريق'),
                      f('block', 'المجمع'),
                      f('address_area', 'المنطقة'),
                      f('address_note', 'وصف إضافي للعنوان',
                          req: false, note: 'اختياري'),
                    ]),
                    head('البيانات البنكية'),
                    const Text(
                        'تُحوَّل مستحقات التاجر من محفظته إلى هذا الحساب',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      f('iban', 'رقم الحساب IBAN', ltr: true),
                      f('account_name', 'اسم الحساب'),
                      f('bank_name', 'اسم البنك'),
                    ]),
                    head('المستندات المرفقة'),
                    const Text('صورة أو PDF، للإدارة فقط',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      for (final k in docs.keys)
                        SizedBox(
                          width: 250,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: tried &&
                                          docRequired.contains(k) &&
                                          docs[k] == null
                                      ? const Color(0xFFB42318)
                                      : const Color(0xFFDDD6CA)),
                            ),
                            icon: Icon(
                                docs[k] == null
                                    ? Icons.upload_file
                                    : Icons.check_circle,
                                color: docs[k] == null
                                    ? null
                                    : const Color(0xFF2F5D50)),
                            label: Text(
                                docs[k]?.name ??
                                    '${docLabels[k]}${docRequired.contains(k) ? ' *' : ' (اختياري)'}',
                                overflow: TextOverflow.ellipsis),
                            onPressed: () async {
                              final p =
                                  await pick(['png', 'jpg', 'jpeg', 'pdf']);
                              if (p != null) setState(() => docs[k] = p);
                            },
                          ),
                        ),
                    ]),
                    head('خطة البداية'),
                    SegmentedButton<String>(
                      segments: [
                        for (final e in planLabels.entries)
                          ButtonSegment(value: e.key, label: Text(e.value))
                      ],
                      selected: {plan},
                      onSelectionChanged: (s) => setState(() => plan = s.first),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      FilledButton(
                          onPressed: busy ? null : save,
                          child:
                              Text(busy ? 'جارٍ الحفظ…' : 'حفظ وإضافة التاجر')),
                      const SizedBox(width: 8),
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إلغاء')),
                    ]),
                  ]),
            ),
          ),
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
          final daysLeft = ends == null
              ? null
              : ends.difference(DateTime.now()).inDays + 1;
          final frozen = m['frozen'] == true, suspended = m['suspended'] == true;

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
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  ),
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
                          Text(
                              '${m['area'] ?? ''} · ${m['store_phone'] ?? ''}',
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
                  row(Icons.person_outline, 'المالك',
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
                  row(Icons.account_balance_outlined, 'البنك',
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
                        color: G.violet.first.withValues(
                            alpha: perms[e.key] == true ? .3 : .1)),
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
                      child: Text(
                          'لا يمكن الصرف حتى فك تجميد المتجر',
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
                  for (final r in ledger.take(30))
                    _LedgerRow(r: r),
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

          return LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 900;
            const gap = SizedBox(height: 14);
            return ListView(padding: const EdgeInsets.all(16), children: [
              hero,
              gap,
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: Column(children: [info, gap, staffCard])),
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
      required this.onTap});
  final String label;
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
              color: current ? Colors.transparent : g.first.withValues(alpha: .25)),
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
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: current ? Colors.white : g.first)),
                  Text(current ? 'اضغط للتجديد' : 'اضغط للتحويل',
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
