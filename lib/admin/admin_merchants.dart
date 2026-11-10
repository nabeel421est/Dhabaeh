import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/common.dart';
import '../customer/customer_shell.dart' show StoreLogo;

class AdminMerchants extends StatelessWidget {
  const AdminMerchants({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<(List<Map<String, dynamic>>, Map<String, num>)>(
      realtimeTables: const ['merchants', 'wallet_ledger'],
      load: () async {
        final m = await sb.from('merchants').select('*, merchant_details(owner_name, owner_phone)').order('created_at');
        final w = await sb.from('wallet_ledger').select('merchant_id, amount');
        final bal = <String, num>{};
        for (final r in w) {
          bal[r['merchant_id']] = (bal[r['merchant_id']] ?? 0) + toNum(r['amount']);
        }
        return (List<Map<String, dynamic>>.from(m), bal);
      },
      builder: (context, data, reload) {
        final (list, bal) = data;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(child: Text('${list.length} متجر مسجّل', style: const TextStyle(color: Colors.black54))),
            FilledButton.icon(
              onPressed: () async {
                final added = await showDialog<bool>(context: context, builder: (_) => const AddMerchantDialog());
                if (added == true) await reload();
              },
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('إضافة تاجر'),
            ),
          ]),
          const SizedBox(height: 8),
          const Text('إيقاف: يختفي المتجر من تطبيق العميل ولا يستقبل طلبات جديدة. تجميد: يُقفل المتجر وتُجمَّد محفظته فلا يُصرف منها.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          if (list.isEmpty) const Empty('لا يوجد تجار بعد'),
          for (final m in list)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    StoreLogo(m['logo_url'], size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m['name'], style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('المالك: ${m['merchant_details']?['owner_name'] ?? ''} · ${m['merchant_details']?['owner_phone'] ?? ''}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        Text('${planLabels[m['plan']]} حتى ${dateText(m['plan_ends'])} · الرصيد ${bhd(bal[m['id']] ?? 0)}', style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                    _state(m),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.tonal(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MerchantAdminPage(merchantId: m['id']))),
                      child: const Text('إدارة'),
                    ),
                    OutlinedButton(onPressed: () async { await rename(context, m); await reload(); }, child: const Text('تعديل')),
                    OutlinedButton(
                      onPressed: () async {
                        await guard(context, () => sb.from('merchants').update({'suspended': !(m['suspended'] == true)}).eq('id', m['id']),
                            ok: m['suspended'] == true ? 'تم تفعيل المتجر' : 'تم إيقاف المتجر');
                        await reload();
                      },
                      child: Text(m['suspended'] == true ? 'تفعيل' : 'إيقاف'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await guard(context, () => sb.from('merchants').update({'frozen': !(m['frozen'] == true)}).eq('id', m['id']),
                            ok: m['frozen'] == true ? 'تم فك التجميد' : 'تم تجميد المتجر');
                        await reload();
                      },
                      child: Text(m['frozen'] == true ? 'فك التجميد' : 'تجميد'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8F1D13)),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text('حذف ${m['name']} نهائياً؟'),
                            content: const Text('تُحذف منتجاته وموظفوه ولا يمكن التراجع. يشترط أن يكون رصيد محفظته صفراً وألا يكون له أي طلبات.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                              FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)), onPressed: () => Navigator.pop(c, true), child: const Text('تأكيد الحذف')),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          await guard(context, () => sb.from('merchants').delete().eq('id', m['id']), ok: 'تم حذف المتجر');
                          await reload();
                        }
                      },
                      child: const Text('حذف'),
                    ),
                  ]),
                ]),
              ),
            ),
        ]);
      },
    );
  }

  Widget _state(Map<String, dynamic> m) {
    final (t, c) = m['frozen'] == true
        ? ('مجمّد', const Color(0xFF1D4E89))
        : m['suspended'] == true
            ? ('موقوف', const Color(0xFF8F1D13))
            : m['plan'] == 'trial'
                ? ('تجريبي', const Color(0xFF9A5B13))
                : ('فعال', const Color(0xFF2F5D50));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
      child: Text(t, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
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
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await guard(context, () => sb.from('merchants').update({'name': name.text.trim(), 'store_phone': normPhone(phone.text), 'area': area.text.trim()}).eq('id', m['id']), ok: 'تم الحفظ');
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
      'name', 'owner_name', 'owner_cpr', 'cr_number', 'vat_number', 'health_license', 'owner_phone', 'store_phone',
      'shop_no', 'building', 'road', 'block', 'address_area', 'address_note', 'iban', 'account_name', 'bank_name', 'owner_password', 'description',
    ])
      k: TextEditingController()
  };
  PlatformFile? logo;
  final docs = <String, PlatformFile?>{'doc_id_path': null, 'doc_cr_path': null, 'doc_tax_path': null, 'doc_health_path': null};
  static const docLabels = {'doc_id_path': 'هوية التاجر', 'doc_cr_path': 'السجل التجاري', 'doc_tax_path': 'الشهادة الضريبية', 'doc_health_path': 'الشهادة الصحية'};
  static const docRequired = {'doc_id_path', 'doc_cr_path', 'doc_health_path'};
  String plan = 'trial';
  bool tried = false;
  bool busy = false;

  Future<PlatformFile?> pick(List<String> ext) async {
    final r = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ext);
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
      return usersFn({'action': 'admin_create_merchant', 'merchant': payload, 'owner_password': c['owner_password']!.text});
    }, ok: 'تمت إضافة التاجر');
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) Navigator.pop(context, true);
  }

  Widget f(String k, String label, {bool req = true, String? note, bool ltr = false, TextInputType? kb}) => SizedBox(
        width: 250,
        child: Field(label, c[k]!, required: req, note: note, ltr: ltr, keyboard: kb),
      );

  Widget head(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4B4380))),
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
              const Expanded(child: Text('إضافة تاجر', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
          ),
          Expanded(
            child: Form(
              key: form,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
                const Text('الحقول المعلّمة بـ * إجبارية', style: TextStyle(color: Colors.black54, fontSize: 12)),
                head('بيانات المتجر'),
                Row(children: [
                  StoreLogo(null, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.image_outlined),
                        label: Text(logo?.name ?? 'رفع شعار المتجر * (يظهر للعملاء)'),
                        onPressed: () async { final p = await pick(['png', 'jpg', 'jpeg', 'webp']); if (p != null) setState(() => logo = p); },
                      ),
                      if (tried && logo == null) const Text('الشعار مطلوب', style: TextStyle(color: Color(0xFFB42318), fontSize: 12)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  f('name', 'اسم المتجر', note: 'يظهر للعملاء'),
                  f('store_phone', 'هاتف المتجر', ltr: true, kb: TextInputType.phone),
                  f('owner_name', 'اسم مالك المتجر', note: 'لا يظهر للعملاء'),
                  f('owner_phone', 'هاتف مالك المتجر', ltr: true, kb: TextInputType.phone, note: 'يدخل به المالك للتطبيق'),
                  f('owner_password', 'كلمة مرور مبدئية للمالك', note: 'إذا كان الرقم غير مسجّل'),
                  f('owner_cpr', 'الرقم الشخصي للتاجر', kb: TextInputType.number),
                  f('cr_number', 'رقم السجل التجاري'),
                  f('health_license', 'رقم الترخيص الصحي'),
                  f('vat_number', 'الرقم الضريبي', req: false, note: 'اختياري'),
                ]),
                head('عنوان المتجر'),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  f('shop_no', 'رقم المحل'),
                  f('building', 'المبنى'),
                  f('road', 'الطريق'),
                  f('block', 'المجمع'),
                  f('address_area', 'المنطقة'),
                  f('address_note', 'وصف إضافي للعنوان', req: false, note: 'اختياري'),
                ]),
                head('البيانات البنكية'),
                const Text('تُحوَّل مستحقات التاجر من محفظته إلى هذا الحساب', style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  f('iban', 'رقم الحساب IBAN', ltr: true),
                  f('account_name', 'اسم الحساب'),
                  f('bank_name', 'اسم البنك'),
                ]),
                head('المستندات المرفقة'),
                const Text('صورة أو PDF، للإدارة فقط', style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final k in docs.keys)
                    SizedBox(
                      width: 250,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: tried && docRequired.contains(k) && docs[k] == null ? const Color(0xFFB42318) : const Color(0xFFDDD6CA)),
                        ),
                        icon: Icon(docs[k] == null ? Icons.upload_file : Icons.check_circle, color: docs[k] == null ? null : const Color(0xFF2F5D50)),
                        label: Text(docs[k]?.name ?? '${docLabels[k]}${docRequired.contains(k) ? ' *' : ' (اختياري)'}', overflow: TextOverflow.ellipsis),
                        onPressed: () async { final p = await pick(['png', 'jpg', 'jpeg', 'pdf']); if (p != null) setState(() => docs[k] = p); },
                      ),
                    ),
                ]),
                head('خطة البداية'),
                SegmentedButton<String>(
                  segments: [for (final e in planLabels.entries) ButtonSegment(value: e.key, label: Text(e.value))],
                  selected: {plan},
                  onSelectionChanged: (s) => setState(() => plan = s.first),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'جارٍ الحفظ…' : 'حفظ وإضافة التاجر')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
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
      appBar: AppBar(title: const Text('إدارة المتجر')),
      body: Loader<Map<String, dynamic>>(
        realtimeTables: const ['merchants', 'wallet_ledger'],
        load: () async {
          final m = await sb.from('merchants').select('*, merchant_details(*)').eq('id', merchantId).single();
          final w = await sb.from('wallet_ledger').select().eq('merchant_id', merchantId).order('created_at', ascending: false);
          final staff = await sb.from('merchant_staff').select('title, perms, profiles(full_name, phone)').eq('merchant_id', merchantId);
          return {...m, 'ledger': w, 'staff': staff};
        },
        builder: (context, m, reload) {
          final d = Map<String, dynamic>.from(m['merchant_details'] ?? {});
          final ledger = List<Map<String, dynamic>>.from(m['ledger']);
          final bal = ledger.fold<num>(0, (a, r) => a + toNum(r['amount']));
          final perms = Map<String, dynamic>.from(m['perms'] ?? {});
          final amount = TextEditingController(text: bal > 0 ? bal.toStringAsFixed(3) : '');
          final ref = TextEditingController();
          return ListView(padding: const EdgeInsets.all(16), children: [
            SectionCard(
              title: m['name'],
              child: Column(children: [
                KeyVal('المالك', '${d['owner_name'] ?? ''} · ${d['owner_phone'] ?? ''}'),
                KeyVal('الرقم الشخصي', '${d['owner_cpr'] ?? ''}'),
                KeyVal('السجل التجاري', '${d['cr_number'] ?? ''}'),
                KeyVal('الترخيص الصحي', '${d['health_license'] ?? ''}'),
                KeyVal('الرقم الضريبي', '${d['vat_number'] ?? '-'}'),
                KeyVal('هاتف المتجر', '${m['store_phone']}'),
                KeyVal('العنوان', 'محل ${d['shop_no']}، مبنى ${d['building']}، طريق ${d['road']}، مجمع ${d['block']}، ${d['address_area']}'),
                KeyVal('البنك', '${d['bank_name'] ?? ''} · ${d['account_name'] ?? ''}'),
                KeyVal('IBAN', '${d['iban'] ?? ''}'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final k in _docNames.keys)
                    if (d[k] != null)
                      ActionChip(
                        avatar: const Icon(Icons.description_outlined, size: 18),
                        label: Text(_docNames[k]!),
                        onPressed: () async {
                          final url = await guard(context, () => sb.storage.from('docs').createSignedUrl(d[k], 600));
                          if (url != null && context.mounted) {
                            showDialog(context: context, builder: (_) => AlertDialog(title: Text(_docNames[k]!), content: SelectableText(url)));
                          }
                        },
                      ),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'الاشتراك',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('الخطة الحالية: ${planLabels[m['plan']]} · تنتهي ${dateText(m['plan_ends'])}'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final p in planLabels.entries)
                    OutlinedButton(
                      onPressed: () async {
                        await guard(context, () => sb.rpc('admin_set_plan', params: {'p_merchant': merchantId, 'p_plan': p.key}), ok: 'تم تحديث الخطة');
                        await reload();
                      },
                      child: Text(m['plan'] == p.key ? 'تجديد ${p.value}' : 'تحويل إلى ${p.value}'),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'صلاحيات التاجر',
              child: Column(children: [
                const Text('التاجر يوزّع على موظفيه من هذه الصلاحيات فقط', style: TextStyle(fontSize: 12, color: Colors.black54)),
                for (final e in merchantPermLabels.entries)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value),
                    value: perms[e.key] == true,
                    onChanged: (v) async {
                      await guard(context, () => sb.from('merchants').update({'perms': {...perms, e.key: v}}).eq('id', merchantId));
                      await reload();
                    },
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'محفظة التاجر',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(bhd(bal), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF2F5D50))),
                if (m['frozen'] == true)
                  const Text('المحفظة مجمّدة: لا يمكن الصرف حتى فك تجميد المتجر', style: TextStyle(color: Color(0xFF1D4E89), fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(width: 160, child: Field('مبلغ الصرف', amount, keyboard: const TextInputType.numberWithOptions(decimal: true))),
                  SizedBox(width: 160, child: Field('رقم الحوالة', ref)),
                  FilledButton(
                    onPressed: m['frozen'] == true
                        ? null
                        : () async {
                            await guard(context, () => sb.rpc('admin_payout', params: {'p_merchant': merchantId, 'p_amount': num.tryParse(amount.text) ?? 0, 'p_ref': ref.text}),
                                ok: 'تم تسجيل الصرف');
                            await reload();
                          },
                    child: const Text('صرف وتحويل'),
                  ),
                ]),
                const SizedBox(height: 8),
                for (final r in ledger.take(30))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(r['note'] ?? r['kind']),
                    subtitle: Text(dateTimeText(r['created_at'])),
                    trailing: Text(bhd(r['amount']), textDirection: TextDirection.ltr),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'موظفو المتجر',
              child: Column(children: [
                if ((m['staff'] as List).isEmpty) const Text('لا يوجد موظفون'),
                for (final s in m['staff'] as List)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${s['profiles']?['full_name'] ?? ''} · ${s['title']}'),
                    subtitle: Text(merchantPermLabels.entries.where((e) => s['perms']?[e.key] == true).map((e) => e.value).join('، ')),
                  ),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  static const _docNames = {'doc_id_path': 'هوية التاجر', 'doc_cr_path': 'السجل التجاري', 'doc_tax_path': 'الشهادة الضريبية', 'doc_health_path': 'الشهادة الصحية'};
}
