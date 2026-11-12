import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/common.dart';
import '../core/i18n.dart';
import '../core/ttext.dart';
import 'admin_order_control.dart' show loadAccess, openAccessPanel;

const activityRoles = {
  'admin': 'الإدارة',
  'merchant_owner': 'التجار',
  'merchant_staff': 'موظفو التجار',
  'driver': 'المناديب',
  'customer': 'العملاء',
  'system': 'النظام',
};
const activityRoleTones = {
  'admin': G.sapphire,
  'merchant_owner': G.emerald,
  'merchant_staff': G.teal,
  'driver': G.sky,
  'customer': G.ruby,
  'system': G.midnight,
};
const activityEntities = {
  'order': 'الطلبات',
  'product': 'المنتجات',
  'offer': 'العروض',
  'merchant': 'المتاجر',
  'staff': 'موظفو المتاجر',
  'user': 'الحسابات والأدوار',
  'payout': 'طلبات السحب',
  'wallet': 'المحافظ',
  'notification': 'الإشعارات',
  'driver': 'توفر المناديب',
  'settings': 'الإعدادات',
  'zone': 'مناطق التوصيل',
  'session': 'الدخول والخروج',
};
const activityEntityIcons = <String, IconData>{
  'order': Icons.receipt_long_outlined,
  'product': Icons.inventory_2_outlined,
  'offer': Icons.local_offer_outlined,
  'merchant': Icons.storefront_outlined,
  'staff': Icons.badge_outlined,
  'user': Icons.person_outline,
  'payout': Icons.outbox_outlined,
  'wallet': Icons.account_balance_wallet_outlined,
  'notification': Icons.campaign_outlined,
  'driver': Icons.delivery_dining_outlined,
  'settings': Icons.settings_outlined,
  'zone': Icons.map_outlined,
  'session': Icons.login,
};
const activityActions = {
  'create': 'إضافة',
  'update': 'تعديل',
  'status': 'تغيير حالة',
  'remove': 'حذف',
  'control': 'إجراء إداري',
  'login': 'تسجيل دخول',
  'logout': 'تسجيل خروج',
};

/// Everything that happens in the four apps, searchable and filterable. Only
/// admins the super admin allows can open it.
class AdminActivity extends StatefulWidget {
  const AdminActivity({super.key});
  @override
  State<AdminActivity> createState() => _AdminActivityState();
}

class _AdminActivityState extends State<AdminActivity> {
  Map<String, dynamic>? access;
  Map<String, dynamic>? stats;
  Object? error;
  final rows = <Map<String, dynamic>>[];
  bool loading = false, more = true;
  String? role, entity, action;
  DateTimeRange? range;
  final q = TextEditingController();
  Timer? debounce;
  static const page = 50;

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<void> start() async {
    try {
      final a = await loadAccess();
      if (!mounted) return;
      setState(() => access = a);
      if (a['me']?['activity'] == true) await refresh();
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> refresh() async {
    rows.clear();
    more = true;
    try {
      final s = await sb.rpc('activity_stats');
      if (mounted) setState(() => stats = Map<String, dynamic>.from(s as Map));
    } catch (_) {}
    await fetch();
  }

  Future<void> fetch() async {
    if (loading || !more) return;
    setState(() => loading = true);
    try {
      final r = await sb.rpc('activity_search', params: {
        'p_q': q.text.trim().isEmpty ? null : q.text.trim(),
        'p_role': role,
        'p_entity': entity,
        'p_action': action,
        'p_from': range == null ? null : isoDate(range!.start),
        'p_to': range == null ? null : isoDate(range!.end),
        'p_limit': page,
        'p_offset': rows.length,
      });
      final list = [for (final x in r as List) Map<String, dynamic>.from(x)];
      rows.addAll(list);
      more = list.length == page;
      error = null;
    } catch (e) {
      error = e;
    }
    if (mounted) setState(() => loading = false);
  }

  void changed(VoidCallback f) {
    setState(f);
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (access == null) {
      return error != null
          ? Empty(errText(error!), icon: Icons.error_outline)
          : const Center(child: CircularProgressIndicator());
    }
    final isSuper = access!['me']?['super'] == true;
    if (access!['me']?['activity'] != true) {
      return const Empty(
          'لا تملك صلاحية عرض سجل الأنشطة. يمنحها المدير العام من «الصلاحيات».',
          icon: Icons.lock_outline);
    }
    final byRole = Map<String, dynamic>.from(stats?['by_role'] ?? {});
    return RefreshIndicator(
      onRefresh: refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) fetch();
          return false;
        },
        child: ListView(padding: const EdgeInsets.all(16), children: [
          PageHero(
            icon: Icons.manage_search,
            title: 'سجل الأنشطة',
            subtitle:
                'كل عملية في تطبيقات الإدارة والتجار والموظفين والمناديب والعملاء',
            stats: [
              ('اليوم', '${stats?['today'] ?? '—'}'),
              ('آخر 7 أيام', '${stats?['week'] ?? '—'}'),
              ('مستخدمون نشطون اليوم', '${stats?['actors_today'] ?? '—'}'),
            ],
            action: isSuper
                ? HeroButton(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'صلاحيات الدخول',
                    onPressed: () =>
                        openAccessPanel(context).then((_) => start()))
                : null,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: q,
            onChanged: (_) {
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 450), refresh);
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: tr('ابحث في الأنشطة: اسم، رقم طلب، متجر، منتج…'),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              TonePill(
                  label: 'الكل',
                  icon: Icons.groups_outlined,
                  colors: G.midnight,
                  selected: role == null,
                  onTap: () => changed(() => role = null)),
              for (final r in activityRoles.entries)
                TonePill(
                  label: r.value,
                  icon: roleIcons[r.key] ?? Icons.memory_outlined,
                  colors: activityRoleTones[r.key]!,
                  selected: role == r.key,
                  count: (byRole[r.key] as num?)?.toInt() ?? -1,
                  onTap: () => changed(() => role = r.key),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                initialValue: entity,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: tr('القسم'),
                    prefixIcon: const Icon(Icons.category_outlined)),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('كل الأقسام')),
                  for (final e in activityEntities.entries)
                    DropdownMenuItem<String?>(
                        value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => changed(() => entity = v),
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                initialValue: action,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: tr('نوع العملية'),
                    prefixIcon: const Icon(Icons.bolt_outlined)),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('كل العمليات')),
                  for (final e in activityActions.entries)
                    DropdownMenuItem<String?>(
                        value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => changed(() => action = v),
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.date_range_outlined),
              onPressed: () async {
                final r = await showDateRangePicker(
                    context: context,
                    initialDateRange: range,
                    firstDate: DateTime(2026),
                    lastDate: DateTime.now().add(const Duration(days: 1)));
                if (r != null) changed(() => range = r);
              },
              label: Text(range == null
                  ? 'كل التواريخ'
                  : '${dateText(isoDate(range!.start))} – ${dateText(isoDate(range!.end))}'),
            ),
            if (range != null ||
                entity != null ||
                action != null ||
                role != null)
              TextButton.icon(
                onPressed: () => changed(() {
                  range = null;
                  entity = null;
                  action = null;
                  role = null;
                }),
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('مسح الفلاتر'),
              ),
          ]),
          const SizedBox(height: 16),
          if (error != null && rows.isEmpty)
            Empty(errText(error!), icon: Icons.error_outline)
          else if (!loading && rows.isEmpty)
            const Empty('لا توجد أنشطة مطابقة', icon: Icons.manage_search),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 72),
                ActivityTile(a: rows[i]),
              ],
            ]),
          ),
          if (loading)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator())),
          if (!loading && more && rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                  child: TextButton(
                      onPressed: fetch, child: const Text('عرض المزيد'))),
            ),
        ]),
      ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.a});
  final Map<String, dynamic> a;

  @override
  Widget build(BuildContext context) {
    final role = '${a['actor_role'] ?? 'system'}';
    final tone = activityRoleTones[role] ?? G.midnight;
    final when = DateTime.tryParse('${a['at']}')?.toLocal();
    return InkWell(
      onTap: () => showDetails(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          GradientBadge(
              colors: tone,
              icon: activityEntityIcons[a['entity']] ?? Icons.bolt_outlined,
              size: 44),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['summary']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 3),
              Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(
                          color: tone.first.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(activityRoles[role] ?? role,
                          style: TextStyle(
                              color: tone.first,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700)),
                    ),
                    Text('${a['actor_name'] ?? tr('النظام')}',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12.5)),
                  ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(when == null ? '' : timeAgo(when),
                style: const TextStyle(color: Colors.black45, fontSize: 12)),
            Text(dateTimeText(a['at']),
                style: const TextStyle(color: Colors.black38, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }

  void showDetails(BuildContext context) {
    final d = a['details'];
    final changes = <(String, String, String)>[];
    if (d is Map && d['before'] is Map && d['after'] is Map) {
      final b = d['before'] as Map, n = d['after'] as Map;
      for (final k in n.keys) {
        if (const ['updated_at', 'dispatch_queue', 'dispatch_at'].contains(k)) {
          continue;
        }
        if (jsonEncode(b[k]) != jsonEncode(n[k])) {
          changes.add(('$k', short(b[k]), short(n[k])));
        }
      }
    }
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${a['summary']}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  KeyVal('المنفّذ', '${a['actor_name'] ?? tr('النظام')}'),
                  KeyVal('الدور',
                      activityRoles[a['actor_role']] ?? '${a['actor_role']}'),
                  KeyVal('القسم',
                      activityEntities[a['entity']] ?? '${a['entity']}'),
                  KeyVal('العملية',
                      activityActions[a['action']] ?? '${a['action']}'),
                  KeyVal('الوقت', dateTimeText(a['at'])),
                  if (changes.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text('ما الذي تغيّر',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    for (final ch in changes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ch.$1,
                                  textDirection: TextDirection.ltr,
                                  style: const TextStyle(
                                      color: Colors.black54, fontSize: 12)),
                              Text('${ch.$2}  ←  ${ch.$3}',
                                  style: const TextStyle(fontSize: 13)),
                            ]),
                      ),
                  ],
                ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  static String short(dynamic v) {
    if (v == null) return '—';
    final s = v is String ? v : jsonEncode(v);
    return s.length > 80 ? '${s.substring(0, 80)}…' : s;
  }
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return tr('الآن');
  if (d.inMinutes < 60) return '${tr('قبل')} ${d.inMinutes} ${tr('د')}';
  if (d.inHours < 24) return '${tr('قبل')} ${d.inHours} ${tr('س')}';
  return '${tr('قبل')} ${d.inDays} ${tr('يوم')}';
}
