import 'package:flutter/material.dart' hide Text;

import 'brand.dart';
import 'common.dart';
import 'i18n.dart';
import 'ttext.dart';

/// A small amount + note dialog used by the driver (request) and the admin (pay / reject).
Future<(num, String)?> _amountDialog(BuildContext context,
    {required String title,
    required List<Color> tone,
    required IconData icon,
    String? info,
    num? amount,
    bool askAmount = true,
    String noteLabel = 'ملاحظة',
    bool noteRequired = false,
    required String action}) async {
  final form = GlobalKey<FormState>();
  final a = TextEditingController(text: amount?.toStringAsFixed(3) ?? '');
  final n = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: tone),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22))),
        child: Row(children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700))),
        ]),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: form,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (info != null) ...[
                  Text(info,
                      style: TextStyle(
                          color: tone.first, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                ],
                if (askAmount) ...[
                  Field('المبلغ (د.ب)', a,
                      required: true,
                      ltr: true,
                      keyboard:
                          const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 10),
                ],
                Field(noteLabel, n, maxLines: 2, required: noteRequired),
              ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء')),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: tone.first),
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: Text(action)),
      ],
    ),
  );
  if (ok != true) return null;
  return (num.tryParse(a.text.trim()) ?? 0, n.text.trim());
}

const _driverTone = [Color(0xFF0D6152), Color(0xFF3CC4A0)];

/// Driver wallet: ask the administration to pay out the fees owed, or follow the request.
class DriverPayoutAsk extends StatelessWidget {
  const DriverPayoutAsk(
      {super.key,
      required this.open,
      required this.last,
      required this.reload});

  /// Fees owed minus payouts already on the way.
  final num open;

  /// The driver's latest request, if any.
  final Map<String, dynamic>? last;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final r = last;
    final waiting = r?['status'] == 'requested';
    final rejected = r?['status'] == 'rejected' &&
        DateTime.tryParse('${r?['handled_at']}')
                ?.isAfter(DateTime.now().subtract(const Duration(days: 3))) ==
            true;
    final pill = BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .25)));
    if (waiting) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: pill,
        child: Row(children: [
          const Icon(Icons.hourglass_top, color: Color(0xFFFFD27A), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${tr('طلب صرف قيد المراجعة')} · ${bhd(r!['amount'])}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          TextButton(
              onPressed: () async {
                await guard(
                    context,
                    () => sb.rpc('driver_cancel_payout_request',
                        params: {'p_id': r['id']}),
                    ok: 'تم إلغاء الطلب');
                await reload();
              },
              child: const Text('إلغاء الطلب',
                  style: TextStyle(color: Colors.white70))),
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (rejected) ...[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: pill,
          child: Text(
              '${tr('رفضت الإدارة طلب الصرف')}: ${r!['reject_reason'] ?? ''}',
              style: const TextStyle(color: Color(0xFFFFC2C2), fontSize: 12.5)),
        ),
        const SizedBox(height: 8),
      ],
      FilledButton.icon(
        style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _driverTone.first,
            disabledBackgroundColor: Colors.white24,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        onPressed: open <= 0
            ? null
            : () async {
                final v = await _amountDialog(context,
                    title: 'طلب صرف المستحقات',
                    tone: _driverTone,
                    icon: Icons.request_quote_outlined,
                    info: '${tr('مستحقاتك المتاحة للصرف')}: ${bhd(open)}',
                    amount: open,
                    noteLabel: 'ملاحظة للإدارة',
                    action: 'إرسال الطلب');
                if (v == null || !context.mounted) return;
                await guard(
                    context,
                    () => sb.rpc('driver_request_payout',
                        params: {'p_amount': v.$1, 'p_note': v.$2}),
                    ok: 'وصل طلبك للإدارة');
                await reload();
              },
        icon: const Icon(Icons.request_quote_outlined),
        label: Text(open <= 0 ? 'لا توجد مستحقات للصرف' : 'طلب صرف المستحقات',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

/// Admin (رسوم المناديب): open payout requests from drivers, with pay / reject.
class DriverPayoutRequestsAdmin extends StatelessWidget {
  const DriverPayoutRequestsAdmin(
      {super.key, required this.requests, required this.reload});
  final List<Map<String, dynamic>> requests;
  final Future<void> Function() reload;

  Future<void> pay(BuildContext context, Map<String, dynamic> r) async {
    final v = await _amountDialog(context,
        title: '${tr('صرف مستحقات')} · ${r['profiles']?['full_name'] ?? ''}',
        tone: G.emerald,
        icon: Icons.task_alt,
        info: '${tr('المبلغ المطلوب')}: ${bhd(r['amount'])}',
        amount: toNum(r['amount']),
        noteLabel: 'ملاحظة للمندوب',
        action: 'صرف');
    if (v == null || !context.mounted) return;
    await guard(
        context,
        () => sb.rpc('admin_handle_payout_request', params: {
              'p_id': r['id'],
              'p_action': 'pay',
              'p_amount': v.$1,
              'p_note': v.$2,
            }),
        ok: 'تم الصرف، وبانتظار تأكيد المندوب');
    await reload();
  }

  Future<void> reject(BuildContext context, Map<String, dynamic> r) async {
    final v = await _amountDialog(context,
        title: '${tr('رفض طلب الصرف')} · ${r['profiles']?['full_name'] ?? ''}',
        tone: G.rose,
        icon: Icons.block,
        askAmount: false,
        noteLabel: 'سبب الرفض (يظهر للمندوب)',
        noteRequired: true,
        action: 'رفض');
    if (v == null || !context.mounted) return;
    await guard(
        context,
        () => sb.rpc('admin_handle_payout_request', params: {
              'p_id': r['id'],
              'p_action': 'reject',
              'p_note': v.$2,
            }),
        ok: 'تم رفض الطلب');
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        GradientBadge(colors: G.amber, icon: Icons.request_quote, size: 34),
        const SizedBox(width: 8),
        const Text('طلبات صرف من المناديب',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        CircleAvatar(
            radius: 12,
            backgroundColor: G.amber.first,
            child: Text('${requests.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12))),
      ]),
      const SizedBox(height: 10),
      for (final r in requests)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: G.amber.first.withValues(alpha: .5))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.delivery_dining_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${r['profiles']?['full_name'] ?? ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text(
                                '${r['profiles']?['phone'] ?? ''} · ${dateTimeText(r['created_at'])}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ]),
                    ),
                    Text(bhd(r['amount']),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: G.emerald.first)),
                  ]),
                  if ('${r['note'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('${tr('ملاحظة المندوب')}: ${r['note']}',
                        style: const TextStyle(color: Colors.black54)),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: G.emerald.first),
                          onPressed: () => pay(context, r),
                          icon: const Icon(Icons.task_alt, size: 18),
                          label: const Text('صرف')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: G.rose.first),
                          onPressed: () => reject(context, r),
                          icon: const Icon(Icons.block, size: 18),
                          label: const Text('رفض')),
                    ),
                  ]),
                ]),
          ),
        ),
      const SizedBox(height: 10),
    ]);
  }
}
