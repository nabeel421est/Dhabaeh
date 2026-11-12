import 'package:flutter/material.dart' hide Text;

import '../auth/gate.dart';
import '../core/brand.dart';
import '../core/common.dart';
import '../core/payouts.dart';
import '../admin/admin_money.dart' show Kpi;
import 'merchant_pages.dart';
import 'merchant_store.dart';
import '../core/ttext.dart';
import '../core/i18n.dart';
import '../core/order_alerts.dart';
import '../customer/order_details.dart';

class MerchantShell extends StatefulWidget {
  const MerchantShell(
      {super.key,
      required this.merchantIds,
      required this.owner,
      this.switcher});
  final List<String> merchantIds;
  final bool owner;
  final Widget? switcher;
  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> {
  late String mid = widget.merchantIds.isEmpty ? '' : widget.merchantIds.first;
  int tab = 0;
  late Future<(Map<String, dynamic>, Map<String, dynamic>)> ctx = load();

  Future<(Map<String, dynamic>, Map<String, dynamic>)> load() async {
    final m = await sb.from('merchants').select().eq('id', mid).single();
    final adminPerms = Map<String, dynamic>.from(m['perms'] ?? {});
    Map<String, dynamic> mine;
    if (widget.owner) {
      mine = adminPerms;
    } else {
      final s = await sb
          .from('merchant_staff')
          .select('perms')
          .eq('merchant_id', mid)
          .eq('user_id', myId!)
          .single();
      final sp = Map<String, dynamic>.from(s['perms'] ?? {});
      mine = {
        for (final k in merchantPermLabels.keys)
          k: adminPerms[k] == true && sp[k] == true
      };
    }
    return (m, mine);
  }

  @override
  Widget build(BuildContext context) {
    if (mid.isEmpty) {
      return Scaffold(
          appBar:
              GradientAppBar(actions: commonActions(context, widget.switcher)),
          body: const Empty('الحساب غير مرتبط بمتجر بعد'));
    }
    return FutureBuilder(
      future: ctx,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
              appBar: GradientAppBar(
                  actions: commonActions(context, widget.switcher)),
              body: Center(child: Text(errText(snap.error!))));
        }
        if (!snap.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        final (m, perms) = snap.data!;
        final tabs = <(String, IconData, Widget)>[
          if (perms['orders'] == true)
            ('الطلبات', Icons.receipt_long_outlined, MerchantOrders(mid: mid)),
          if (perms['products'] == true)
            (
              'المنتجات',
              Icons.inventory_2_outlined,
              MerchantProducts(mid: mid, canPrice: perms['pricing'] == true)
            ),
          if (perms['offers'] == true)
            ('العروض', Icons.local_offer_outlined, MerchantOffers(mid: mid)),
          if (perms['wallet'] == true)
            (
              'المحفظة',
              Icons.account_balance_wallet_outlined,
              MerchantWallet(
                  mid: mid, frozen: m['frozen'] == true, owner: widget.owner)
            ),
          if (perms['staff'] == true)
            ('الموظفون', Icons.group_outlined, MerchantStaffTab(mid: mid)),
          if (widget.owner)
            (
              'المتجر',
              Icons.storefront_outlined,
              StoreSettings(
                  merchant: m, onSaved: () => setState(() => ctx = load()))
            ),
        ];
        if (tabs.isEmpty) {
          return Scaffold(
              appBar: GradientAppBar(
                  title: Text(m['name']),
                  actions: commonActions(context, widget.switcher)),
              body: const Empty('لا توجد صلاحيات ممنوحة لهذا الحساب'));
        }
        if (tab >= tabs.length) tab = 0;
        return OrderAlertWatcher(
            enabled: perms['orders'] == true,
            title: 'طلب جديد',
            fetch: () => newOrderAlerts(merchantId: mid),
            onOpen: (c, id) => Navigator.push(
                c,
                MaterialPageRoute(
                    builder: (_) =>
                        OrderDetailsPage(orderId: id, viewer: 'merchant'))),
            child: Scaffold(
              appBar: GradientAppBar(
                logo: true,
                title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m['name']),
                      Text(widget.owner ? 'مالك المتجر' : 'موظف',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                    ]),
                actions: [
                  if (widget.merchantIds.length > 1)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.store),
                      onSelected: (v) => setState(() {
                        mid = v;
                        ctx = load();
                      }),
                      itemBuilder: (_) => [
                        for (final id in widget.merchantIds)
                          PopupMenuItem(
                              value: id, child: Text(id.substring(0, 8)))
                      ],
                    ),
                  ...commonActions(context, widget.switcher),
                ],
              ),
              body: Column(children: [
                if (m['suspended'] == true || m['frozen'] == true)
                  MaterialBanner(
                    content: Text(m['frozen'] == true
                        ? 'المتجر مجمّد من الإدارة: الحساب مقفل والمحفظة مجمّدة'
                        : 'المتجر موقوف من الإدارة: لا يظهر للعملاء ولا يستقبل طلبات جديدة'),
                    backgroundColor: const Color(0xFFFBE9E7),
                    actions: const [SizedBox.shrink()],
                  ),
                Expanded(
                    child: IndexedStack(
                        index: tab, children: [for (final t in tabs) t.$3])),
              ]),
              bottomNavigationBar: tabs.length < 2
                  ? null
                  : NavigationBar(
                      selectedIndex: tab,
                      onDestinationSelected: (i) => setState(() => tab = i),
                      destinations: [
                        for (final t in tabs)
                          NavigationDestination(
                              icon: Icon(t.$2), label: tr(t.$1))
                      ],
                    ),
            ));
      },
    );
  }
}

class MerchantWallet extends StatelessWidget {
  const MerchantWallet(
      {super.key, required this.mid, required this.frozen, this.owner = false});
  final String mid;
  final bool frozen;
  final bool owner;

  Future<void> requestPayout(BuildContext context, num available,
      Future<void> Function() reload) async {
    final amount = TextEditingController(
        text: available > 0 ? available.toStringAsFixed(3) : '');
    final note = TextEditingController();
    final b = brandOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              gradient: b.gradient,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22))),
          child: Row(children: [
            Icon(Icons.outbox_outlined, color: b.accent),
            const SizedBox(width: 10),
            const Expanded(
                child: Text('طلب سحب الرصيد',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700))),
          ]),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('المتاح للسحب: ${bhd(available)}',
                    style:
                        TextStyle(color: b.dark, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                    'يُحوَّل المبلغ لحسابك البنكي المسجّل لدى الإدارة، وتتابع المراحل هنا في المحفظة.',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 14),
                Field('المبلغ (د.ب)', amount,
                    required: true,
                    keyboard:
                        const TextInputType.numberWithOptions(decimal: true),
                    ltr: true),
                const SizedBox(height: 10),
                Field('ملاحظة للإدارة', note, maxLines: 2),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton.icon(
              onPressed: () => Navigator.pop(c, true),
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('إرسال الطلب')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await guard(
        context,
        () => sb.rpc('merchant_request_payout', params: {
              'p_merchant': mid,
              'p_amount': num.tryParse(amount.text.trim()) ?? 0,
              'p_note': note.text.trim()
            }),
        ok: 'وصل طلبك للإدارة');
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Loader<
        (
          List<Map<String, dynamic>>,
          List<Map<String, dynamic>>,
          List<Map<String, dynamic>>
        )>(
      realtimeTables: const [
        'wallet_ledger',
        'payout_requests',
        'payout_events'
      ],
      load: () async {
        final rows = await sb
            .from('wallet_ledger')
            .select()
            .eq('merchant_id', mid)
            .order('created_at', ascending: false);
        final reqs = await sb
            .from('payout_requests')
            .select()
            .eq('merchant_id', mid)
            .order('created_at', ascending: false);
        final ids = [for (final r in reqs) r['id']];
        final evs = ids.isEmpty
            ? []
            : await sb
                .from('payout_events')
                .select()
                .inFilter('request_id', ids)
                .order('created_at');
        return (
          List<Map<String, dynamic>>.from(rows),
          List<Map<String, dynamic>>.from(reqs),
          List<Map<String, dynamic>>.from(evs)
        );
      },
      builder: (context, data, reload) {
        final (rows, reqs, evs) = data;
        final b = brandOf(context);
        final bal = rows.fold<num>(0, (a, r) => a + toNum(r['amount']));
        final pending = reqs
            .where((r) =>
                ['requested', 'under_review', 'approved'].contains(r['status']))
            .fold<num>(0, (a, r) => a + toNum(r['amount']));
        final available = bal - pending;
        return ListView(padding: const EdgeInsets.all(16), children: [
          GradientCard(
            padding: const EdgeInsets.all(22),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.account_balance_wallet_outlined, color: b.accent),
                const SizedBox(width: 8),
                const Text('رصيد المحفظة',
                    style: TextStyle(color: Colors.white70)),
              ]),
              const SizedBox(height: 6),
              Text(bhd(bal),
                  style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child:
                        _walletStat('المتاح للسحب', bhd(available), b.accent)),
                const SizedBox(width: 10),
                Expanded(
                    child: _walletStat(
                        'طلبات قيد التنفيذ', bhd(pending), Colors.white)),
              ]),
              const SizedBox(height: 14),
              if (owner && !frozen)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: b.dark),
                    onPressed: available <= 0
                        ? null
                        : () => requestPayout(context, available, reload),
                    icon: const Icon(Icons.outbox_outlined),
                    label: Text(available <= 0
                        ? 'لا يوجد رصيد متاح للسحب'
                        : 'طلب سحب الرصيد'),
                  ),
                ),
              if (frozen)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(999)),
                  child: const Text('المحفظة مجمّدة من الإدارة',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 8),
              const Text(
                  'يُضاف صافي كل طلب بعد التسليم مخصوماً منه عمولة المنصة.',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 700 ? 3 : 1;
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            final inc = rows
                .where((r) => toNum(r['amount']) > 0)
                .fold<num>(0, (a, r) => a + toNum(r['amount']));
            final outc = rows
                .where((r) => toNum(r['amount']) < 0)
                .fold<num>(0, (a, r) => a - toNum(r['amount']));
            final paid = reqs
                .where((r) => r['status'] == 'transferred')
                .fold<num>(0, (a, r) => a + toNum(r['amount']));
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: w,
                  child: Kpi(
                      label: 'إجمالي الإيداعات',
                      value: bhd(inc),
                      icon: Icons.south_west,
                      colors: G.emerald)),
              SizedBox(
                  width: w,
                  child: Kpi(
                      label: 'إجمالي الخصومات',
                      value: bhd(outc),
                      icon: Icons.north_east,
                      colors: G.ruby)),
              SizedBox(
                  width: w,
                  child: Kpi(
                      label: 'تم تحويله لحسابك',
                      value: bhd(paid),
                      icon: Icons.account_balance_outlined,
                      colors: G.sapphire)),
            ]);
          }),
          const SizedBox(height: 16),
          Row(children: [
            Icon(Icons.outbox_outlined, color: b.primary),
            const SizedBox(width: 8),
            const Text('طلبات السحب',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          if (reqs.isEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                    owner
                        ? 'ما عندك طلبات سحب. اضغط "طلب سحب الرصيد" وتتابع مراحله هنا.'
                        : 'لا توجد طلبات سحب',
                    style: const TextStyle(color: Colors.black54)),
              ),
            ),
          for (final r in reqs) ...[
            PayoutCard(
                r: r,
                events: evs.where((e) => e['request_id'] == r['id']).toList()),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          SectionCard(
            title: 'الحركات',
            child: rows.isEmpty
                ? const Text('لا توجد حركات بعد')
                : Column(children: [
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          GradientBadge(
                            colors:
                                toNum(r['amount']) >= 0 ? G.emerald : G.ruby,
                            icon: toNum(r['amount']) >= 0
                                ? Icons.south_west
                                : Icons.north_east,
                            size: 36,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r['note'] ?? r['kind'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text(dateTimeText(r['created_at']),
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54)),
                                ]),
                          ),
                          Text(bhd(r['amount']),
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: toNum(r['amount']) >= 0
                                      ? G.emerald.first
                                      : G.ruby.first)),
                        ]),
                      ),
                  ]),
          ),
        ]);
      },
    );
  }

  Widget _walletStat(String k, String v, Color c) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          Text(v,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: c)),
        ]),
      );
}

class MerchantStaffTab extends StatelessWidget {
  const MerchantStaffTab({super.key, required this.mid});
  final String mid;

  Future<void> add(BuildContext context, Future<void> Function() reload) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final pass = TextEditingController();
    final title = TextEditingController(text: 'موظف');
    final perms = {for (final k in merchantPermLabels.keys) k: k == 'orders'};
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('إضافة موظف'),
          content: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Field('الاسم', name, required: true),
                const SizedBox(height: 10),
                Field('رقم الجوال', phone,
                    required: true, keyboard: TextInputType.phone, ltr: true),
                const SizedBox(height: 10),
                Field('كلمة مرور مبدئية', pass,
                    required: true,
                    note: 'للحساب الجديد فقط، 6 أحرف على الأقل'),
                const SizedBox(height: 10),
                Field('المسمى', title),
                const SizedBox(height: 10),
                for (final e in merchantPermLabels.entries)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: perms[e.key],
                    title: Text(e.value),
                    onChanged: (v) => set(() => perms[e.key] = v == true),
                  ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) Navigator.pop(c, true);
                },
                child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await guard(
        context,
        () => usersFn({
              'action': 'merchant_add_staff',
              'merchant_id': mid,
              'full_name': name.text.trim(),
              'phone': normPhone(phone.text),
              'password': pass.text,
              'title': title.text.trim(),
              'perms': perms,
            }),
        ok: 'تمت إضافة الموظف');
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('merchant_staff')
          .select('*, profiles(full_name, phone)')
          .eq('merchant_id', mid)),
      builder: (context, staff, reload) => Stack(children: [
        staff.isEmpty
            ? ListView(children: const [Empty('لا يوجد موظفون')])
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                    for (final s in staff)
                      Card(
                        child: ListTile(
                          title: Text(
                              '${s['profiles']?['full_name'] ?? ''} · ${s['title']}'),
                          subtitle: Text(merchantPermLabels.entries
                              .where((e) => s['perms']?[e.key] == true)
                              .map((e) => e.value)
                              .join('، ')),
                          trailing: IconButton(
                            tooltip: tr('إزالة'),
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed: () async {
                              await guard(
                                  context,
                                  () => sb
                                      .from('merchant_staff')
                                      .delete()
                                      .eq('merchant_id', mid)
                                      .eq('user_id', s['user_id']),
                                  ok: 'تمت الإزالة');
                              await reload();
                            },
                          ),
                        ),
                      ),
                  ]),
        Positioned(
          left: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
              onPressed: () => add(context, reload),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('موظف جديد')),
        ),
      ]),
    );
  }
}
