import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/common.dart';
import '../core/config.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final phone = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  bool hide = true;

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final p = normPhone(phone.text);
    setState(() => busy = true);
    await guard(
        context,
        () => sb.auth
            .signInWithPassword(email: emailForPhone(p), password: pass.text));
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final b = brands['login']!;
    return Scaffold(
      body: AuthBackdrop(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const AuthEmblem(),
          const SizedBox(height: 26),
          AuthCard(
            child: Form(
              key: form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthCardTitle(
                        icon: Icons.login_rounded,
                        title: 'تسجيل الدخول',
                        subtitle: 'أهلاً بعودتك، ادخل برقم جوالك'),
                    const SizedBox(height: 20),
                    PhoneField(ctrl: phone),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: pass,
                      obscureText: hide,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: hide ? 'إظهار' : 'إخفاء',
                          icon: Icon(hide
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => hide = !hide),
                        ),
                      ),
                      validator: (v) => (v ?? '').length >= 6
                          ? null
                          : 'كلمة المرور 6 أحرف على الأقل',
                      onFieldSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: 22),
                    GradientButton(
                      label: 'دخول',
                      icon: Icons.arrow_forward,
                      busy: busy,
                      onPressed: submit,
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('ما عندك حساب؟',
                            style: TextStyle(
                                color: Colors.black.withValues(alpha: .5),
                                fontSize: 13)),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: b.stops[1],
                        side: BorderSide(
                            color: b.accent.withValues(alpha: .9), width: 1.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SignupPage())),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('سجّل حساب جديد',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ]),
            ),
          ),
          const SizedBox(height: 22),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _Perk(Icons.verified_outlined, 'ذبح شرعي موثوق'),
              _Perk(Icons.local_shipping_outlined, 'توصيل لباب البيت'),
              _Perk(Icons.lock_outline, 'دفع آمن'),
            ],
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- shared auth pieces

/// Deep gradient backdrop with soft glows, shared by sign-in and sign-up.
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child, this.maxWidth = 440});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) {
    final b = brands['login']!;
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [b.stops[0], b.stops[1], b.stops[2]])),
      child: Stack(children: [
        PositionedDirectional(
            top: -90,
            end: -70,
            child: _Glow(280, b.accent.withValues(alpha: .16))),
        PositionedDirectional(
            top: 180,
            start: -120,
            child: _Glow(240, Colors.white.withValues(alpha: .05))),
        PositionedDirectional(
            bottom: -120,
            end: -40,
            child: _Glow(320, const Color(0xFFD0646B).withValues(alpha: .22))),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child),
            ),
          ),
        ),
      ]),
    );
  }
}

class AuthEmblem extends StatelessWidget {
  const AuthEmblem({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final b = brands['login']!;
    final s = compact ? 64.0 : 92.0;
    return Column(children: [
      Container(
        width: s,
        height: s,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
              colors: [b.accent, const Color(0xFFFFF1CF), b.accent]),
          boxShadow: [
            BoxShadow(
                color: b.accent.withValues(alpha: .35),
                blurRadius: 28,
                spreadRadius: 2)
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [b.stops[1], b.stops[0]])),
          child: Icon(Icons.storefront_rounded,
              color: b.accent, size: compact ? 30 : 44),
        ),
      ),
      SizedBox(height: compact ? 8 : 14),
      ShaderMask(
        shaderCallback: (r) => LinearGradient(
                colors: [Colors.white, b.accent, Colors.white])
            .createShader(r),
        child: Text('ذبائح البحرين',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: compact ? 24 : 32,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ),
      if (!compact) ...[
        const SizedBox(height: 4),
        Text(b.tagline,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14.5)),
      ],
    ]);
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final b = brands['login']!;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [b.accent, b.accent.withValues(alpha: .15), b.accent]),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .32),
              blurRadius: 34,
              offset: const Offset(0, 16))
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: const Color(0xFFFFFBF7),
            borderRadius: BorderRadius.circular(26)),
        child: child,
      ),
    );
  }
}

class AuthCardTitle extends StatelessWidget {
  const AuthCardTitle(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final b = brands['login']!;
    return Row(children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(colors: [b.stops[1], b.stops[2]])),
        child: Icon(icon, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: b.stops[0])),
          Text(subtitle,
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ]),
      ),
    ]);
  }
}

class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.ctrl, this.required = false});
  final TextEditingController ctrl;
  final bool required;
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
            labelText: required ? 'رقم الجوال *' : 'رقم الجوال',
            prefixIcon: const Icon(Icons.phone_iphone),
            suffix: const Text('+973',
                textDirection: TextDirection.ltr,
                style: TextStyle(color: Colors.black54)),
            hintText: '3XXX XXXX'),
        validator: (v) =>
            normPhone(v ?? '').length == 8 ? null : 'رقم الجوال 8 أرقام',
      );
}

class GradientButton extends StatelessWidget {
  const GradientButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.busy = false});
  final String label;
  final IconData? icon;
  final bool busy;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final b = brands['login']!;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [b.stops[0], b.stops[1], b.stops[2]]),
        boxShadow: [
          BoxShadow(
              color: b.stops[1].withValues(alpha: .4),
              blurRadius: 16,
              offset: const Offset(0, 8))
        ],
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800)),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, color: b.accent, size: 20),
                ],
              ]),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final b = brands['login']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: b.accent.withValues(alpha: .4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: b.accent),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 12.5)),
      ]),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow(this.size, this.color);
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}
