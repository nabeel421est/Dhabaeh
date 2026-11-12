import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/common.dart';
import '../core/config.dart';
import 'signup_page.dart';
import '../core/ttext.dart';
import '../core/lang_button.dart';
import '../core/i18n.dart';

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
    await guard(context, () async {
      await sb.auth
          .signInWithPassword(email: emailForPhone(p), password: pass.text);
      logEvent('login');
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final b = brands['login']!;
    return Scaffold(
      body: AuthBackdrop(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                        labelText: tr('كلمة المرور'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: tr(hide ? 'إظهار' : 'إخفاء'),
                          icon: Icon(hide
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => hide = !hide),
                        ),
                      ),
                      validator: (v) => (v ?? '').length >= 6
                          ? null
                          : tr('كلمة المرور 6 أحرف على الأقل'),
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
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SignupPage())),
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
            child: _Glow(320, const Color(0xFFB03C62).withValues(alpha: .25))),
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
        const PositionedDirectional(
            top: 0,
            end: 0,
            child: SafeArea(
                child:
                    Padding(padding: EdgeInsets.all(12), child: LangButton()))),
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
    final s = compact ? 130.0 : 210.0;
    return Column(children: [
      Semantics(
        label: appName,
        child: Container(
          width: s,
          height: s,
          padding: EdgeInsets.all(compact ? 6 : 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF6EEEA),
            borderRadius: BorderRadius.circular(compact ? 22 : 34),
            border: Border.all(color: b.accent, width: 1.6),
            boxShadow: [
              BoxShadow(
                  color: b.accent.withValues(alpha: .35),
                  blurRadius: 30,
                  spreadRadius: 1),
              BoxShadow(
                  color: Colors.black.withValues(alpha: .3),
                  blurRadius: 24,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 16 : 26),
            child: Image.asset('assets/brand/logo-full.png',
                fit: BoxFit.cover, filterQuality: FilterQuality.medium),
          ),
        ),
      ),
      SizedBox(height: compact ? 8 : 14),
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
            labelText: tr(required ? 'رقم الجوال *' : 'رقم الجوال'),
            prefixIcon: const Icon(Icons.phone_iphone),
            suffix: const Text('+973',
                textDirection: TextDirection.ltr,
                style: TextStyle(color: Colors.black54)),
            hintText: tr('3XXX XXXX')),
        validator: (v) =>
            normPhone(v ?? '').length == 8 ? null : tr('رقم الجوال 8 أرقام'),
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
