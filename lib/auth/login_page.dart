import 'package:flutter/material.dart';

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
        await usersFn({'action': 'signup', 'phone': p, 'password': pass.text, 'full_name': name.text.trim()});
      }
      await sb.auth.signInWithPassword(email: emailForPhone(p), password: pass.text);
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.storefront, color: Colors.white, size: 38),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('ذبائح البحرين', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const Text('ذبيحتك من المسلخ إلى باب بيتك', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 28),
                  Text(signup ? 'حساب جديد' : 'تسجيل الدخول', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  if (signup) ...[
                    Field('الاسم', name, required: true),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'رقم الجوال', prefixText: '+973 ', hintText: '3XXX XXXX'),
                    validator: (v) => normPhone(v ?? '').length == 8 ? null : 'رقم الجوال 8 أرقام',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                    validator: (v) => (v ?? '').length >= 6 ? null : 'كلمة المرور 6 أحرف على الأقل',
                    onFieldSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(signup ? 'إنشاء الحساب والدخول' : 'دخول'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => signup = !signup),
                    child: Text(signup ? 'عندي حساب، تسجيل الدخول' : 'ما عندك حساب؟ سجّل كعميل'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
