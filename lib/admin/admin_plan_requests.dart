import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/common.dart';
import '../core/ttext.dart';
import '../merchant/merchant_store.dart'
    show planLook, planReqLabels, planReqColors;

/// Merchants' renew / upgrade requests, with the transfer receipt and approve / reject.
class PlanRequestsSection extends StatefulWidget {
  const PlanRequestsSection({super.key});
  @override
  State<PlanRequestsSection> createState() => _PlanRequestsSectionState();
}

class _PlanRequestsSectionState extends State<PlanRequestsSection> {
  String filter = 'pending';

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['subscription_requests'],
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('subscription_requests')
          .select('*, merchants(name, plan, plan_ends)')
          .order('created_at', ascending: false)),
      builder: (context, reqs, reload) {
        final b = brandOf(context);
        final shown = reqs
            .where((r) => filter == 'all' || r['status'] == filter)
            .toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            GradientBadge(
                colors: G.amber, icon: Icons.receipt_long_outlined, size: 40),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('طلبات الاشتراك والترقية',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text('راجع إيصال التحويل ثم فعّل الباقة أو ارفض الطلب',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final f in [...planReqLabels.keys, 'all'])
                TonePill(
                  label: f == 'all' ? 'الكل' : planReqLabels[f]!,
                  count: f == 'all'
                      ? reqs.length
                      : reqs.where((r) => r['status'] == f).length,
                  colors: f == 'all' ? b.stops.sublist(1) : planReqColors(f),
                  selected: filter == f,
                  onTap: () => setState(() => filter = f),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('لا توجد طلبات هنا',
                    style: TextStyle(color: Colors.black54)),
              ),
            ),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 380).floor().clamp(1, 3);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final r in shown)
                SizedBox(
                    width: w,
                    child: _RequestCard(r: r, onDone: reload)),
            ]);
          }),
        ]);
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.r, required this.onDone});
  final Map<String, dynamic> r;
  final Future<void> Function() onDone;

  Future<void> review(BuildContext context, bool approve) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(approve ? 'تفعيل الباقة' : 'رفض الطلب'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                approve
                    ? 'تتفعّل الباقة ${planLabels[r['plan']]} لـ ${r['merchants']?['name'] ?? ''} ويُسجَّل ${bhd(r['amount'])} في إيرادات الاشتراكات.'
                    : 'يصل السبب للتاجر في تطبيقه.',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            Field(approve ? 'ملاحظة (اختياري)' : 'سبب الرفض *', note,
                maxLines: 2),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: approve ? G.emerald.first : G.ruby.first),
              onPressed: () => Navigator.pop(c, true),
              child: Text(approve ? 'تفعيل' : 'رفض')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await guard(
        context,
        () => sb.rpc('admin_review_plan_request', params: {
              'p_request': r['id'],
              'p_approve': approve,
              'p_note': note.text.trim()
            }),
        ok: approve ? 'تم تفعيل الاشتراك وإشعار التاجر' : 'تم رفض الطلب وإشعار التاجر');
    await onDone();
  }

  Future<void> showReceipt(BuildContext context) async {
    final path = '${r['receipt_path'] ?? ''}';
    if (path.isEmpty) return;
    final url = await guard(
        context, () => sb.storage.from('docs').createSignedUrl(path, 600));
    if (url == null || !context.mounted) return;
    final isPdf = path.toLowerCase().endsWith('.pdf');
    await showDialog(
      context: context,
      builder: (c) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: G.amber)),
              child: Row(children: [
                const Icon(Icons.receipt_long_outlined, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'إيصال طلب #${r['code']} · ${r['merchants']?['name'] ?? ''} · ${bhd(r['amount'])}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(c),
                    icon: const Icon(Icons.close, color: Colors.white)),
              ]),
            ),
            Flexible(
              child: isPdf
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 48),
                        const SizedBox(height: 8),
                        const Text('الإيصال ملف PDF، انسخ الرابط وافتحه:'),
                        const SizedBox(height: 8),
                        SelectableText(url, style: const TextStyle(fontSize: 12)),
                      ]),
                    )
                  : InteractiveViewer(
                      child: Image.network(url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Padding(
                                padding: const EdgeInsets.all(16),
                                child: SelectableText(url),
                              )),
                    ),
            ),
            if (r['transfer_ref'] != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('رقم العملية: ${r['transfer_ref']}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = '${r['status']}';
    final look = planLook['${r['plan']}'] ?? planLook['monthly']!;
    final sc = planReqColors(st);
    final upgrade = r['kind'] == 'upgrade';
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(children: [
            Text(k, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
            const Spacer(),
            Flexible(
                child: Text(v,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
        );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: look.$2)),
          child: Row(children: [
            Icon(look.$1, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['merchants']?['name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                Text(
                    '#${r['code']} · ${upgrade ? 'ترقية' : 'تجديد'} ${planLabels[r['from_plan']]} ← ${planLabels[r['plan']]}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(999)),
              child: Text(planReqLabels[st] ?? st,
                  style: TextStyle(
                      color: sc.first,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            kv('المبلغ', bhd(r['amount'])),
            kv('تاريخ الطلب', dateTimeText(r['created_at'])),
            kv('الاشتراك الحالي ينتهي',
                dateText(r['merchants']?['plan_ends'])),
            if (r['transfer_ref'] != null) kv('رقم العملية', '${r['transfer_ref']}'),
            if (r['new_ends'] != null) kv('ساري حتى', dateText(r['new_ends'])),
            if (r['note'] != null) kv('ملاحظة التاجر', '${r['note']}'),
            if (r['admin_note'] != null) kv('ملاحظة الإدارة', '${r['admin_note']}'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: r['receipt_path'] == null
                    ? null
                    : () => showReceipt(context),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(r['receipt_path'] == null
                    ? 'بدون إيصال'
                    : 'عرض الإيصال'),
              ),
              if (st == 'pending') ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: G.emerald.first),
                  onPressed: () => review(context, true),
                  icon: const Icon(Icons.task_alt, size: 18),
                  label: const Text('تفعيل'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: G.ruby.first),
                  onPressed: () => review(context, false),
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('رفض'),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}
