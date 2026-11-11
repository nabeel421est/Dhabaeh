import 'package:flutter/material.dart' hide Text;

import 'brand.dart';
import 'common.dart';
import 'ttext.dart';

/// Stages of a merchant's withdrawal request, in order. "rejected" can end it at any point before transfer.
const payoutLabels = {
  'requested': 'تم الطلب',
  'under_review': 'قيد المراجعة',
  'approved': 'تمت الموافقة',
  'transferred': 'تم التحويل',
  'rejected': 'مرفوض',
};
const payoutSteps = ['requested', 'under_review', 'approved', 'transferred'];

List<Color> payoutColors(String s) => switch (s) {
      'requested' => G.amber,
      'under_review' => G.sky,
      'approved' => G.violet,
      'transferred' => G.emerald,
      _ => G.ruby,
    };

IconData payoutIcon(String s) => switch (s) {
      'requested' => Icons.outbox_outlined,
      'under_review' => Icons.manage_search,
      'approved' => Icons.event_available_outlined,
      'transferred' => Icons.check_circle_outline,
      _ => Icons.cancel_outlined,
    };

/// Horizontal progress of a request: each stage lights up in its colour once reached,
/// with the time it happened (and the planned transfer date under "approved").
class PayoutStepper extends StatelessWidget {
  const PayoutStepper({super.key, required this.request, required this.events});
  final Map<String, dynamic> request;
  final List<Map<String, dynamic>> events;
  @override
  Widget build(BuildContext context) {
    final status = '${request['status']}';
    final rejected = status == 'rejected';
    final reached = <String, String>{
      for (final e in events) '${e['status']}': '${e['created_at']}'
    };
    final steps = [
      ...payoutSteps
          .take(rejected ? payoutSteps.indexOf(_lastReached(reached)) + 1 : 4),
      if (rejected) 'rejected'
    ];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < steps.length; i++) ...[
        Expanded(
            child: _Step(
                step: steps[i],
                done: reached.containsKey(steps[i]),
                at: reached[steps[i]],
                request: request)),
        if (i < steps.length - 1)
          Padding(
            padding: EdgeInsets.zero,
            child: Container(
              width: 18,
              height: 3,
              margin: const EdgeInsets.only(top: 17),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: reached.containsKey(steps[i + 1])
                    ? LinearGradient(colors: payoutColors(steps[i + 1]))
                    : null,
                color: reached.containsKey(steps[i + 1])
                    ? null
                    : const Color(0xFFE3E8EE),
              ),
            ),
          ),
      ],
    ]);
  }

  static String _lastReached(Map<String, String> reached) {
    var last = 'requested';
    for (final s in payoutSteps) {
      if (reached.containsKey(s)) last = s;
    }
    return last;
  }
}

class _Step extends StatelessWidget {
  const _Step(
      {required this.step,
      required this.done,
      required this.at,
      required this.request});
  final String step;
  final bool done;
  final String? at;
  final Map<String, dynamic> request;
  @override
  Widget build(BuildContext context) {
    final colors = payoutColors(step);
    final sub = step == 'approved' && request['scheduled_date'] != null
        ? 'التحويل ${dateText(request['scheduled_date'])}'
        : done && at != null
            ? dateText(at)
            : '';
    return Column(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: done ? LinearGradient(colors: colors) : null,
          color: done ? null : const Color(0xFFF0F3F6),
          boxShadow: done
              ? [
                  BoxShadow(
                      color: colors.first.withValues(alpha: .3),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
              : null,
        ),
        child: Icon(payoutIcon(step),
            size: 18, color: done ? Colors.white : Colors.black26),
      ),
      const SizedBox(height: 6),
      Text(payoutLabels[step]!,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: done ? FontWeight.w700 : FontWeight.w500,
              color: done ? colors.first : Colors.black38)),
      if (sub.isNotEmpty)
        Text(sub,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: Colors.black45)),
    ]);
  }
}

/// One withdrawal request: gradient header in its stage colour, the amount, bank account, stepper and notes.
class PayoutCard extends StatelessWidget {
  const PayoutCard(
      {super.key,
      required this.r,
      required this.events,
      this.merchantName,
      this.action});
  final Map<String, dynamic> r;
  final List<Map<String, dynamic>> events;
  final String? merchantName;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final status = '${r['status']}';
    final colors = payoutColors(status);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: colors)),
          child: Row(children: [
            Icon(payoutIcon(status), color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'طلب سحب #${r['code']}${merchantName != null ? ' · $merchantName' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    Text(dateTimeText(r['created_at']),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ]),
            ),
            Text(bhd(r['amount']),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PayoutStepper(request: r, events: events),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FA),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.account_balance_outlined,
                    size: 18, color: Colors.black45),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      '${r['bank_name'] ?? ''} · ${r['account_name'] ?? ''}\n${r['iban'] ?? ''}',
                      style: const TextStyle(fontSize: 12.5, height: 1.5)),
                ),
              ]),
            ),
            if ('${r['note'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('ملاحظة التاجر: ${r['note']}',
                  style:
                      const TextStyle(fontSize: 12.5, color: Colors.black54)),
            ],
            if ('${r['admin_note'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: colors.first.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(12)),
                child: Text('ملاحظة الإدارة: ${r['admin_note']}',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: colors.first,
                        fontWeight: FontWeight.w600)),
              ),
            ],
            if ('${r['transfer_ref'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('رقم الحوالة: ${r['transfer_ref']}',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ]),
        ),
      ]),
    );
  }
}
