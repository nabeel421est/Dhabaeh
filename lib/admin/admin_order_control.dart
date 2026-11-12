import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/common.dart';
import '../core/i18n.dart';
import '../core/ttext.dart';
import '../customer/order_details.dart';

Future<Map<String, dynamic>> loadAccess() async =>
    Map<String, dynamic>.from(await sb.rpc('admin_access_list') as Map);

/// Order control: locked behind a password the super admin sets (one master
/// password, or a personal one per admin). Once open, any order can be edited,
/// held, deleted, moved to another store or given to another driver.
class AdminOrderControl extends StatefulWidget {
  const AdminOrderControl({super.key});
  @override
  State<AdminOrderControl> createState() => _AdminOrderControlState();
}

class _AdminOrderControlState extends State<AdminOrderControl> {
  String? token;
  DateTime? until;
  Map<String, dynamic>? access;
  Object? accessError;
  final pass = TextEditingController();
  bool busy = false, hide = true;
  Timer? tick;

  @override
  void initState() {
    super.initState();
    refreshAccess();
    tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (token != null && until != null && DateTime.now().isAfter(until!)) {
        lock(msg: 'انتهت الجلسة، أدخل كلمة المرور مرة أخرى');
      } else if (token != null && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    tick?.cancel();
    super.dispose();
  }

  Future<void> refreshAccess() async {
    try {
      final a = await loadAccess();
      if (mounted) setState(() => access = a);
    } catch (e) {
      if (mounted) setState(() => accessError = e);
    }
  }

  void lock({String? msg}) {
    if (!mounted) return;
    setState(() {
      token = null;
      until = null;
    });
    if (msg != null) toast(context, msg, error: true);
  }

  Future<void> unlock() async {
    if (pass.text.isEmpty) return;
    setState(() => busy = true);
    try {
      final t = await sb.rpc('oc_unlock', params: {'p_password': pass.text});
      if (!mounted) return;
      if (t == null) {
        toast(context, 'كلمة المرور غير صحيحة', error: true);
      } else {
        pass.clear();
        setState(() {
          token = '$t';
          until = DateTime.now().add(const Duration(minutes: 30));
        });
      }
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
    if (mounted) setState(() => busy = false);
  }

  /// Runs a control action; a dead session locks the page again.
  Future<bool> act(Future<dynamic> Function(String token) fn,
      {required String ok}) async {
    try {
      await fn(token!);
      if (mounted) toast(context, ok);
      return true;
    } catch (e) {
      final m = errText(e);
      if (m.contains('انتهت جلسة')) {
        lock(msg: m);
      } else if (mounted) {
        toast(context, m, error: true);
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (access == null) {
      return accessError != null
          ? Empty(errText(accessError!), icon: Icons.error_outline)
          : const Center(child: CircularProgressIndicator());
    }
    if (token == null) return lockScreen(context);
    return _ControlBoard(
      until: until!,
      onLock: () => lock(),
      act: act,
      isSuper: access!['me']?['super'] == true,
      sectionSet: access!['any_key'] == true,
      onAccess: () => openAccessPanel(context).then((_) => refreshAccess()),
    );
  }

  Widget lockScreen(BuildContext context) {
    final b = brandOf(context);
    final me = Map<String, dynamic>.from(access!['me'] ?? {});
    final isSuper = me['super'] == true;
    final anyKey = access!['any_key'] == true;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            GradientCard(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              child: Column(children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Colors.white.withValues(alpha: .28),
                      Colors.white.withValues(alpha: .06)
                    ]),
                    border: Border.all(color: b.accent, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: b.accent.withValues(alpha: .35),
                          blurRadius: 24)
                    ],
                  ),
                  child: Icon(Icons.lock_outline, size: 38, color: b.accent),
                ),
                const SizedBox(height: 14),
                const Text('التحكم في الطلبات',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    anyKey
                        ? 'قسم محمي. أدخل كلمة مرور القسم'
                        : isSuper
                            ? 'أول دخول: استخدم كلمة مرور حسابك كمدير عام'
                            : 'قسم محمي. أدخل كلمة المرور التي حددها المدير العام',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!anyKey)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                              isSuper
                                  ? 'لم تُحدد كلمة مرور خاصة للقسم بعد، فادخل بكلمة مرور حسابك، ثم خصّص كلمة مرور للقسم من «الصلاحيات وكلمات المرور» داخله.'
                                  : 'لم يحدد المدير العام كلمة مرور لهذا القسم بعد.',
                              style: TextStyle(color: G.amber.first)),
                        ),
                      TextField(
                        controller: pass,
                        obscureText: hide,
                        textDirection: TextDirection.ltr,
                        onSubmitted: (_) => unlock(),
                        decoration: InputDecoration(
                          labelText: tr(anyKey || !isSuper
                              ? 'كلمة مرور القسم'
                              : 'كلمة مرور حسابك'),
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: IconButton(
                              onPressed: () => setState(() => hide = !hide),
                              icon: Icon(hide
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: busy ? null : unlock,
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.lock_open_outlined),
                        label: const Text('فتح القسم'),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                          'تبقى الجلسة مفتوحة 30 دقيقة. بعد 5 محاولات خاطئة يُقفل القسم 15 دقيقة.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.black45, fontSize: 12)),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

const _holdTone = G.amber;
const _deletedTone = G.ruby;

class _ControlBoard extends StatefulWidget {
  const _ControlBoard(
      {required this.until,
      required this.onLock,
      required this.act,
      required this.isSuper,
      required this.sectionSet,
      required this.onAccess});
  final bool sectionSet;
  final DateTime until;
  final VoidCallback onLock;
  final VoidCallback onAccess;
  final bool isSuper;
  final Future<bool> Function(Future<dynamic> Function(String token) fn,
      {required String ok}) act;
  @override
  State<_ControlBoard> createState() => _ControlBoardState();
}

typedef _BoardData = (
  List<Map<String, dynamic>> orders,
  List<Map<String, dynamic>> stores,
  List<Map<String, dynamic>> drivers,
);

class _ControlBoardState extends State<_ControlBoard> {
  String filter = 'open';
  String store = 'all';
  final q = TextEditingController();

  static const filters = <String, (String, IconData, List<Color>)>{
    'open': ('الطلبات الجارية', Icons.timelapse_outlined, G.sapphire),
    'all': ('الكل', Icons.apps_outlined, G.midnight),
    'held': ('موقوفة', Icons.pause_circle_outline, _holdTone),
    'closed': ('مكتملة وملغاة', Icons.task_alt_outlined, G.teal),
    'deleted': ('محذوفة', Icons.delete_outline, _deletedTone),
  };

  bool match(Map o, String f) {
    final del = o['deleted_at'] != null;
    final open = !['delivered', 'cancelled'].contains(o['status']);
    return switch (f) {
      'deleted' => del,
      'held' => !del && o['held'] == true,
      'open' => !del && open,
      'closed' => !del && !open,
      _ => !del,
    };
  }

  Future<_BoardData> load() async {
    final o = await sb
        .from('orders')
        .select('*, merchants(name)')
        .order('created_at', ascending: false)
        .limit(400);
    final m =
        await sb.from('merchants').select('id, name, suspended').order('name');
    final r = await sb
        .from('user_roles')
        .select('user_id, profiles(full_name, phone, deleted_at, is_active)')
        .eq('role', 'driver');
    return (
      List<Map<String, dynamic>>.from(o),
      List<Map<String, dynamic>>.from(m),
      [
        for (final d in r)
          if (d['profiles']?['deleted_at'] == null)
            {
              'id': d['user_id'],
              'name': d['profiles']?['full_name'] ?? '',
              'phone': d['profiles']?['phone'] ?? '',
            }
      ],
    );
  }

  Future<String?> askReason(BuildContext context, String title,
      {String hint = 'السبب (اختياري)',
      String action = 'تأكيد',
      List<Color> tone = G.sapphire,
      bool required = false}) async {
    final c = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Form(
              key: form,
              child: Field(hint, c, maxLines: 3, required: required)),
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
              child: Text(action)),
        ],
      ),
    );
    return ok == true ? c.text.trim() : null;
  }

  Future<void> editOrder(BuildContext context, Map<String, dynamic> o,
      Future<void> Function() reload) async {
    final f = <String, TextEditingController>{
      for (final k in [
        'customer_name',
        'customer_phone',
        'slaughter_time',
        'delivery_slot',
        'address',
        'notes'
      ])
        k: TextEditingController(text: '${o[k] ?? ''}'),
    };
    DateTime? sd = DateTime.tryParse('${o['slaughter_date'] ?? ''}');
    DateTime? dd = DateTime.tryParse('${o['delivery_date'] ?? ''}');
    Widget dateBtn(BuildContext c, String label, DateTime? v,
            void Function(DateTime) on) =>
        OutlinedButton.icon(
          icon: const Icon(Icons.event_outlined),
          onPressed: () async {
            final d = await showDatePicker(
                context: c,
                initialDate: v ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)));
            if (d != null) on(d);
          },
          label:
              Text('${tr(label)}: ${v == null ? '—' : dateText(isoDate(v))}'),
        );
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('${tr('تعديل الطلب')} #${o['code']}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(child: Field('اسم العميل', f['customer_name']!)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Field('جوال العميل', f['customer_phone']!,
                          ltr: true, keyboard: TextInputType.phone)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: dateBtn(
                          c, 'تاريخ الذبح', sd, (d) => set(() => sd = d))),
                  const SizedBox(width: 10),
                  Expanded(child: Field('وقت الذبح', f['slaughter_time']!)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: dateBtn(
                          c,
                          o['fulfillment'] == 'pickup'
                              ? 'تاريخ الاستلام'
                              : 'تاريخ التوصيل',
                          dd,
                          (d) => set(() => dd = d))),
                  const SizedBox(width: 10),
                  Expanded(child: Field('الفترة', f['delivery_slot']!)),
                ]),
                const SizedBox(height: 10),
                Field('العنوان', f['address']!, maxLines: 2),
                const SizedBox(height: 10),
                Field('ملاحظات', f['notes']!, maxLines: 3),
                const SizedBox(height: 8),
                const Text(
                    'الأسعار والأصناف لا تُعدّل من هنا حفاظاً على صحة المحافظ والعمولات.',
                    style: TextStyle(color: Colors.black45, fontSize: 12)),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('حفظ التعديل')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final fields = {
      for (final e in f.entries) e.key: e.value.text.trim(),
      'slaughter_date': sd == null ? '' : isoDate(sd!),
      'delivery_date': dd == null ? '' : isoDate(dd!),
    };
    if (await widget.act(
        (t) => sb.rpc('oc_update_order',
            params: {'p_token': t, 'p_order': o['id'], 'p_fields': fields}),
        ok: 'تم حفظ التعديل')) {
      await reload();
    }
  }

  Future<void> changeStatus(BuildContext context, Map<String, dynamic> o,
      Future<void> Function() reload) async {
    final s = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('${tr('تغيير حالة الطلب')} #${o['code']}'),
        children: [
          for (final k in statusLabels.keys)
            if (k != o['status'] &&
                !(o['fulfillment'] == 'pickup' && k == 'out_for_delivery'))
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, k),
                child: Row(children: [
                  Icon(Icons.circle, size: 12, color: statusColor(k)),
                  const SizedBox(width: 10),
                  Text(statusLabels[k]!),
                ]),
              ),
        ],
      ),
    );
    if (s == null || !context.mounted) return;
    if (s == 'delivered' || s == 'cancelled') {
      final sure = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(s == 'delivered' ? 'تأكيد التسليم؟' : 'إلغاء الطلب؟'),
          content: Text(s == 'delivered'
              ? 'سيُغلق الطلب وتُضاف مبالغه للمحافظ.'
              : 'سيُغلق الطلب ولا يمكن إعادة فتحه.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('رجوع')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('تأكيد')),
          ],
        ),
      );
      if (sure != true || !context.mounted) return;
    }
    if (await widget.act(
        (t) => sb.rpc('oc_set_status',
            params: {'p_token': t, 'p_order': o['id'], 'p_status': s}),
        ok: 'تم تغيير الحالة')) {
      await reload();
    }
  }

  Future<void> hold(BuildContext context, Map<String, dynamic> o,
      Future<void> Function() reload) async {
    final on = o['held'] != true;
    String? reason = '';
    if (on) {
      reason = await askReason(context, '${tr('إيقاف الطلب')} #${o['code']}',
          hint: 'سبب الإيقاف (يصل للتاجر)', action: 'إيقاف', tone: _holdTone);
      if (reason == null) return;
    }
    if (!context.mounted) return;
    if (await widget.act(
        (t) => sb.rpc('oc_hold', params: {
              'p_token': t,
              'p_order': o['id'],
              'p_hold': on,
              'p_reason': reason
            }),
        ok: on ? 'تم إيقاف الطلب' : 'تم استئناف الطلب')) {
      await reload();
    }
  }

  Future<void> remove(BuildContext context, Map<String, dynamic> o,
      Future<void> Function() reload) async {
    final restore = o['deleted_at'] != null;
    String? reason;
    if (!restore) {
      reason = await askReason(context, '${tr('حذف الطلب')} #${o['code']}',
          hint: 'سبب الحذف', action: 'حذف', tone: _deletedTone, required: true);
      if (reason == null) return;
    }
    if (!context.mounted) return;
    if (await widget.act(
        (t) => sb.rpc('oc_delete', params: {
              'p_token': t,
              'p_order': o['id'],
              'p_reason': reason,
              'p_restore': restore
            }),
        ok: restore ? 'تم استرجاع الطلب' : 'تم حذف الطلب')) {
      await reload();
    }
  }

  Future<void> transfer(BuildContext context, Map<String, dynamic> o,
      List<Map<String, dynamic>> stores, Future<void> Function() reload) async {
    final to = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('${tr('تحويل الطلب')} #${o['code']} ${tr('إلى تاجر آخر')}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
                'يعود الطلب «جديد» لدى المتجر الجديد ليقبله، ويُلغى إسناد المندوب.',
                style: TextStyle(color: Colors.black54, fontSize: 12.5)),
          ),
          for (final m in stores)
            if (m['id'] != o['merchant_id'])
              SimpleDialogOption(
                onPressed: m['suspended'] == true
                    ? null
                    : () => Navigator.pop(c, m['id'] as String),
                child: Row(children: [
                  GradientBadge(
                      colors: m['suspended'] == true
                          ? [Colors.blueGrey, Colors.blueGrey.shade200]
                          : G.sapphire,
                      icon: Icons.storefront_outlined,
                      size: 34),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${m['name']}')),
                  if (m['suspended'] == true)
                    const Text('موقوف',
                        style: TextStyle(color: Colors.black38)),
                ]),
              ),
        ],
      ),
    );
    if (to == null || !context.mounted) return;
    final reason = await askReason(context, 'سبب التحويل',
        action: 'تحويل', tone: G.violet);
    if (reason == null || !context.mounted) return;
    if (await widget.act(
        (t) => sb.rpc('oc_transfer_merchant', params: {
              'p_token': t,
              'p_order': o['id'],
              'p_merchant': to,
              'p_reason': reason
            }),
        ok: 'تم تحويل الطلب للمتجر الجديد')) {
      await reload();
    }
  }

  Future<void> driver(
      BuildContext context,
      Map<String, dynamic> o,
      List<Map<String, dynamic>> drivers,
      Future<void> Function() reload) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${tr('مندوب الطلب')} #${o['code']}'),
        content: SizedBox(
          width: 420,
          child: ListView(shrinkWrap: true, children: [
            if (drivers.isEmpty) const Empty('لا يوجد مناديب'),
            for (final d in drivers)
              ListTile(
                enabled: d['id'] != o['driver_id'],
                leading: const GradientBadge(
                    colors: G.sky, icon: Icons.delivery_dining, size: 38),
                title: Text('${d['name']}'),
                subtitle: Text('${d['phone']}'),
                trailing: d['id'] == o['driver_id']
                    ? const Text('الحالي')
                    : const Icon(Icons.chevron_left),
                onTap: () => Navigator.pop(c, d['id'] as String),
              ),
          ]),
        ),
        actions: [
          if (o['driver_id'] != null)
            TextButton(
                onPressed: () => Navigator.pop(c, ''),
                style: TextButton.styleFrom(foregroundColor: G.ruby.first),
                child: const Text('إلغاء الإسناد وإعادة العرض')),
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    if (await widget.act(
        (t) => sb.rpc('oc_assign_driver', params: {
              'p_token': t,
              'p_order': o['id'],
              'p_driver': chosen.isEmpty ? null : chosen
            }),
        ok: chosen.isEmpty ? 'أُلغي إسناد المندوب' : 'تم تغيير المندوب')) {
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.until.difference(DateTime.now());
    return Loader<_BoardData>(
      realtimeTables: const ['orders'],
      load: load,
      builder: (context, data, reload) {
        final (orders, stores, drivers) = data;
        final counts = {
          for (final f in filters.keys)
            f: orders.where((o) => match(o, f)).length
        };
        final text = q.text.trim().toLowerCase();
        final list = orders.where((o) {
          if (!match(o, filter)) return false;
          if (store != 'all' && o['merchant_id'] != store) return false;
          if (text.isEmpty) return true;
          return '${o['code']} ${o['customer_name']} ${o['customer_phone']} ${o['merchants']?['name']} ${o['driver_name']}'
              .toLowerCase()
              .contains(text);
        }).toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          PageHero(
            icon: Icons.tune_outlined,
            title: 'التحكم في الطلبات',
            subtitle:
                '${tr('الجلسة مفتوحة')} · ${tr('تُقفل بعد')} ${left.inMinutes.clamp(0, 30)} ${tr('دقيقة')}',
            stats: [
              ('جارية', '${counts['open']}'),
              ('موقوفة', '${counts['held']}'),
              ('محذوفة', '${counts['deleted']}'),
            ],
            action: Wrap(spacing: 8, runSpacing: 8, children: [
              if (widget.isSuper)
                HeroButton(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'الصلاحيات وكلمات المرور',
                    onPressed: widget.onAccess),
              HeroButton(
                  icon: Icons.lock_outline,
                  label: 'قفل القسم',
                  onPressed: widget.onLock),
            ]),
          ),
          const SizedBox(height: 16),
          if (widget.isSuper && !widget.sectionSet) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [
                  G.amber.last.withValues(alpha: .18),
                  G.gold.last.withValues(alpha: .10)
                ]),
                border: Border.all(color: G.amber.first.withValues(alpha: .35)),
              ),
              child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(Icons.key_outlined, color: G.amber.first),
                    const Text(
                        'دخلت بكلمة مرور حسابك. خصّص كلمة مرور خاصة لهذا القسم.',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: G.amber.first),
                      onPressed: widget.onAccess,
                      icon: const Icon(Icons.password_outlined),
                      label: const Text('تحديد كلمة مرور القسم'),
                    ),
                  ]),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: q,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: tr(
                  'ابحث برقم الطلب أو العميل أو الجوال أو المتجر أو المندوب'),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in filters.entries)
                TonePill(
                  label: f.value.$1,
                  icon: f.value.$2,
                  colors: f.value.$3,
                  selected: filter == f.key,
                  count: counts[f.key] ?? 0,
                  onTap: () => setState(() => filter = f.key),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              TonePill(
                  label: 'كل المتاجر',
                  icon: Icons.storefront_outlined,
                  colors: G.midnight,
                  selected: store == 'all',
                  onTap: () => setState(() => store = 'all')),
              for (final m in stores)
                TonePill(
                    label: '${m['name']}',
                    colors: G.teal,
                    selected: store == m['id'],
                    onTap: () => setState(() => store = m['id'])),
            ]),
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            const Empty('لا توجد طلبات بهذا التصنيف',
                icon: Icons.receipt_long_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 380).floor().clamp(1, 3);
            final w = (c.maxWidth - 14 * (cols - 1)) / cols;
            return Wrap(spacing: 14, runSpacing: 14, children: [
              for (final o in list)
                SizedBox(
                  width: w,
                  child: ControlOrderCard(
                    o: o,
                    onEdit: () => editOrder(context, o, reload),
                    onStatus: () => changeStatus(context, o, reload),
                    onHold: () => hold(context, o, reload),
                    onDelete: () => remove(context, o, reload),
                    onTransfer: () => transfer(context, o, stores, reload),
                    onDriver: () => driver(context, o, drivers, reload),
                  ),
                ),
            ]);
          }),
        ]);
      },
    );
  }
}

class ControlOrderCard extends StatelessWidget {
  const ControlOrderCard(
      {super.key,
      required this.o,
      required this.onEdit,
      required this.onStatus,
      required this.onHold,
      required this.onDelete,
      required this.onTransfer,
      required this.onDriver});
  final Map<String, dynamic> o;
  final VoidCallback onEdit, onStatus, onHold, onDelete, onTransfer, onDriver;

  @override
  Widget build(BuildContext context) {
    final deleted = o['deleted_at'] != null;
    final held = o['held'] == true && !deleted;
    final closed = ['delivered', 'cancelled'].contains(o['status']);
    final sc = statusColor(o['status']);
    final head = deleted
        ? _deletedTone
        : held
            ? _holdTone
            : [
                Color.lerp(sc, Colors.black, .25)!,
                Color.lerp(sc, Colors.white, .35)!
              ];
    final delivery = o['fulfillment'] != 'pickup';
    final canTransfer = !deleted && ['new', 'accepted'].contains(o['status']);
    Widget line(IconData i, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(children: [
            Icon(i, size: 16, color: Colors.black45),
            const SizedBox(width: 6),
            Expanded(
                child: Text(t,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13))),
          ]),
        );
    Widget btn(IconData i, String label, List<Color> tone, VoidCallback? on) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 6, bottom: 6),
          child: ActionChip(
            avatar: Icon(i,
                size: 16, color: on == null ? Colors.black26 : tone.first),
            label: Text(label),
            labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: on == null ? Colors.black26 : tone.first),
            side: BorderSide(color: tone.first.withValues(alpha: .25)),
            backgroundColor: tone.last.withValues(alpha: .08),
            onPressed: on,
          ),
        );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      OrderDetailsPage(orderId: o['id'], viewer: 'admin'))),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: head)),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${o['code']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      Text(o['merchants']?['name'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(999)),
                child: Text(
                    deleted
                        ? tr('محذوف')
                        : held
                            ? '${tr('موقوف')} · ${statusOf(o)}'
                            : statusOf(o),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            line(Icons.person_outline,
                '${o['customer_name'] ?? ''} · ${o['customer_phone'] ?? ''}'),
            line(Icons.event_outlined,
                '${tr('الذبح')} ${dateText(o['slaughter_date'])} ${o['slaughter_time'] ?? ''}'),
            line(
                delivery
                    ? Icons.local_shipping_outlined
                    : Icons.storefront_outlined,
                '${delivery ? tr('التوصيل') : tr('استلام من المحل')} ${dateText(o['delivery_date'])} ${o['delivery_slot'] ?? ''}'),
            if (delivery)
              line(Icons.two_wheeler_outlined,
                  '${tr('المندوب')}: ${o['driver_name'] ?? tr('غير معيّن')}'),
            line(Icons.payments_outlined,
                '${bhd(o['total'])} · ${paymentLabels[o['payment_method']] ?? ''}'),
            if (held && '${o['held_reason'] ?? ''}'.isNotEmpty)
              line(Icons.info_outline,
                  '${tr('سبب الإيقاف')}: ${o['held_reason']}'),
            if (deleted)
              line(Icons.info_outline,
                  '${tr('سبب الحذف')}: ${o['deleted_reason'] ?? ''}'),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
          child: Wrap(children: [
            if (!deleted) ...[
              btn(Icons.edit_outlined, 'تعديل', G.sapphire, onEdit),
              btn(Icons.sync_alt, 'الحالة', G.midnight,
                  closed ? null : onStatus),
              btn(
                  held ? Icons.play_circle_outline : Icons.pause_circle_outline,
                  held ? 'استئناف' : 'إيقاف',
                  _holdTone,
                  closed ? null : onHold),
              btn(Icons.swap_horiz, 'تحويل لتاجر', G.violet,
                  canTransfer ? onTransfer : null),
              if (delivery)
                btn(Icons.delivery_dining_outlined, 'المندوب', G.sky,
                    closed ? null : onDriver),
            ],
            btn(
                deleted ? Icons.restore : Icons.delete_outline,
                deleted ? 'استرجاع' : 'حذف',
                _deletedTone,
                o['status'] == 'delivered' && !deleted ? null : onDelete),
          ]),
        ),
      ]),
    );
  }
}

/// Super admin panel: who is a super admin, who may open the activity log, the
/// master password for order control, and personal passwords per admin.
Future<void> openAccessPanel(BuildContext context) => showDialog(
    context: context, builder: (_) => const Dialog(child: _AccessPanel()));

class _AccessPanel extends StatefulWidget {
  const _AccessPanel();
  @override
  State<_AccessPanel> createState() => _AccessPanelState();
}

class _AccessPanelState extends State<_AccessPanel> {
  Map<String, dynamic>? a;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final r = await guard(context, loadAccess);
    if (mounted && r != null) setState(() => a = r);
  }

  Future<void> setPassword(String? user, String who) async {
    final p1 = TextEditingController(), p2 = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(user == null
            ? 'كلمة المرور الرئيسية للقسم'
            : '${tr('كلمة مرور خاصة بـ')} $who'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  user == null
                      ? 'تفتح القسم لأي مدير يعرفها.'
                      : 'تفتح القسم لهذا المدير فقط.',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              TextFormField(
                controller: p1,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: tr('كلمة المرور')),
                validator: (v) => (v ?? '').length < 6
                    ? tr('كلمة المرور 6 أحرف على الأقل')
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: p2,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: tr('تأكيد كلمة المرور')),
                validator: (v) =>
                    v != p1.text ? tr('كلمتا المرور غير متطابقتين') : null,
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
              child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await guard(
        context,
        () => sb.rpc('oc_set_password',
            params: {'p_user': user, 'p_password': p1.text}),
        ok: 'تم حفظ كلمة المرور');
    await reload();
  }

  Future<void> removePassword(String? user) async {
    await guard(
        context,
        () => sb.rpc('oc_set_password',
            params: {'p_user': user, 'p_password': null}),
        ok: 'تم سحب كلمة المرور');
    await reload();
  }

  Future<void> setAccess(Map ad, {bool? sup, bool? act}) async {
    await guard(
        context,
        () => sb.rpc('admin_set_access', params: {
              'p_user': ad['id'],
              'p_super': sup ?? ad['super'] == true,
              'p_activity': act ?? ad['activity'] == true,
            }),
        ok: 'تم تحديث الصلاحيات');
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final admins = [
      for (final x in (a?['admins'] as List? ?? const []))
        Map<String, dynamic>.from(x)
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
      child: a == null
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()))
          : ListView(
              padding: const EdgeInsets.all(18),
              shrinkWrap: true,
              children: [
                  Row(children: [
                    const GradientBadge(
                        colors: G.sapphire,
                        icon: Icons.admin_panel_settings_outlined,
                        size: 42),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('صلاحيات الإدارة العامة',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 14),
                  GradientHeaderCard(
                    title: 'كلمة المرور الرئيسية',
                    subtitle: a!['master_set'] == true
                        ? 'محددة · تفتح القسم لأي مدير يعرفها'
                        : 'غير محددة',
                    icon: Icons.key_outlined,
                    colors: G.midnight,
                    trailing: a!['master_set'] == true
                        ? IconButton(
                            tooltip: tr('سحب كلمة المرور'),
                            onPressed: () => removePassword(null),
                            icon: const Icon(Icons.key_off_outlined,
                                color: Colors.white))
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton.icon(
                        onPressed: () => setPassword(null, ''),
                        icon: const Icon(Icons.password_outlined),
                        label: Text(a!['master_set'] == true
                            ? 'تغيير كلمة المرور الرئيسية'
                            : 'تحديد كلمة المرور الرئيسية'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GradientHeaderCard(
                    title: 'المديرون',
                    subtitle:
                        'المدير العام يدير الصلاحيات، وسجل الأنشطة لمن تسمح له فقط',
                    icon: Icons.groups_outlined,
                    colors: G.sapphire,
                    child: Column(children: [
                      for (final ad in admins) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                          child: Row(children: [
                            GradientBadge(
                                colors: ad['super'] == true ? G.gold : G.sky,
                                text: '${ad['name']}'.isEmpty
                                    ? '?'
                                    : '${ad['name']}'.characters.first,
                                size: 38),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${ad['name']}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text('${ad['phone'] ?? ''}',
                                        style: const TextStyle(
                                            color: Colors.black45,
                                            fontSize: 12)),
                                  ]),
                            ),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                          child: Wrap(spacing: 6, runSpacing: 6, children: [
                            FilterChip(
                              label: const Text('مدير عام'),
                              avatar: const Icon(
                                  Icons.workspace_premium_outlined,
                                  size: 16),
                              selected: ad['super'] == true,
                              onSelected: (v) => setAccess(ad, sup: v),
                            ),
                            FilterChip(
                              label: const Text('سجل الأنشطة'),
                              avatar: const Icon(Icons.manage_search, size: 16),
                              selected:
                                  ad['activity'] == true || ad['super'] == true,
                              onSelected: ad['super'] == true
                                  ? null
                                  : (v) => setAccess(ad, act: v),
                            ),
                            ActionChip(
                              avatar: Icon(
                                  ad['has_key'] == true
                                      ? Icons.key
                                      : Icons.key_outlined,
                                  size: 16),
                              label: Text(ad['has_key'] == true
                                  ? 'تغيير كلمة مروره للطلبات'
                                  : 'كلمة مرور خاصة للطلبات'),
                              onPressed: () =>
                                  setPassword(ad['id'], ad['name']),
                            ),
                            if (ad['has_key'] == true)
                              ActionChip(
                                avatar: const Icon(Icons.key_off_outlined,
                                    size: 16),
                                label: const Text('سحبها'),
                                onPressed: () => removePassword(ad['id']),
                              ),
                          ]),
                        ),
                        const Divider(height: 1),
                      ],
                    ]),
                  ),
                ]),
    );
  }
}
