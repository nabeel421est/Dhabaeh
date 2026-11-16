import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/common.dart';
import '../core/i18n.dart';
import '../core/ttext.dart';
import 'admin_payment_methods.dart' show payIcon;

/// Gradient for a payment method's wallet card.
List<Color> methodTone(Map m, int i) {
  if (m['gateway'] == 'tap') {
    return const [Color(0xFF0B0B10), Color(0xFF2B2B36), Color(0xFF6B6B7E)];
  }
  return switch ('${m['code']}') {
    'benefitpay' => const [
        Color(0xFF5C0A1E),
        Color(0xFFB0163A),
        Color(0xFFF0607A)
      ],
    'bank_transfer' => const [
        Color(0xFF0B2559),
        Color(0xFF1F5FC4),
        Color(0xFF6AB2F7)
      ],
    'cash' => const [Color(0xFF04362B), Color(0xFF0E8A60), Color(0xFF55D6A0)],
    _ => [
        const [Color(0xFF3A1A78), Color(0xFF7448D8), Color(0xFFB79BFA)],
        const [Color(0xFF6E3A0A), Color(0xFFD9771F), Color(0xFFF7C562)],
        const [Color(0xFF05464A), Color(0xFF0F8C84), Color(0xFF4FD1B5)],
        const [Color(0xFF5C0F4E), Color(0xFFB02A8A), Color(0xFFF07BC6)],
      ][i % 4],
  };
}

/// «محافظ وسائل الدفع»: one luxurious card per payment method with what came in
/// through it; tapping a card opens its stats and orders.
class MethodWallets extends StatelessWidget {
  const MethodWallets({super.key});

  @override
  Widget build(BuildContext context) => Loader<List<Map<String, dynamic>>>(
        realtimeTables: const ['orders', 'payment_methods'],
        load: () async => [
          for (final x in await sb.rpc('admin_method_wallets') as List)
            Map<String, dynamic>.from(x)
        ],
        builder: (context, ws, _) {
          final b = brandOf(context);
          final all = ws.fold<num>(0, (a, w) => a + toNum(w['paid_total']));
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: LinearGradient(colors: b.gold)),
                    child: Icon(Icons.account_balance_wallet_outlined,
                        size: 19, color: b.dark),
                  ),
                  const SizedBox(width: 10),
                  Text('محافظ وسائل الدفع',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: b.dark)),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(colors: b.gold)),
                    child: Text('${tr('المجموع')} ${bhd(all)}',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: b.dark)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                          b.accent.withValues(alpha: .7),
                          b.accent.withValues(alpha: 0),
                        ]))),
                  ),
                ]),
                const SizedBox(height: 6),
                const Text(
                    'كل وسيلة دفع لها محفظة تجمع ما دفعه العملاء عن طريقها. أي وسيلة تضيفها من «وسائل الدفع» تظهر لها محفظة هنا تلقائياً.',
                    style: TextStyle(color: Colors.black54, fontSize: 12.5)),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, c) {
                  final cols = (c.maxWidth / 290).floor().clamp(1, 4);
                  final w = (c.maxWidth - 14 * (cols - 1)) / cols;
                  return Wrap(spacing: 14, runSpacing: 14, children: [
                    for (final (i, m) in ws.indexed)
                      SizedBox(
                        width: w,
                        child: _WalletCard(
                          m: m,
                          tone: methodTone(m, i),
                          share: all > 0 ? toNum(m['paid_total']) / all : 0,
                          onTap: () =>
                              _openWallet(context, m, methodTone(m, i)),
                        ),
                      ),
                  ]);
                }),
              ]);
        },
      );
}

class _WalletCard extends StatefulWidget {
  const _WalletCard(
      {required this.m,
      required this.tone,
      required this.share,
      required this.onTap});
  final Map<String, dynamic> m;
  final List<Color> tone;
  final double share;
  final VoidCallback onTap;
  @override
  State<_WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<_WalletCard> {
  bool hover = false;
  @override
  Widget build(BuildContext context) {
    final m = widget.m, t = widget.tone;
    const gold = Color(0xFFF4D58A);
    final off = m['active'] != true || m['archived'] == true;
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedScale(
        scale: hover ? 1.02 : 1,
        duration: const Duration(milliseconds: 160),
        child: Container(
          padding: const EdgeInsets.all(1.4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gold,
                  t[2].withValues(alpha: .5),
                  gold.withValues(alpha: .7)
                ]),
            boxShadow: [
              BoxShadow(
                  color: t[1].withValues(alpha: hover ? .55 : .38),
                  blurRadius: hover ? 30 : 22,
                  offset: const Offset(0, 12)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: t),
                  ),
                  child: Stack(children: [
                    PositionedDirectional(
                      end: -30,
                      top: -40,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              Colors.white.withValues(alpha: .22),
                              Colors.white.withValues(alpha: 0)
                            ])),
                      ),
                    ),
                    PositionedDirectional(
                      start: -10,
                      bottom: -24,
                      child: Icon(payIcon(m['icon']),
                          size: 120,
                          color: Colors.white.withValues(alpha: .07)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFFF1C9),
                                        gold,
                                        Color(0xFFB8893A)
                                      ]),
                                  boxShadow: [
                                    BoxShadow(
                                        color: gold.withValues(alpha: .45),
                                        blurRadius: 12)
                                  ],
                                ),
                                child: Icon(payIcon(m['icon']),
                                    color: const Color(0xFF3A2606), size: 23),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${tr('محفظة')} ${m['name']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w800)),
                                      Text(
                                          off
                                              ? tr('متوقفة للعملاء')
                                              : '${m['paid_count']} ${tr('عملية مدفوعة')}',
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: .75),
                                              fontSize: 12)),
                                    ]),
                              ),
                              Icon(Icons.chevron_left,
                                  color: Colors.white.withValues(alpha: .7)),
                            ]),
                            const SizedBox(height: 16),
                            Text(tr('الرصيد المحصّل'),
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: .7),
                                    fontSize: 12)),
                            ShaderMask(
                              shaderCallback: (r) => const LinearGradient(
                                      colors: [Colors.white, Color(0xFFFFF1C9)])
                                  .createShader(r),
                              child: Text(bhd(m['paid_total']),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: LinearProgressIndicator(
                                value: widget.share.clamp(0, 1).toDouble(),
                                minHeight: 6,
                                backgroundColor:
                                    Colors.white.withValues(alpha: .16),
                                valueColor: const AlwaysStoppedAnimation(gold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _mini(tr('اليوم'), bhd(m['today_total'])),
                              _mini(tr('هذا الشهر'), bhd(m['month_total'])),
                              if (toNum(m['pending_total']) +
                                      toNum(m['review_total']) >
                                  0)
                                _mini(
                                    tr('بانتظار التأكيد'),
                                    bhd(toNum(m['pending_total']) +
                                        toNum(m['review_total'])),
                                    warn: true),
                            ]),
                          ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mini(String k, String v, {bool warn = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: warn
              ? const Color(0xFFFFC857).withValues(alpha: .22)
              : Colors.white.withValues(alpha: .13),
          border: Border.all(
              color: warn
                  ? const Color(0xFFFFC857).withValues(alpha: .7)
                  : Colors.white.withValues(alpha: .25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .75), fontSize: 10.5)),
          Text(v,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ]),
      );
}

Future<void> _openWallet(BuildContext context, Map m, List<Color> t) =>
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 10, 18),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: t)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(payIcon(m['icon']),
                          color: const Color(0xFFF4D58A), size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${tr('محفظة')} ${m['name']}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                      ),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white)),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      for (final s in [
                        (tr('الرصيد المحصّل'), bhd(m['paid_total'])),
                        (tr('اليوم'), bhd(m['today_total'])),
                        (tr('هذا الشهر'), bhd(m['month_total'])),
                        (tr('بانتظار الدفع'), bhd(m['pending_total'])),
                        (tr('بانتظار مراجعة الإيصال'), bhd(m['review_total'])),
                        (tr('عدد الطلبات'), '${m['orders_count']}'),
                      ])
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.white.withValues(alpha: .14),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: .3))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.$1,
                                    style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: .75),
                                        fontSize: 11.5)),
                                Text(s.$2,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800)),
                              ]),
                        ),
                    ]),
                  ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Text('حركات المحفظة',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Flexible(
              child: FutureBuilder(
                future: sb.rpc('admin_method_wallet_orders',
                    params: {'p_code': m['code']}),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(errText(snap.error!)));
                  }
                  if (!snap.hasData) {
                    return const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator()));
                  }
                  final rows = [
                    for (final x in snap.data as List)
                      Map<String, dynamic>.from(x)
                  ];
                  if (rows.isEmpty) {
                    return const Empty('لا توجد حركات في هذه المحفظة بعد',
                        icon: Icons.account_balance_wallet_outlined);
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _TxnRow(rows[i], t),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );

class _TxnRow extends StatelessWidget {
  const _TxnRow(this.r, this.t);
  final Map<String, dynamic> r;
  final List<Color> t;
  @override
  Widget build(BuildContext context) {
    final cancelled = r['status'] == 'cancelled';
    final ps = '${r['payment_status']}';
    final (label, col) = cancelled
        ? (tr('ملغي'), const Color(0xFF64748B))
        : switch (ps) {
            'paid' => (tr('مدفوع'), const Color(0xFF0E8A60)),
            'awaiting_review' => (
                tr('بانتظار مراجعة الإيصال'),
                const Color(0xFFB7791F)
              ),
            _ => (tr('بانتظار الدفع'), const Color(0xFFB3261E)),
          };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [
          Colors.white,
          Color.lerp(t[2], Colors.white, .88)!,
        ]),
        border: Border.all(color: t[1].withValues(alpha: .18)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(colors: [t[1], t[2]])),
          child: const Icon(Icons.receipt_long_outlined,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('#${r['code']} · ${r['customer_name'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
                '${r['merchant_name'] ?? ''} · ${dateTimeText(r['paid_at'] ?? r['created_at'])}'
                '${(r['payment_auth'] ?? '').toString().isEmpty ? '' : ' · ${tr('رقم التفويض')} ${r['payment_auth']}'}',
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(bhd(r['total']),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cancelled ? Colors.black38 : t[1],
                  decoration: cancelled ? TextDecoration.lineThrough : null)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: col.withValues(alpha: .12)),
            child: Text(label,
                style: TextStyle(
                    color: col, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }
}
