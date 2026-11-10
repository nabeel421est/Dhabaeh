import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_shell.dart';
import '../core/common.dart';
import '../customer/customer_shell.dart';
import '../driver/driver_shell.dart';
import '../merchant/merchant_shell.dart';
import 'login_page.dart';

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
  List<String> merchantIds(String role) =>
      roles.where((x) => x['role'] == role && x['merchant_id'] != null).map((x) => '${x['merchant_id']}').toList();
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
      if (s.event == AuthChangeEvent.signedIn) setState(() { roleOverride = null; session = loadSession(); });
      if (s.event == AuthChangeEvent.signedOut) setState(() => session = null);
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  Future<Session> loadSession() async {
    final roles = await sb.from('user_roles').select('role, merchant_id').eq('user_id', myId!);
    final profile = await sb.from('profiles').select().eq('id', myId!).single();
    if (profile['is_active'] == false) {
      await sb.auth.signOut();
      throw Exception('هذا الحساب موقوف، تواصل مع الإدارة');
    }
    return Session(List<Map<String, dynamic>>.from(roles), profile);
  }

  @override
  Widget build(BuildContext context) {
    if (session == null) return const LoginPage();
    return FutureBuilder<Session>(
      future: session,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(errText(snap.error!)),
                TextButton(onPressed: () => sb.auth.signOut(), child: const Text('تسجيل الخروج')),
              ]),
            ),
          );
        }
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final s = snap.data!;
        final available = ['admin', 'merchant_owner', 'merchant_staff', 'driver', 'customer'].where(s.has).toList();
        if (available.isEmpty) available.add('customer');
        final role = (roleOverride != null && available.contains(roleOverride)) ? roleOverride! : available.first;
        final switcher = available.length > 1
            ? RoleSwitcher(current: role, roles: available, onPick: (r) => setState(() => roleOverride = r))
            : null;
        return switch (role) {
          'admin' => AdminShell(profile: s.profile, switcher: switcher),
          'merchant_owner' => MerchantShell(merchantIds: s.merchantIds('merchant_owner'), owner: true, switcher: switcher),
          'merchant_staff' => MerchantShell(merchantIds: s.merchantIds('merchant_staff'), owner: false, switcher: switcher),
          'driver' => DriverShell(profile: s.profile, switcher: switcher),
          _ => CustomerShell(profile: s.profile, switcher: switcher),
        };
      },
    );
  }
}

class RoleSwitcher extends StatelessWidget {
  const RoleSwitcher({super.key, required this.current, required this.roles, required this.onPick});
  final String current;
  final List<String> roles;
  final void Function(String) onPick;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'التبديل بين صلاحيات الحساب',
        icon: const Icon(Icons.swap_horiz),
        onSelected: onPick,
        itemBuilder: (_) => [
          for (final r in roles)
            CheckedPopupMenuItem(value: r, checked: r == current, child: Text(roleLabels[r] ?? r)),
        ],
      );
}

/// Shared app-bar actions: role switcher (if any) and sign out.
List<Widget> commonActions(BuildContext context, Widget? switcher) => [
      if (switcher != null) switcher,
      IconButton(
        tooltip: 'تسجيل الخروج',
        icon: const Icon(Icons.logout),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('تسجيل الخروج؟'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('خروج')),
              ],
            ),
          );
          if (ok == true) await sb.auth.signOut();
        },
      ),
    ];
