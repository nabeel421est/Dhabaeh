import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_shell.dart';
import '../core/brand.dart';
import '../core/common.dart';
import '../core/push.dart';
import '../customer/customer_shell.dart';
import '../driver/driver_shell.dart';
import '../merchant/merchant_shell.dart';
import 'login_page.dart';
import '../core/ttext.dart';
import '../core/lang_button.dart';
import '../core/i18n.dart';

/// One login for everyone. After sign-in the account's roles decide which app opens:
/// admin > merchant owner > merchant staff > driver > customer.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class Session {
  Session(this.roles, this.profile);
  final List<Map<String, dynamic>> roles;
  final Map<String, dynamic> profile;
  bool has(String r) => roles.any((x) => x['role'] == r);
  List<String> get available {
    final a = [
      'admin',
      'merchant_owner',
      'merchant_staff',
      'driver',
      'customer'
    ].where(has).toList();
    return a.isEmpty ? ['customer'] : a;
  }

  List<String> merchantIds(String role) => roles
      .where((x) => x['role'] == role && x['merchant_id'] != null)
      .map((x) => '${x['merchant_id']}')
      .toList();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? sub;
  Future<Session>? session;
  String? roleOverride; // role picked from the in-app switcher

  @override
  void initState() {
    super.initState();
    if (sb.auth.currentSession != null) session = loadSession();
    sub = sb.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedIn)
        setState(() {
          roleOverride = null;
          session = loadSession();
        });
      if (s.event == AuthChangeEvent.signedOut) {
        activeBrand.value = brands['login']!;
        setState(() => session = null);
      }
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  Future<Session> loadSession() async {
    final roles = await sb
        .from('user_roles')
        .select('role, merchant_id')
        .eq('user_id', myId!);
    final profile = await sb.from('profiles').select().eq('id', myId!).single();
    if (profile['is_active'] == false) {
      await sb.auth.signOut();
      throw Exception('هذا الحساب موقوف، تواصل مع الإدارة');
    }
    await loadUserLanguage();
    final s = Session(List<Map<String, dynamic>>.from(roles), profile);
    // Switch the look before the app opens, so the first frame already has its identity.
    activeBrand.value = brands[s.available.first] ?? brands['customer']!;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      useBrand('login');
      return const LoginPage();
    }
    return FutureBuilder<Session>(
      future: session,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(errText(snap.error!)),
                TextButton(
                    onPressed: () => sb.auth.signOut(),
                    child: const Text('تسجيل الخروج')),
              ]),
            ),
          );
        }
        if (!snap.hasData)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        final s = snap.data!;
        final available = [
          'admin',
          'merchant_owner',
          'merchant_staff',
          'driver',
          'customer'
        ].where(s.has).toList();
        if (available.isEmpty) available.add('customer');
        final role = (roleOverride != null && available.contains(roleOverride))
            ? roleOverride!
            : available.first;
        final switcher = available.length > 1
            ? RoleSwitcher(
                current: role,
                roles: available,
                onPick: (r) {
                  activeBrand.value = brands[r] ?? brands['customer']!;
                  setState(() => roleOverride = r);
                })
            : null;
        useBrand(role);
        return switch (role) {
          'admin' => AdminShell(profile: s.profile, switcher: switcher),
          'merchant_owner' => MerchantShell(
              merchantIds: s.merchantIds('merchant_owner'),
              owner: true,
              switcher: switcher),
          'merchant_staff' => MerchantShell(
              merchantIds: s.merchantIds('merchant_staff'),
              owner: false,
              switcher: switcher),
          'driver' => DriverShell(profile: s.profile, switcher: switcher),
          _ => CustomerShell(profile: s.profile, switcher: switcher),
        };
      },
    );
  }
}

/// Switch the whole app's look to [key]'s identity after this frame.
void useBrand(String key) {
  final b = brands[key] ?? brands['customer']!;
  if (activeBrand.value != b)
    WidgetsBinding.instance.addPostFrameCallback((_) => activeBrand.value = b);
}

/// Switches between the apps an account can open, shown as gradient role cards.
class RoleSwitcher extends StatelessWidget {
  const RoleSwitcher(
      {super.key,
      required this.current,
      required this.roles,
      required this.onPick});
  final String current;
  final List<String> roles;
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final cur = roleGradients[current] ?? G.violet;
    return PopupMenuButton<String>(
      tooltip: tr('التبديل بين صلاحيات الحساب'),
      onSelected: onPick,
      offset: const Offset(0, 52),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 14,
      shadowColor: Colors.black45,
      constraints: const BoxConstraints(minWidth: 300, maxWidth: 320),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      menuPadding: const EdgeInsets.all(10),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 40,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(children: [
            Icon(Icons.swap_horiz_rounded, size: 18, color: cur.first),
            const SizedBox(width: 6),
            Text('التبديل بين الواجهات',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: cur.first)),
          ]),
        ),
        for (final r in roles)
          PopupMenuItem<String>(
            value: r,
            height: 0,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _RoleTile(role: r, selected: r == current),
          ),
      ],
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: 10, end: 6),
        padding: const EdgeInsetsDirectional.fromSTEB(6, 5, 12, 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: .14),
          border: Border.all(color: Colors.white.withValues(alpha: .35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: cur),
                border: Border.all(color: Colors.white, width: 1.4)),
            child: Icon(roleIcons[current] ?? Icons.person,
                size: 15, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(roleLabels[current] ?? current,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more, size: 18, color: Colors.white),
        ]),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({required this.role, required this.selected});
  final String role;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final g = roleGradients[role] ?? G.violet;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: selected
            ? LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: g)
            : LinearGradient(colors: [
                g.first.withValues(alpha: .07),
                g.last.withValues(alpha: .12)
              ]),
        border: Border.all(
            color:
                selected ? Colors.transparent : g.first.withValues(alpha: .18)),
        boxShadow: selected
            ? [
                BoxShadow(
                    color: g.first.withValues(alpha: .35),
                    blurRadius: 12,
                    offset: const Offset(0, 5))
              ]
            : null,
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: selected ? Colors.white.withValues(alpha: .22) : null,
            gradient: selected ? null : LinearGradient(colors: g),
          ),
          child: Icon(roleIcons[role] ?? Icons.person,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(roleLabels[role] ?? role,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : g.first)),
                Text(roleHints[role] ?? '',
                    style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white70 : Colors.black54)),
              ]),
        ),
        if (selected)
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.white),
            child: Icon(Icons.check_rounded, size: 18, color: g.first),
          )
        else
          Icon(Icons.chevron_right, color: g.first.withValues(alpha: .6)),
      ]),
    );
  }
}

/// Shared app-bar actions: role switcher (if any) and sign out.
List<Widget> commonActions(BuildContext context, Widget? switcher) => [
      const LangButton(),
      if (switcher != null) switcher,
      IconButton(
        tooltip: tr('تسجيل الخروج'),
        icon: const Icon(Icons.logout),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('تسجيل الخروج؟'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('إلغاء')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('خروج')),
              ],
            ),
          );
          if (ok == true) {
            await logEvent('logout');
            await pushSignOut();
            await sb.auth.signOut();
          }
        },
      ),
    ];
