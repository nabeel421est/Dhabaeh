import 'package:flutter/material.dart';

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
        return ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'بحث بالاسم أو الجوال'),
                onChanged: (v) => setState(() => search = v),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () async {
                await showAddUser(context, merchants,
                    preset: widget.onlyRole ??
                        (widget.group == UserGroup.platform
                            ? 'merchant_owner'
                            : null));
                await reload();
              },
              icon: const Icon(Icons.person_add_alt),
              label: Text(widget.onlyRole == 'driver'
                  ? 'إضافة مندوب'
                  : widget.group == UserGroup.customers
                      ? 'إضافة عميل'
                      : 'إضافة مستخدم'),
            ),
          ]),
          const SizedBox(height: 12),
          if (list.isEmpty) const Empty('لا توجد نتائج'),
          for (final p in list)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                    child: Text('${p['full_name']}'.isEmpty
                        ? '?'
                        : '${p['full_name']}'.characters.first)),
                title: Text('${p['full_name']}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${p['phone'] ?? ''}${p['area'] == null ? '' : ' · ${p['area']}'}\n'
                    '${(p['user_roles'] as List).map((r) => '${roleLabels[r['role']]}${r['merchant_id'] != null ? ' (${mName[r['merchant_id']] ?? ''})' : ''}').join('، ')}'),
                isThreeLine: true,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(p['is_active'] == true ? 'فعال' : 'موقوف',
                      style: const TextStyle(fontSize: 12)),
                  Switch(
                    value: p['is_active'] == true,
                    onChanged: p['id'] == myId
                        ? null
                        : (v) async {
                            await guard(
                                context,
                                () => sb.from('profiles').update(
                                    {'is_active': v}).eq('id', p['id']));
                            await reload();
                          },
                  ),
                  IconButton(
                    tooltip: 'الصلاحيات',
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    onPressed: () async {
                      await showAddUser(context, merchants, existing: p);
                      await reload();
                    },
                  ),
                ]),
              ),
            ),
        ]);
      },
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

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      realtimeTables: const ['notifications'],
      load: () async => List<Map<String, dynamic>>.from(await sb
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(100)),
      builder: (context, sent, reload) =>
          ListView(padding: const EdgeInsets.all(16), children: [
        SectionCard(
          title: 'إشعار جديد',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, children: [
              for (final a in audiences.entries)
                ChoiceChip(
                    label: Text(a.value),
                    selected: audience == a.key,
                    onSelected: (_) => setState(() => audience = a.key)),
            ]),
            const SizedBox(height: 10),
            Field('العنوان', title, required: true),
            const SizedBox(height: 10),
            Field('النص', body, maxLines: 3),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty)
                  return toast(context, 'اكتب عنوان الإشعار', error: true);
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
              child: const Text('إرسال'),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'المرسلة',
          child: Column(children: [
            if (sent.isEmpty) const Text('لم يُرسل شيء بعد'),
            for (final n in sent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(n['title']),
                subtitle: Text(
                    '${audiences[n['audience']] ?? n['audience']} · ${dateTimeText(n['created_at'])}'),
              ),
          ]),
        ),
      ]),
    );
  }
}
