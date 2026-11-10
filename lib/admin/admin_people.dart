import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/common.dart';

/// Which accounts a list shows: customers only, platform staff (admin, store owners and their employees), or one role.
enum UserGroup { customers, platform }

const platformRoles = {'admin', 'merchant_owner', 'merchant_staff'};

/// A list of accounts. New accounts can get any mix of roles.
class AdminUsers extends StatefulWidget {
  const AdminUsers({super.key, this.onlyRole, this.group});
  final String? onlyRole;
  final UserGroup? group;
  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    return Loader<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>(
      realtimeTables: const ['profiles', 'user_roles'],
      load: () async {
        final p = await sb
            .from('profiles')
            .select('*, user_roles(role, merchant_id)')
            .order('created_at', ascending: false);
        final m = await sb.from('merchants').select('id, name').order('name');
        return (
          List<Map<String, dynamic>>.from(p),
          List<Map<String, dynamic>>.from(m)
        );
      },
      builder: (context, data, reload) {
        final (people, merchants) = data;
        final mName = {for (final m in merchants) m['id']: m['name']};
        final list = people.where((p) {
          final roles =
              (p['user_roles'] as List).map((r) => r['role']).toList();
          if (widget.onlyRole != null && !roles.contains(widget.onlyRole))
            return false;
          // A customer is an account with no role beyond customer; anyone with a store or admin role is platform staff.
          if (widget.group == UserGroup.customers &&
              roles.any((r) => r != 'customer')) return false;
          if (widget.group == UserGroup.platform &&
              !roles.any(platformRoles.contains)) return false;
          final q = search.trim();
          return q.isEmpty ||
              '${p['full_name']}'.contains(q) ||
              '${p['phone']}'.contains(q);
        }).toList();
        final active = list.where((p) => p['is_active'] == true).length;
        final (heroIcon, heroTitle, heroSub) =
            switch ((widget.onlyRole, widget.group)) {
          ('driver', _) => (
              Icons.local_shipping_outlined,
              'المندوبون',
              'فريق التوصيل وحالة كل مندوب'
            ),
          (_, UserGroup.customers) => (
              Icons.people_outline,
              'العملاء',
              'زبائن المنصة اللي يطلبون من المسالخ'
            ),
          (_, UserGroup.platform) => (
              Icons.admin_panel_settings_outlined,
              'مستخدمو المنصة',
              'أصحاب المتاجر وموظفينهم والمشرفين'
            ),
          _ => (Icons.people_outline, 'المستخدمون', 'كل الحسابات'),
        };
        final addLabel = widget.onlyRole == 'driver'
            ? 'إضافة مندوب'
            : widget.group == UserGroup.customers
                ? 'إضافة عميل'
                : 'إضافة مستخدم';
        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon: heroIcon,
            title: heroTitle,
            subtitle: heroSub,
            stats: [
              ('الإجمالي', '${list.length}'),
              ('فعّال', '$active'),
              ('موقوف', '${list.length - active}')
            ],
            action: HeroButton(
              icon: Icons.person_add_alt,
              label: addLabel,
              onPressed: () async {
                await showAddUser(context, merchants,
                    preset: widget.onlyRole ??
                        (widget.group == UserGroup.platform
                            ? 'merchant_owner'
                            : null));
                await reload();
              },
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'بحث بالاسم أو الجوال'),
            onChanged: (v) => setState(() => search = v),
          ),
          const SizedBox(height: 16),
          if (list.isEmpty) const Empty('لا توجد نتائج'),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 330).floor().clamp(1, 4);
            final w = (c.maxWidth - 14 * (cols - 1)) / cols;
            return Wrap(spacing: 14, runSpacing: 14, children: [
              for (final p in list)
                SizedBox(
                  width: w,
                  child: _PersonCard(
                    p: p,
                    mName: mName,
                    onToggle: p['id'] == myId
                        ? null
                        : (v) async {
                            await guard(
                                context,
                                () => sb.from('profiles').update(
                                    {'is_active': v}).eq('id', p['id']));
                            await reload();
                          },
                    onRoles: () async {
                      await showAddUser(context, merchants, existing: p);
                      await reload();
                    },
                  ),
                ),
            ]);
          }),
        ]);
      },
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard(
      {required this.p,
      required this.mName,
      required this.onToggle,
      required this.onRoles});
  final Map<String, dynamic> p;
  final Map<dynamic, dynamic> mName;
  final void Function(bool)? onToggle;
  final VoidCallback onRoles;
  @override
  Widget build(BuildContext context) {
    final roles = (p['user_roles'] as List).cast<Map>();
    final main = [
      'admin',
      'merchant_owner',
      'merchant_staff',
      'driver',
      'customer'
    ].firstWhere((r) => roles.any((x) => x['role'] == r),
        orElse: () => 'customer');
    final colors = roleGradients[main]!;
    final active = p['is_active'] == true;
    final name = '${p['full_name'] ?? ''}';
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
            height: 5,
            decoration:
                BoxDecoration(gradient: LinearGradient(colors: colors))),
        Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              GradientBadge(
                  colors: colors,
                  text: name.isEmpty ? '?' : name.characters.first),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                          '${p['phone'] ?? ''}${p['area'] == null ? '' : ' · ${p['area']}'}',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 13)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: (active
                          ? const Color(0xFF1E8A5F)
                          : const Color(0xFFB83250))
                      .withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(active ? 'فعّال' : 'موقوف',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? const Color(0xFF1E8A5F)
                            : const Color(0xFFB83250))),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in roles)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(colors: [
                      for (final c in roleGradients[r['role']] ?? colors)
                        c.withValues(alpha: .14),
                    ]),
                  ),
                  child: Text(
                    '${roleLabels[r['role']]}${r['merchant_id'] != null ? ' · ${mName[r['merchant_id']] ?? ''}' : ''}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (roleGradients[r['role']] ?? colors).first),
                  ),
                ),
            ]),
            const Divider(height: 22),
            Row(children: [
              Switch(value: active, onChanged: onToggle),
              const SizedBox(width: 6),
              Text(active ? 'الحساب مفعّل' : 'الحساب موقوف',
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const Spacer(),
              TextButton.icon(
                  onPressed: onRoles,
                  icon:
                      const Icon(Icons.admin_panel_settings_outlined, size: 18),
                  label: const Text('الصلاحيات')),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Add a user, or (with [existing]) add roles to one. A store owner or store employee must be linked to a store.
Future<void> showAddUser(
    BuildContext context, List<Map<String, dynamic>> merchants,
    {String? preset, Map<String, dynamic>? existing}) async {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(text: existing?['full_name'] ?? '');
  final phone = TextEditingController(text: existing?['phone'] ?? '');
  final pass = TextEditingController();
  final area = TextEditingController(text: existing?['area'] ?? '');
  final have = {
    for (final r in (existing?['user_roles'] as List? ?? []))
      r['role'] as String
  };
  final roles = {
    for (final r in roleLabels.keys)
      r: have.contains(r) || r == (preset ?? 'customer')
  };
  String? merchantId = merchants.isEmpty ? null : merchants.first['id'];
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text(existing == null
            ? 'إضافة مستخدم'
            : 'صلاحيات ${existing['full_name']}'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (existing == null) ...[
                      Field('الاسم', name, required: true),
                      const SizedBox(height: 10),
                      Field('رقم الجوال', phone,
                          required: true,
                          keyboard: TextInputType.phone,
                          ltr: true),
                      const SizedBox(height: 10),
                      Field('كلمة مرور مبدئية', pass,
                          required: true, note: 'يغيّرها المستخدم لاحقاً'),
                      const SizedBox(height: 10),
                      Field('المنطقة', area),
                      const SizedBox(height: 12),
                    ],
                    const Text('الصلاحيات',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    for (final r in roleLabels.entries)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: roles[r.key],
                        enabled: !have.contains(r.key),
                        title: Text(r.value),
                        onChanged: (v) => set(() => roles[r.key] = v == true),
                      ),
                    if (roles['merchant_owner'] == true ||
                        roles['merchant_staff'] == true)
                      DropdownButtonFormField<String>(
                        initialValue: merchantId,
                        decoration: const InputDecoration(
                            labelText: 'المتجر المرتبط *'),
                        items: [
                          for (final m in merchants)
                            DropdownMenuItem(
                                value: m['id'] as String,
                                child: Text(m['name']))
                        ],
                        onChanged: (v) => set(() => merchantId = v),
                        validator: (v) => v == null ? 'اختر المتجر' : null,
                      ),
                  ]),
            ),
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
    ),
  );
  if (ok != true || !context.mounted) return;
  await guard(
      context,
      () => usersFn({
            'action': 'admin_create_user',
            'full_name': existing?['full_name'] ?? name.text.trim(),
            'phone': normPhone(existing?['phone'] ?? phone.text),
            'password': pass.text,
            'area': area.text.trim().isEmpty ? null : area.text.trim(),
            'roles': [
              for (final e in roles.entries)
                if (e.value && !have.contains(e.key)) e.key
            ],
            'merchant_id': merchantId,
          }),
      ok: 'تم الحفظ');
}

class AdminDrivers extends StatelessWidget {
  const AdminDrivers({super.key});
  @override
  Widget build(BuildContext context) => const AdminUsers(onlyRole: 'driver');
}

class AdminNotify extends StatefulWidget {
  const AdminNotify({super.key});
  @override
  State<AdminNotify> createState() => _AdminNotifyState();
}

class _AdminNotifyState extends State<AdminNotify> {
  final title = TextEditingController();
  final body = TextEditingController();
  String audience = 'all';
  static const audiences = {
    'all': 'الجميع',
    'customers': 'العملاء',
    'merchants': 'التجار',
    'drivers': 'المندوبون'
  };
  static const audienceLook = <String, (IconData, List<Color>)>{
    'all': (Icons.campaign_outlined, G.sky),
    'customers': (Icons.people_outline, G.ruby),
    'merchants': (Icons.storefront_outlined, G.emerald),
    'drivers': (Icons.local_shipping_outlined, G.sapphire),
  };

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['notifications'],
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(100)),
      builder: (context, sent, reload) {
        int count(String a) => sent.where((n) => n['audience'] == a).length;
        final look = audienceLook[audience]!;
        return ListView(padding: const EdgeInsets.all(18), children: [
          PageHero(
            icon: Icons.campaign_outlined,
            title: 'الإشعارات',
            subtitle: 'رسائل تصل لتطبيقات العملاء والتجار والمندوبين',
            stats: [
              ('المرسلة', '${sent.length}'),
              for (final a in audiences.entries) (a.value, '${count(a.key)}')
            ],
          ),
          const SizedBox(height: 16),
          GradientHeaderCard(
            title: 'إشعار جديد',
            subtitle: 'إلى: ${audiences[audience]}',
            icon: look.$1,
            colors: look.$2,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('لمن يُرسل؟',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final a in audiences.entries)
                      _AudienceTile(
                        label: a.value,
                        icon: audienceLook[a.key]!.$1,
                        colors: audienceLook[a.key]!.$2,
                        selected: audience == a.key,
                        onTap: () => setState(() => audience = a.key),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  Field('العنوان', title, required: true),
                  const SizedBox(height: 10),
                  Field('النص', body, maxLines: 3),
                  const SizedBox(height: 14),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: look.$2.first),
                      icon: const Icon(Icons.send_outlined, size: 18),
                      onPressed: () async {
                        if (title.text.trim().isEmpty)
                          return toast(context, 'اكتب عنوان الإشعار',
                              error: true);
                        await guard(
                            context,
                            () => sb.from('notifications').insert({
                                  'audience': audience,
                                  'title': title.text.trim(),
                                  'body': body.text.trim(),
                                  'created_by': myId
                                }),
                            ok: 'تم الإرسال');
                        title.clear();
                        body.clear();
                        await reload();
                      },
                      label: const Text('إرسال'),
                    ),
                  ),
                ]),
          ),
          const SizedBox(height: 18),
          const Text('المرسلة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (sent.isEmpty)
            const Empty('لم يُرسل شيء بعد', icon: Icons.campaign_outlined),
          LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 380).floor().clamp(1, 3);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final n in sent)
                SizedBox(
                  width: w,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GradientBadge(
                                colors: (audienceLook[n['audience']] ??
                                        audienceLook['all']!)
                                    .$2,
                                icon: (audienceLook[n['audience']] ??
                                        audienceLook['all']!)
                                    .$1,
                                size: 42),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n['title'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    if ('${n['body'] ?? ''}'.isNotEmpty)
                                      Text(n['body'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 13)),
                                    const SizedBox(height: 6),
                                    Text(
                                        '${audiences[n['audience']] ?? n['audience']} · ${dateTimeText(n['created_at'])}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                (audienceLook[n['audience']] ??
                                                        audienceLook['all']!)
                                                    .$2
                                                    .first)),
                                  ]),
                            ),
                          ]),
                    ),
                  ),
                ),
            ]);
          }),
        ]);
      },
    );
  }
}

class _AudienceTile extends StatelessWidget {
  const _AudienceTile(
      {required this.label,
      required this.icon,
      required this.colors,
      required this.selected,
      required this.onTap});
  final String label;
  final IconData icon;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 130,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: selected ? LinearGradient(colors: colors) : null,
            color: selected ? null : Colors.white,
            border: Border.all(
                color: selected
                    ? Colors.transparent
                    : colors.first.withValues(alpha: .3)),
          ),
          child: Row(children: [
            Icon(icon, size: 20, color: selected ? Colors.white : colors.first),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : colors.first)),
          ]),
        ),
      );
}
