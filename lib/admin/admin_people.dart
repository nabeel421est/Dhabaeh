import 'dart:math';

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
            .isFilter('deleted_at', null)
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
                      await showEditUser(context, merchants, p);
                      await reload();
                    },
                    onDelete: p['id'] == myId
                        ? null
                        : () async {
                            await confirmDeleteUser(context, p);
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
      required this.onRoles,
      required this.onDelete});
  final Map<String, dynamic> p;
  final Map<dynamic, dynamic> mName;
  final void Function(bool)? onToggle;
  final VoidCallback onRoles;
  final VoidCallback? onDelete;
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
                  icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                  label: const Text('تعديل')),
              if (onDelete != null)
                IconButton(
                  tooltip: 'حذف المستخدم',
                  onPressed: onDelete,
                  style: IconButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFB83250).withValues(alpha: .08)),
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFB83250), size: 20),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Edit a user's name, area and roles: each role can be granted or removed.
/// A store owner or employee role is tied to the store picked next to it.
Future<void> showEditUser(BuildContext context,
    List<Map<String, dynamic>> merchants, Map<String, dynamic> p) async {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(text: '${p['full_name'] ?? ''}');
  final area = TextEditingController(text: '${p['area'] ?? ''}');
  final current = (p['user_roles'] as List? ?? []).cast<Map>();
  final on = {
    for (final r in roleLabels.keys) r: current.any((x) => x['role'] == r)
  };
  String? storeOf(String role) {
    final m = current.where((x) => x['role'] == role).firstOrNull;
    return m?['merchant_id'] as String? ??
        (merchants.isEmpty ? null : merchants.first['id'] as String);
  }

  final store = {
    'merchant_owner': storeOf('merchant_owner'),
    'merchant_staff': storeOf('merchant_staff'),
  };
  final self = p['id'] == myId;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: G.violet),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22))),
          child: Row(children: [
            const Icon(Icons.manage_accounts_outlined, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text('تعديل ${p['full_name'] ?? ''}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        content: SizedBox(
          width: 460,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Field('الاسم', name, required: true),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: '${p['phone'] ?? ''}',
                      enabled: false,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                          labelText: 'رقم الجوال (اسم الدخول)',
                          prefixIcon: Icon(Icons.lock_outline)),
                    ),
                    const SizedBox(height: 10),
                    Field('المنطقة', area),
                    const SizedBox(height: 14),
                    const Text('الصلاحيات',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const Text('فعّل الصلاحية لإعطائها، أو ألغِها لإزالتها',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 6),
                    for (final r in roleLabels.entries) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: on[r.key] == true
                              ? LinearGradient(colors: [
                                  for (final x
                                      in roleGradients[r.key] ?? G.violet)
                                    x.withValues(alpha: .12)
                                ])
                              : null,
                          border: Border.all(
                              color: (roleGradients[r.key] ?? G.violet)
                                  .first
                                  .withValues(
                                      alpha: on[r.key] == true ? .5 : .15)),
                        ),
                        child: SwitchListTile(
                          dense: true,
                          value: on[r.key] == true,
                          activeThumbColor:
                              (roleGradients[r.key] ?? G.violet).first,
                          title: Text(r.value,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: self && r.key == 'admin'
                              ? const Text('لا يمكنك إزالتها عن نفسك')
                              : null,
                          onChanged: self && r.key == 'admin'
                              ? null
                              : (v) => set(() => on[r.key] = v),
                        ),
                      ),
                      if ((r.key == 'merchant_owner' ||
                              r.key == 'merchant_staff') &&
                          on[r.key] == true)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DropdownButtonFormField<String>(
                            initialValue: store[r.key],
                            isExpanded: true,
                            decoration: InputDecoration(
                                labelText: r.key == 'merchant_owner'
                                    ? 'المتجر الذي يملكه *'
                                    : 'المتجر الذي يعمل فيه *'),
                            items: [
                              for (final m in merchants)
                                DropdownMenuItem(
                                    value: m['id'] as String,
                                    child: Text(m['name']))
                            ],
                            onChanged: (v) => set(() => store[r.key] = v),
                            validator: (v) => v == null ? 'اختر المتجر' : null,
                          ),
                        ),
                    ],
                  ]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء')),
          FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: G.violet.first),
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(c, true);
              },
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('حفظ التعديلات')),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  await guard(
      context,
      () => usersFn({
            'action': 'admin_update_user',
            'user_id': p['id'],
            'full_name': name.text.trim(),
            'area': area.text.trim(),
            'roles': [
              for (final e in on.entries)
                if (e.value)
                  {
                    'role': e.key,
                    if (store.containsKey(e.key)) 'merchant_id': store[e.key],
                  }
            ],
          }),
      ok: 'تم حفظ التعديلات');
}

/// Delete a user after confirmation. Accounts with orders or money records are
/// archived by the server instead (signed out for good, roles removed), to keep the history.
Future<void> confirmDeleteUser(
    BuildContext context, Map<String, dynamic> p) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded,
          color: Color(0xFFB83250), size: 40),
      title: Text('حذف ${p['full_name'] ?? ''}؟'),
      content: const Text(
          'سيُحذف الحساب ولن يتمكن صاحبه من الدخول.\nإذا كان للحساب طلبات أو سجلات مالية، يُؤرشف بدل الحذف النهائي حتى تبقى السجلات محفوظة.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء')),
        FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB83250)),
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('حذف')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final r = await guard(context,
      () => usersFn({'action': 'admin_delete_user', 'user_id': p['id']}));
  if (r != null && context.mounted) {
    toast(
        context,
        r['mode'] == 'archived'
            ? 'تم حذف المستخدم، وبقيت طلباته وسجلاته المالية محفوظة'
            : 'تم حذف المستخدم نهائياً');
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
  var hidePass = true;
  final main = preset ?? 'customer';
  final colors = roleGradients[main] ?? G.violet;
  final isCustomer = existing == null && main == 'customer';
  final title = existing != null
      ? 'صلاحيات ${existing['full_name']}'
      : main == 'driver'
          ? 'إضافة مندوب'
          : isCustomer
              ? 'إضافة عميل'
              : 'إضافة مستخدم';
  final subtitle = existing != null
      ? 'أضف صلاحيات جديدة لهذا الحساب'
      : isCustomer
          ? 'حساب عميل جديد يدخل برقم جواله'
          : 'حساب جديد للمنصة مع صلاحياته';

  InputDecoration deco(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colors.first),
        suffixIcon: suffix,
        filled: true,
        fillColor: colors.first.withValues(alpha: .04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.first.withValues(alpha: .18))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.first, width: 1.6)),
      );

  Widget section(IconData icon, String text, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(text,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              Text(hint,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
        ]),
      );

  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) {
      final needStore =
          roles['merchant_owner'] == true || roles['merchant_staff'] == true;
      return Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Gradient header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [colors.last, colors.first]),
              ),
              child: Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: .5), width: 1.5),
                  ),
                  child: Icon(
                      existing != null
                          ? Icons.key_outlined
                          : Icons.person_add_alt_1_outlined,
                      color: Colors.white,
                      size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .85),
                                fontSize: 13)),
                      ]),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(c, false),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ]),
            ),
            Flexible(
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (existing == null) ...[
                          section(Icons.badge_outlined, 'بيانات الحساب',
                              'رقم الجوال هو اسم الدخول'),
                          TextFormField(
                            controller: name,
                            decoration:
                                deco('الاسم الكامل *', Icons.person_outline),
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? 'اكتب الاسم' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            decoration: deco(
                                'رقم الجوال *', Icons.phone_iphone_outlined,
                                suffix: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  child: Text('+973',
                                      textDirection: TextDirection.ltr,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black54)),
                                )),
                            validator: (v) {
                              final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                              return d.length == 8 ||
                                      (d.length == 11 && d.startsWith('973'))
                                  ? null
                                  : 'رقم الجوال 8 أرقام';
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: pass,
                            obscureText: hidePass,
                            textDirection: TextDirection.ltr,
                            decoration: deco(
                                'كلمة مرور مبدئية *', Icons.lock_outline,
                                suffix: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'إظهار',
                                        icon: Icon(hidePass
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined),
                                        onPressed: () =>
                                            set(() => hidePass = !hidePass),
                                      ),
                                      IconButton(
                                        tooltip: 'توليد كلمة مرور',
                                        icon: Icon(Icons.auto_awesome,
                                            color: colors.first),
                                        onPressed: () => set(() {
                                          const a =
                                              'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
                                          final rnd = Random.secure();
                                          pass.text = List.generate(
                                                  10,
                                                  (_) =>
                                                      a[rnd.nextInt(a.length)])
                                              .join();
                                          hidePass = false;
                                        }),
                                      ),
                                    ])),
                            validator: (v) => (v ?? '').length < 6
                                ? '6 أحرف على الأقل'
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                                start: 12, top: 4),
                            child: Text('يغيّرها المستخدم بعد أول دخول',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: area,
                            decoration:
                                deco('المنطقة', Icons.location_on_outlined),
                          ),
                          const SizedBox(height: 18),
                        ],
                        section(Icons.verified_user_outlined, 'الصلاحيات',
                            'اختر ما يستطيع هذا الحساب فتحه'),
                        LayoutBuilder(builder: (context, box) {
                          final w = box.maxWidth >= 440
                              ? (box.maxWidth - 10) / 2
                              : box.maxWidth;
                          return Wrap(spacing: 10, runSpacing: 10, children: [
                            for (final r in roleLabels.entries)
                              SizedBox(
                                width: w,
                                child: _RolePick(
                                  label: r.value,
                                  hint: roleHints[r.key] ?? '',
                                  icon: roleIcons[r.key] ?? Icons.person,
                                  colors: roleGradients[r.key] ?? G.violet,
                                  selected: roles[r.key] == true,
                                  locked: have.contains(r.key),
                                  onTap: () => set(() =>
                                      roles[r.key] = !(roles[r.key] ?? false)),
                                ),
                              ),
                          ]);
                        }),
                        if (needStore) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(colors: [
                                for (final x
                                    in roleGradients['merchant_owner']!)
                                  x.withValues(alpha: .08)
                              ]),
                              border: Border.all(
                                  color: roleGradients['merchant_owner']!
                                      .first
                                      .withValues(alpha: .25)),
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: merchantId,
                              isExpanded: true,
                              decoration: deco('المتجر المرتبط *',
                                  Icons.storefront_outlined),
                              items: [
                                for (final m in merchants)
                                  DropdownMenuItem(
                                      value: m['id'] as String,
                                      child: Text(m['name']))
                              ],
                              onChanged: (v) => set(() => merchantId = v),
                              validator: (v) =>
                                  v == null ? 'اختر المتجر' : null,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ]),
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: colors.first.withValues(alpha: .1))),
              ),
              child: Row(children: [
                Expanded(
                  flex: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient:
                          LinearGradient(colors: [colors.first, colors.last]),
                      boxShadow: [
                        BoxShadow(
                            color: colors.first.withValues(alpha: .35),
                            blurRadius: 14,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        if (!roles.values.any((v) => v)) {
                          toast(c, 'اختر صلاحية واحدة على الأقل');
                          return;
                        }
                        if (form.currentState!.validate()) {
                          Navigator.pop(c, true);
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(existing == null ? 'إنشاء الحساب' : 'حفظ',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: colors.first,
                      side:
                          BorderSide(color: colors.first.withValues(alpha: .4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('إلغاء'),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
    }),
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
      ok: existing == null ? 'تم إنشاء الحساب' : 'تم الحفظ');
}

/// A selectable role card: full gradient when chosen, soft tint otherwise.
class _RolePick extends StatelessWidget {
  const _RolePick(
      {required this.label,
      required this.hint,
      required this.icon,
      required this.colors,
      required this.selected,
      required this.locked,
      required this.onTap});
  final String label, hint;
  final IconData icon;
  final List<Color> colors;
  final bool selected, locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : colors.first;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: selected
            ? LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: colors)
            : LinearGradient(
                colors: [for (final x in colors) x.withValues(alpha: .07)]),
        border: Border.all(
            color: colors.first.withValues(alpha: selected ? 0 : .2)),
        boxShadow: selected
            ? [
                BoxShadow(
                    color: colors.first.withValues(alpha: .3),
                    blurRadius: 12,
                    offset: const Offset(0, 5))
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: locked ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: .22)
                      : colors.first.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: fg, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white : Colors.black87)),
                      Text(locked ? 'لديه هذه الصلاحية' : hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: selected
                                  ? Colors.white.withValues(alpha: .85)
                                  : Colors.black54)),
                    ]),
              ),
              Icon(
                  locked
                      ? Icons.lock_outline
                      : selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                  color: selected
                      ? Colors.white
                      : colors.first.withValues(alpha: .5),
                  size: 22),
            ]),
          ),
        ),
      ),
    );
  }
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
  String kind = 'message'; // message | offer
  static const kinds = {
    'message': ('رسالة', Icons.mark_email_unread_outlined),
    'offer': ('عرض', Icons.local_offer_outlined),
  };
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
                  const SizedBox(height: 14),
                  const Text('نوع الإشعار',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final k in kinds.entries)
                      _AudienceTile(
                        label: k.value.$1,
                        icon: k.value.$2,
                        colors: k.key == 'offer' ? G.gold : G.violet,
                        selected: kind == k.key,
                        onTap: () => setState(() => kind = k.key),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  Field(kind == 'offer' ? 'عنوان العرض' : 'العنوان', title,
                      required: true,
                      hint: kind == 'offer'
                          ? 'مثال: خصم 10% على النعيمي هذا الأسبوع'
                          : null),
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
                                  'kind': kind,
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
                                        '${n['kind'] == 'offer' ? 'عرض' : 'رسالة'} · ${audiences[n['audience']] ?? n['audience']} · ${dateTimeText(n['created_at'])}',
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
