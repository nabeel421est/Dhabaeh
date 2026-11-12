import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/common.dart';
import '../core/i18n.dart';
import '../core/ttext.dart';
import '../core/tap_pay.dart';

/// What each kind of method does in an order.
const payKinds = <String, (String, String, List<Color>)>{
  'cash': (
    'نقداً عند الاستلام',
    'يدفع العميل للمندوب أو للمحل عند الاستلام، ويُسجَّل المبلغ بحوزة المندوب',
    G.amber
  ),
  'bank_transfer': (
    'تحويل مع إيصال',
    'يحوّل العميل ويرفع الإيصال، وتراجعه الإدارة',
    G.sapphire
  ),
  'benefitpay': (
    'دفع إلكتروني',
    'يدفع العميل من تطبيق أو محفظة إلكترونية قبل التنفيذ',
    G.emerald
  ),
};

/// Icons a method can use. Kept const so the icon font keeps them.
const payIcons = <String, IconData>{
  'payments': Icons.payments_outlined,
  'cash': Icons.money_outlined,
  'bank': Icons.account_balance_outlined,
  'phone': Icons.phone_iphone,
  'card': Icons.credit_card,
  'wallet': Icons.account_balance_wallet_outlined,
  'qr': Icons.qr_code_2,
  'apple': Icons.apple,
  'link': Icons.link,
  'receipt': Icons.receipt_long_outlined,
};

IconData payIcon(dynamic key) => payIcons['$key'] ?? Icons.payments_outlined;

/// «وسائل الدفع»: every way customers can pay, with add, edit, stop, order and delete.
class AdminPaymentMethods extends StatelessWidget {
  const AdminPaymentMethods({super.key});

  Future<void> save(BuildContext context, Map<String, dynamic> data,
      Future<void> Function() reload,
      {String ok = 'تم الحفظ'}) async {
    final r = await guard(
        context, () => sb.rpc('admin_save_payment_method', params: {'p': data}),
        ok: ok);
    if (r != null) await reload();
  }

  Future<void> edit(BuildContext context, Map<String, dynamic>? m,
      Future<void> Function() reload) async {
    final form = GlobalKey<FormState>();
    final c = {
      for (final k in [
        'name',
        'name_en',
        'description',
        'account',
        'instructions'
      ])
        k: TextEditingController(text: '${m?[k] ?? ''}'),
    };
    String kind = '${m?['kind'] ?? 'bank_transfer'}';
    String icon = '${m?['icon'] ?? 'payments'}';
    bool active = m?['active'] != false;
    bool del = m?['for_delivery'] != false;
    bool pick = m?['for_pickup'] != false;
    final builtin = m?['builtin'] == true;
    bool tap = m?['gateway'] == 'tap';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final tone = payKinds[kind]!.$3;
        return AlertDialog(
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: tone),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22))),
            child: Row(children: [
              Icon(payIcon(icon), color: Colors.white),
              const SizedBox(width: 10),
              Text(m == null ? 'وسيلة دفع جديدة' : 'تعديل وسيلة الدفع',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Field('اسم وسيلة الدفع', c['name']!,
                          required: true, hint: 'مثل: Apple Pay أو ستي باي'),
                      const SizedBox(height: 10),
                      Field('الاسم بالإنجليزي', c['name_en']!, ltr: true),
                      const SizedBox(height: 12),
                      const Text('طريقة عملها',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      for (final e in payKinds.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap:
                                builtin ? null : () => set(() => kind = e.key),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: kind == e.key
                                    ? e.value.$3.first.withValues(alpha: .1)
                                    : null,
                                border: Border.all(
                                    color: kind == e.key
                                        ? e.value.$3.first
                                        : Colors.black12,
                                    width: kind == e.key ? 1.6 : 1),
                              ),
                              child: Row(children: [
                                Icon(
                                    kind == e.key
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: e.value.$3.first),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(e.value.$1,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        Text(e.value.$2,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54)),
                                      ]),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      if (builtin)
                        const Text('طريقة عمل الوسائل الأساسية ثابتة.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black45)),
                      if (kind == 'benefitpay' && !builtin) ...[
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .04),
                              borderRadius: BorderRadius.circular(14)),
                          child: SwitchListTile(
                              value: tap,
                              onChanged: (v) => set(() => tap = v),
                              secondary: const Icon(Icons.apple),
                              title: const Text(
                                  'الدفع عبر بوابة Tap (Apple Pay والبطاقات)'),
                              subtitle: const Text(
                                  'ينتقل العميل لصفحة الدفع، ويتأكد الطلب مدفوعاً تلقائياً',
                                  style: TextStyle(fontSize: 12))),
                        ),
                        const TapStatusNote(),
                      ],
                      const SizedBox(height: 10),
                      Field('وصف قصير يظهر للعميل', c['description']!,
                          hint: 'مثل: ادفع من محفظتك'),
                      const SizedBox(height: 10),
                      Field(
                          kind == 'bank_transfer'
                              ? 'رقم الحساب أو IBAN'
                              : 'رقم الدفع أو الحساب',
                          c['account']!,
                          ltr: true,
                          note: 'يظهر للعميل ليحوّل أو يدفع عليه'),
                      const SizedBox(height: 10),
                      Field('تعليمات للعميل', c['instructions']!,
                          maxLines: 3,
                          hint: 'مثل: اكتب رقم الطلب في ملاحظة التحويل'),
                      const SizedBox(height: 12),
                      const Text('الأيقونة',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final e in payIcons.entries)
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => set(() => icon = e.key),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: icon == e.key
                                    ? LinearGradient(colors: tone)
                                    : null,
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Icon(e.value,
                                  color: icon == e.key
                                      ? Colors.white
                                      : Colors.black54),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 8),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: active,
                          onChanged: (v) => set(() => active = v),
                          title: const Text('مفعّلة وتظهر للعميل')),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: del,
                          onChanged: (v) => set(() => del = v),
                          title: const Text('متاحة لطلبات التوصيل')),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: pick,
                          onChanged: (v) => set(() => pick = v),
                          title: const Text('متاحة للاستلام من المحل')),
                    ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: tone.first),
                onPressed: () {
                  if (form.currentState!.validate()) Navigator.pop(ctx, true);
                },
                child: Text(m == null ? 'إضافة' : 'حفظ')),
          ],
        );
      }),
    );
    if (ok != true || !context.mounted) return;
    await save(
        context,
        {
          if (m != null) 'code': m['code'],
          for (final e in c.entries) e.key: e.value.text.trim(),
          'kind': kind,
          'icon': icon,
          'active': active,
          'for_delivery': del,
          'for_pickup': pick,
          'gateway': kind == 'benefitpay' && tap ? 'tap' : '',
        },
        reload,
        ok: m == null ? 'تمت إضافة وسيلة الدفع' : 'تم الحفظ');
  }

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['payment_methods'],
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('payment_methods')
          .select()
          .eq('archived', false)
          .order('sort')),
      builder: (context, list, reload) {
        final on = list.where((m) => m['active'] == true).length;
        Future<void> move(int i, int d) async {
          final j = i + d;
          if (j < 0 || j >= list.length) return;
          final a = list[i], b = list[j];
          await guard(context, () async {
            await sb.rpc('admin_save_payment_method', params: {
              'p': {'code': a['code'], 'sort': j + 1}
            });
            await sb.rpc('admin_save_payment_method', params: {
              'p': {'code': b['code'], 'sort': i + 1}
            });
          });
          await reload();
        }

        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon: Icons.account_balance_wallet_outlined,
            title: 'وسائل الدفع',
            subtitle:
                'الطرق التي يدفع بها العميل عند الطلب، بالترتيب الذي يراه',
            stats: [
              ('كل الوسائل', '${list.length}'),
              ('مفعّلة', '$on'),
              ('موقوفة', '${list.length - on}'),
            ],
            action: HeroButton(
              icon: Icons.add_card_outlined,
              label: 'إضافة وسيلة دفع',
              onPressed: () => edit(context, null, reload),
            ),
          ),
          const SizedBox(height: 16),
          if (list.isEmpty) const Empty('لا توجد وسائل دفع'),
          for (var i = 0; i < list.length; i++)
            _MethodCard(
              m: list[i],
              first: i == 0,
              last: i == list.length - 1,
              onUp: () => move(i, -1),
              onDown: () => move(i, 1),
              onEdit: () => edit(context, list[i], reload),
              onToggle: (v) => save(
                  context, {'code': list[i]['code'], 'active': v}, reload,
                  ok: v ? 'تم تفعيل وسيلة الدفع' : 'تم إيقاف وسيلة الدفع'),
              onDelete: list[i]['builtin'] == true
                  ? null
                  : () async {
                      final sure = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text('${tr('حذف')} ${list[i]['name']}؟'),
                          content: const Text(
                              'تختفي من تطبيق العميل، وتبقى ظاهرة في الطلبات السابقة التي دُفعت بها.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('رجوع')),
                            FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor: G.ruby.first),
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('حذف')),
                          ],
                        ),
                      );
                      if (sure == true && context.mounted) {
                        await save(context,
                            {'code': list[i]['code'], 'archived': true}, reload,
                            ok: 'تم حذف وسيلة الدفع');
                      }
                    },
            ),
        ]);
      },
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard(
      {required this.m,
      required this.first,
      required this.last,
      required this.onUp,
      required this.onDown,
      required this.onEdit,
      required this.onToggle,
      required this.onDelete});
  final Map<String, dynamic> m;
  final bool first, last;
  final VoidCallback onUp, onDown, onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final k = payKinds['${m['kind']}'] ?? payKinds['cash']!;
    final on = m['active'] == true;
    final tone = on ? k.$3 : [Colors.blueGrey, Colors.blueGrey.shade300];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: tone)),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(payIcon(m['icon']), color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m['name']}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    Text(k.$1,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12.5)),
                  ]),
            ),
            if (m['builtin'] == true)
              Container(
                margin: const EdgeInsetsDirectional.only(end: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(999)),
                child: const Text('أساسية',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            Switch(
                value: on,
                onChanged: onToggle,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.white.withValues(alpha: .45)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if ('${m['description'] ?? ''}'.isNotEmpty)
              Text('${m['description']}',
                  style: const TextStyle(color: Colors.black87)),
            if ('${m['account'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const Icon(Icons.tag, size: 16, color: Colors.black45),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SelectableText('${m['account']}',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _chip(
                  m['for_delivery'] != false
                      ? 'متاحة للتوصيل'
                      : 'غير متاحة للتوصيل',
                  Icons.delivery_dining_outlined,
                  m['for_delivery'] != false),
              _chip(
                  m['for_pickup'] != false
                      ? 'متاحة للاستلام من المحل'
                      : 'غير متاحة للاستلام',
                  Icons.storefront_outlined,
                  m['for_pickup'] != false),
              _chip(on ? 'تظهر للعميل' : 'موقوفة',
                  on ? Icons.visibility_outlined : Icons.visibility_off, on),
            ]),
            const Divider(height: 20),
            Row(children: [
              IconButton(
                  tooltip: tr('أعلى'),
                  onPressed: first ? null : onUp,
                  icon: const Icon(Icons.arrow_upward)),
              IconButton(
                  tooltip: tr('أسفل'),
                  onPressed: last ? null : onDown,
                  icon: const Icon(Icons.arrow_downward)),
              const Spacer(),
              TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('تعديل')),
              if (onDelete != null)
                IconButton(
                  tooltip: tr('حذف'),
                  onPressed: onDelete,
                  style: IconButton.styleFrom(
                      backgroundColor: G.ruby.first.withValues(alpha: .08)),
                  icon:
                      Icon(Icons.delete_outline, color: G.ruby.first, size: 20),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(String t, IconData i, bool ok) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color:
                (ok ? G.emerald.first : Colors.blueGrey).withValues(alpha: .1),
            borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 14, color: ok ? G.emerald.first : Colors.blueGrey),
          const SizedBox(width: 4),
          Text(t,
              style: TextStyle(
                  fontSize: 12,
                  color: ok ? G.emerald.first : Colors.blueGrey,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Whether the Tap secret key is set on the server (test or live).
class TapStatusNote extends StatelessWidget {
  const TapStatusNote({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future:
            tapFn({'action': 'status'}).catchError((_) => <String, dynamic>{}),
        builder: (_, s) {
          if (!s.hasData) return const SizedBox(height: 8);
          final mode = s.data!['mode'];
          final (txt, col) = switch (mode) {
            'live' => ('بوابة Tap مربوطة (حساب فعلي)', Colors.green.shade700),
            'test' => (
                'بوابة Tap مربوطة على البيئة التجريبية',
                Colors.orange.shade800
              ),
            _ => (
                'بوابة Tap غير مربوطة بعد، العميل ما يقدر يدفع بها حالياً',
                Colors.red.shade700
              ),
          };
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(children: [
              Icon(mode == null ? Icons.link_off : Icons.verified,
                  size: 16, color: col),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(txt, style: TextStyle(fontSize: 12, color: col))),
            ]),
          );
        },
      );
}
