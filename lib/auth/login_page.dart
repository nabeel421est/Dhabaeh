import 'package:flutter/material.dart';

import '../core/brand.dart';
import '../core/common.dart';
import '../core/config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final phone = TextEditingController();
  final pass = TextEditingController();
  final name = TextEditingController();
  bool signup = false;
  bool busy = false;

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final p = normPhone(phone.text);
    setState(() => busy = true);
    await guard(context, () async {
      if (signup) {
        await usersFn({
          'action': 'signup',
          'phone': p,
          'password': pass.text,
          'full_name': name.text.trim()
        });
      }
      await sb.auth
          .signInWithPassword(email: emailForPhone(p), password: pass.text);
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final b = brands['login']!;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: b.stops)),
        child: Stack(children: [
          PositionedDirectional(
              top: -80,
              end: -60,
              child: _Glow(260, Colors.white.withValues(alpha: .06))),
          PositionedDirectional(
              bottom: -100,
              start: -70,
              child: _Glow(300, b.accent.withValues(alpha: .14))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.white.withValues(alpha: .1),
                              border: Border.all(
                                  color: b.accent.withValues(alpha: .8),
                                  width: 1.4),
                            ),
                            child: Icon(Icons.storefront,
                                color: b.accent, size: 40),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text('ذبائح البحرين',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        Text(b.tagline,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: .25),
                                  blurRadius: 30,
                                  offset: const Offset(0, 14))
                            ],
                          ),
                          child: Form(
                            key: form,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(signup ? 'حساب جديد' : 'تسجيل الدخول',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 16),
                                  if (signup) ...[
                                    Field('الاسم', name, required: true),
                                    const SizedBox(height: 12),
                                  ],
                                  TextFormField(
                                    controller: phone,
                                    keyboardType: TextInputType.phone,
                                    textDirection: TextDirection.ltr,
                                    decoration: const InputDecoration(
                                        labelText: 'رقم الجوال',
                                        prefixText: '+973 ',
                                        hintText: '3XXX XXXX'),
                                    validator: (v) =>
                                        normPhone(v ?? '').length == 8
                                            ? null
                                            : 'رقم الجوال 8 أرقام',
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: pass,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                        labelText: 'كلمة المرور'),
                                    validator: (v) => (v ?? '').length >= 6
                                        ? null
                                        : 'كلمة المرور 6 أحرف على الأقل',
                                    onFieldSubmitted: (_) => submit(),
                                  ),
                                  const SizedBox(height: 20),
                                  FilledButton(
                                    onPressed: busy ? null : submit,
                                    child: busy
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : Text(signup
                                            ? 'إنشاء الحساب والدخول'
                                            : 'دخول'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => signup = !signup),
                                    child: Text(signup
                                        ? 'عندي حساب، تسجيل الدخول'
                                        : 'ما عندك حساب؟ سجّل كعميل'),
                                  ),
                                ]),
                          ),
                        ),
                      ]),
                ),
              ),
            ),
          ),
        ]),
      ),
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
