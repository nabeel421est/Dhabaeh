import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/brand.dart';
import '../core/common.dart';

const planRank = {'trial': 0, 'monthly': 1, 'yearly': 2};
const planLook = <String, (IconData, List<Color>)>{
  'trial': (Icons.hourglass_top_outlined, G.amber),
  'monthly': (Icons.calendar_month_outlined, G.sky),
  'yearly': (Icons.workspace_premium_outlined, G.gold),
};
const planReqLabels = {
  'pending': 'قيد المراجعة',
  'approved': 'تم التفعيل',
  'rejected': 'مرفوض'
};
List<Color> planReqColors(String s) => switch (s) {
      'approved' => G.emerald,
      'rejected' => G.ruby,
      _ => G.amber,
    };

num planPrice(Map s, String plan) => switch (plan) {
      'monthly' => toNum(s['monthly_price']),
      'yearly' => toNum(s['yearly_price']),
      _ => 0,
    };
int planDays(Map s, String plan) => switch (plan) {
      'monthly' => 30,
      'yearly' => 365,
      _ => (toNum(s['trial_days']).toInt()),
    };

/// End of the subscription's last day, local time.
DateTime planEnd(dynamic ends) {
  final d = DateTime.tryParse('$ends') ?? DateTime.now();
  return DateTime(d.year, d.month, d.day, 23, 59, 59);
}

class StoreSettings extends StatefulWidget {
  const StoreSettings(
      {super.key, required this.merchant, required this.onSaved});
  final Map<String, dynamic> merchant;
  final VoidCallback onSaved;
  @override
  State<StoreSettings> createState() => _StoreSettingsState();
}

class _StoreSettingsState extends State<StoreSettings> {
  late bool open = widget.merchant['is_open'] == true;
  late final desc =
      TextEditingController(text: widget.merchant['description'] ?? '');

  @override
  Widget build(BuildContext context) {
    final m = widget.merchant;
    final b = brandOf(context);
    return Loader<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
      realtimeTables: const ['subscription_requests', 'merchants'],
      load: () async {
        final s =
            await sb.from('platform_settings').select().eq('id', 1).single();
        final reqs = await sb
            .from('subscription_requests')
            .select()
            .eq('merchant_id', m['id'])
            .order('created_at', ascending: false);
        return (s, List<Map<String, dynamic>>.from(reqs));
      },
      builder: (context, data, reload) {
        final (s, reqs) = data;
        final pending = reqs.where((r) => r['status'] == 'pending').firstOrNull;
        final plan = '${m['plan']}';
        Future<void> start(bool upgrade) async {
          final done = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (_) => PlanPickerPage(
                      merchant: m, settings: s, upgrade: upgrade)));
          if (done == true) {
            await reload();
            widget.onSaved();
          }
        }

        return ListView(padding: const EdgeInsets.all(16), children: [
          PageHero(
            icon: Icons.storefront_outlined,
            title: '${m['name']}',
            subtitle: '${m['area'] ?? ''} · ${m['store_phone'] ?? ''}',
            stats: [
              ('الحالة', open ? 'مفتوح' : 'مغلق'),
              ('الباقة', planLabels[plan] ?? plan),
            ],
          ),
          const SizedBox(height: 14),
          SubscriptionCountdown(
            merchant: m,
            settings: s,
            pending: pending,
            onRenew: plan == 'trial' || pending != null ? null : () => start(false),
            onUpgrade:
                plan == 'yearly' || pending != null ? null : () => start(true),
          ),
          const SizedBox(height: 14),
          if (reqs.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.history, color: b.primary),
              const SizedBox(width: 8),
              const Text('طلبات الاشتراك',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            for (final r in reqs) ...[
              PlanRequestRow(r: r),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
          ],
          GradientHeaderCard(
            title: 'حالة المتجر',
            subtitle: 'تحكم في استقبال الطلبات والنبذة التي يراها العملاء',
            icon: Icons.toggle_on_outlined,
            colors: b.stops.sublist(1),
            child: Column(children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(open
                    ? 'المتجر مفتوح ويستقبل الطلبات'
                    : 'المتجر مغلق مؤقتاً'),
                value: open,
                onChanged: (v) => setState(() => open = v),
              ),
              Field('نبذة عن المتجر (تظهر للعملاء)', desc, maxLines: 3),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save_outlined, size: 18),
                  onPressed: () async {
                    await guard(
                        context,
                        () => sb.rpc('merchant_update_store', params: {
                              'p_merchant': m['id'],
                              'p_is_open': open,
                              'p_description': desc.text.trim(),
                              'p_logo': null
                            }),
                        ok: 'تم الحفظ');
                    widget.onSaved();
                  },
                  label: const Text('حفظ'),
                ),
              ),
            ]),
          ),
        ]);
      },
    );
  }
}

/// Gradient subscription card with a live days/hours/minutes/seconds countdown.
class SubscriptionCountdown extends StatefulWidget {
  const SubscriptionCountdown(
      {super.key,
      required this.merchant,
      required this.settings,
      this.pending,
      this.onRenew,
      this.onUpgrade});
  final Map<String, dynamic> merchant;
  final Map<String, dynamic> settings;
  final Map<String, dynamic>? pending;
  final VoidCallback? onRenew;
  final VoidCallback? onUpgrade;
  @override
  State<SubscriptionCountdown> createState() => _SubscriptionCountdownState();
}

class _SubscriptionCountdownState extends State<SubscriptionCountdown> {
  Timer? t;
  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.merchant;
    final plan = '${m['plan']}';
    final look = planLook[plan] ?? planLook['monthly']!;
    final end = planEnd(m['plan_ends']);
    final left = end.difference(DateTime.now());
    final expired = left.isNegative;
    final total = planDays(widget.settings, plan) * 86400;
    final frac = expired || total <= 0
        ? 0.0
        : (left.inSeconds / total).clamp(0.0, 1.0).toDouble();
    final soon = !expired && left.inDays < 5;
    final colors = expired ? G.ruby : look.$2;
    Widget unit(int v, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: .25))),
            child: Column(children: [
              Text(v.toString().padLeft(2, '0'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()])),
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        );
    final l = expired ? Duration.zero : left;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [colors.first, colors.last, colors.first]),
        boxShadow: [
          BoxShadow(
              color: colors.first.withValues(alpha: .3),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        PositionedDirectional(
            end: -40,
            top: -50,
            child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .08)))),
        Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(look.$1, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الباقة ${planLabels[plan] ?? plan}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700)),
                      Text(
                          expired
                              ? 'انتهى الاشتراك في ${dateText(m['plan_ends'])}'
                              : 'ينتهي في ${dateText(m['plan_ends'])}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12.5)),
                    ]),
              ),
              if (soon || expired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(expired ? 'منتهي' : 'قارب على الانتهاء',
                      style: TextStyle(
                          color: colors.first,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
            const SizedBox(height: 16),
            const Text('المتبقي من الاشتراك',
                style: TextStyle(color: Colors.white70, fontSize: 12.5)),
            const SizedBox(height: 8),
            Row(children: [
              unit(l.inDays, 'يوم'),
              const SizedBox(width: 8),
              unit(l.inHours % 24, 'ساعة'),
              const SizedBox(width: 8),
              unit(l.inMinutes % 60, 'دقيقة'),
              const SizedBox(width: 8),
              unit(l.inSeconds % 60, 'ثانية'),
            ]),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 7,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: .22)),
            ),
            const SizedBox(height: 14),
            if (widget.pending != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.hourglass_bottom, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        'طلب ${widget.pending!['kind'] == 'upgrade' ? 'الترقية' : 'التجديد'} إلى الباقة ${planLabels[widget.pending!['plan']]} قيد مراجعة الإدارة، وتوصلك رسالة عند التفعيل.',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, height: 1.5)),
                  ),
                ]),
              )
            else
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (widget.onRenew != null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: colors.first),
                    onPressed: widget.onRenew,
                    icon: const Icon(Icons.autorenew),
                    label: const Text('طلب تجديد الاشتراك'),
                  ),
                if (widget.onUpgrade != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70)),
                    onPressed: widget.onUpgrade,
                    icon: const Icon(Icons.trending_up),
                    label: const Text('ترقية الباقة'),
                  ),
              ]),
          ]),
        ),
      ]),
    );
  }
}

class PlanRequestRow extends StatelessWidget {
  const PlanRequestRow({super.key, required this.r});
  final Map<String, dynamic> r;
  @override
  Widget build(BuildContext context) {
    final st = '${r['status']}';
    final c = planReqColors(st);
    final look = planLook['${r['plan']}'] ?? planLook['monthly']!;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          GradientBadge(colors: look.$2, icon: look.$1, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '#${r['code']} · ${r['kind'] == 'upgrade' ? 'ترقية' : 'تجديد'} ${planLabels[r['from_plan']]} ← ${planLabels[r['plan']]}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                      '${dateTimeText(r['created_at'])} · ${bhd(r['amount'])}'
                      '${r['new_ends'] != null ? ' · ساري حتى ${dateText(r['new_ends'])}' : ''}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                  if (st == 'rejected' && r['admin_note'] != null)
                    Text('السبب: ${r['admin_note']}',
                        style: TextStyle(fontSize: 12, color: c.first)),
                ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: c),
                borderRadius: BorderRadius.circular(999)),
            child: Text(planReqLabels[st] ?? st,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- choose a plan

class PlanPickerPage extends StatefulWidget {
  const PlanPickerPage(
      {super.key,
      required this.merchant,
      required this.settings,
      required this.upgrade});
  final Map<String, dynamic> merchant;
  final Map<String, dynamic> settings;
  final bool upgrade;
  @override
  State<PlanPickerPage> createState() => _PlanPickerPageState();
}

class _PlanPickerPageState extends State<PlanPickerPage> {
  late final current = '${widget.merchant['plan']}';
  late final options = [
    for (final p in ['monthly', 'yearly'])
      if (!widget.upgrade || planRank[p]! > planRank[current]!) p
  ];
  late String pick = widget.upgrade ? options.last : current;

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final monthly = planPrice(s, 'monthly');
    final yearly = planPrice(s, 'yearly');
    final saving = monthly * 12 - yearly;
    final notes = {
      'monthly': 'يتجدد كل شهر، مناسب للبداية',
      'yearly': saving > 0
          ? 'توفر ${bhd(saving)} مقارنة بالشهري'
          : 'سنة كاملة بدون انقطاع',
    };
    return Scaffold(
      appBar: GradientAppBar(
          title: Text(widget.upgrade ? 'ترقية الباقة' : 'تجديد الاشتراك')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
            widget.upgrade
                ? 'اختر الباقة التي تريد الترقية إليها. تبدأ الباقة الجديدة من يوم التفعيل.'
                : 'اختر الباقة. التجديد يضاف بعد نهاية اشتراكك الحالي فلا تخسر أي يوم.',
            style: const TextStyle(color: Colors.black54, height: 1.5)),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 620 ? options.length : 1;
          final w = (c.maxWidth - 12 * (cols - 1)) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final p in options)
              SizedBox(
                width: w,
                child: _PlanOption(
                  plan: p,
                  price: planPrice(s, p),
                  note: notes[p]!,
                  current: p == current,
                  best: p == 'yearly',
                  selected: pick == p,
                  onTap: () => setState(() => pick = p),
                ),
              ),
          ]);
        }),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: (planLook[pick] ?? planLook['monthly']!).$2.first,
              padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: () async {
            final done = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => PlanPaymentPage(
                        merchant: widget.merchant,
                        settings: s,
                        plan: pick,
                        upgrade: widget.upgrade)));
            if (done == true && context.mounted) Navigator.pop(context, true);
          },
          icon: const Icon(Icons.payments_outlined),
          label: Text(
              'متابعة للدفع · ${planLabels[pick]} · ${bhd(planPrice(s, pick))}'),
        ),
      ]),
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption(
      {required this.plan,
      required this.price,
      required this.note,
      required this.current,
      required this.best,
      required this.selected,
      required this.onTap});
  final String plan;
  final num price;
  final String note;
  final bool current;
  final bool best;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final look = planLook[plan]!;
    final cs = look.$2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: selected
              ? LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: cs)
              : null,
          color: selected ? null : Colors.white,
          border: Border.all(
              color: selected ? Colors.transparent : cs.first.withValues(alpha: .3),
              width: 1.5),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: cs.first.withValues(alpha: .3),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ]
              : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(look.$1, color: selected ? Colors.white : cs.first, size: 28),
            const Spacer(),
            if (current) _tag('باقتك الحالية', selected, cs.first),
            if (best && !current) _tag('الأوفر', selected, cs.first),
            const SizedBox(width: 6),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Colors.white : cs.first),
          ]),
          const SizedBox(height: 12),
          Text('الباقة ${planLabels[plan]}',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text(bhd(price),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : cs.first)),
          Text(plan == 'yearly' ? 'لمدة سنة' : 'لمدة شهر',
              style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white70 : Colors.black54)),
          const SizedBox(height: 10),
          Text(note,
              style: TextStyle(
                  fontSize: 13,
                  color: selected ? Colors.white : Colors.black54)),
        ]),
      ),
    );
  }

  Widget _tag(String t, bool selected, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: selected ? Colors.white : c.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(999)),
        child: Text(t,
            style:
                TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
      );
}

// ---------------------------------------------------------------- payment + receipt

class PlanPaymentPage extends StatefulWidget {
  const PlanPaymentPage(
      {super.key,
      required this.merchant,
      required this.settings,
      required this.plan,
      required this.upgrade});
  final Map<String, dynamic> merchant;
  final Map<String, dynamic> settings;
  final String plan;
  final bool upgrade;
  @override
  State<PlanPaymentPage> createState() => _PlanPaymentPageState();
}

class _PlanPaymentPageState extends State<PlanPaymentPage> {
  PlatformFile? receipt;
  final ref = TextEditingController();
  final note = TextEditingController();
  bool busy = false;

  Future<void> submit() async {
    if (receipt?.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ارفع صورة إيصال التحويل أولاً')));
      return;
    }
    setState(() => busy = true);
    final r = await guard(context, () async {
      final safe = receipt!.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path =
          '$myId/sub-${widget.merchant['id']}-${DateTime.now().millisecondsSinceEpoch}-$safe';
      await sb.storage.from('docs').uploadBinary(path, receipt!.bytes!);
      return await sb.rpc('merchant_request_plan', params: {
        'p_merchant': widget.merchant['id'],
        'p_plan': widget.plan,
        'p_receipt': path,
        'p_ref': ref.text.trim(),
        'p_note': note.text.trim(),
      });
    }, ok: 'وصل طلبك للإدارة، ويتفعّل الاشتراك بعد مراجعة الإيصال');
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final look = planLook[widget.plan]!;
    final cs = look.$2;
    final amount = planPrice(s, widget.plan);
    final iban = '${s['platform_iban'] ?? ''}';
    final start = !widget.upgrade
        ? (planEnd(widget.merchant['plan_ends']).isAfter(DateTime.now())
            ? DateTime.tryParse('${widget.merchant['plan_ends']}')!
            : DateTime.now())
        : DateTime.now();
    final ends = start.add(Duration(days: planDays(s, widget.plan)));
    Widget step(int n, String t) => Row(children: [
          CircleAvatar(
              radius: 13,
              backgroundColor: cs.first,
              child: Text('$n',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]);
    return Scaffold(
      appBar: const GradientAppBar(title: Text('الدفع ورفع الإيصال')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: cs),
              ),
              child: Row(children: [
                Icon(look.$1, color: Colors.white, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${widget.upgrade ? 'ترقية إلى' : 'تجديد'} الباقة ${planLabels[widget.plan]}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                        Text('ساري تقريباً حتى ${dateText(isoDate(ends))} بعد التفعيل',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12.5)),
                      ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('المبلغ',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(bhd(amount),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      step(1, 'حوّل المبلغ إلى حساب المنصة'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: cs.first.withValues(alpha: .06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: cs.first.withValues(alpha: .2))),
                        child: Row(children: [
                          Icon(Icons.account_balance_outlined, color: cs.first),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('IBAN حساب المنصة',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.black54)),
                                  SelectableText(
                                      iban.isEmpty ? 'يضاف من الإدارة' : iban,
                                      textDirection: TextDirection.ltr,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: .5)),
                                ]),
                          ),
                          if (iban.isNotEmpty)
                            IconButton(
                              tooltip: 'نسخ',
                              icon: const Icon(Icons.copy_outlined),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: iban));
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('تم نسخ رقم الحساب')));
                              },
                            ),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      step(2, 'ارفع إيصال التحويل'),
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final r = await FilePicker.platform.pickFiles(
                              withData: true,
                              type: FileType.custom,
                              allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']);
                          if (r != null) setState(() => receipt = r.files.first);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 22, horizontal: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: receipt == null
                                ? const Color(0xFFF7F9FA)
                                : G.emerald.first.withValues(alpha: .07),
                            border: Border.all(
                                color: receipt == null
                                    ? Colors.black12
                                    : G.emerald.first.withValues(alpha: .5),
                                width: 1.5),
                          ),
                          child: Column(children: [
                            Icon(
                                receipt == null
                                    ? Icons.cloud_upload_outlined
                                    : Icons.task_alt,
                                size: 34,
                                color: receipt == null
                                    ? cs.first
                                    : G.emerald.first),
                            const SizedBox(height: 6),
                            Text(
                                receipt == null
                                    ? 'اضغط لاختيار صورة أو ملف PDF للإيصال'
                                    : receipt!.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if (receipt != null)
                              const Text('اضغط للتغيير',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Field('رقم العملية / المرجع', ref, ltr: true),
                      const SizedBox(height: 10),
                      Field('ملاحظة للإدارة', note, maxLines: 2),
                      const SizedBox(height: 18),
                      step(3, 'أرسل الطلب'),
                      const SizedBox(height: 6),
                      const Text(
                          'تراجع الإدارة الإيصال وتفعّل الباقة، وتوصلك رسالة بالنتيجة.',
                          style: TextStyle(fontSize: 12.5, color: Colors.black54)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: cs.first,
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: busy ? null : submit,
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_outlined),
                        label: const Text('إرسال طلب الاشتراك'),
                      ),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
