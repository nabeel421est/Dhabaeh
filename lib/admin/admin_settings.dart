import 'package:flutter/material.dart' hide Text;

import '../core/brand.dart';
import '../core/common.dart';
import '../core/ttext.dart';

/// General settings for all the apps: default language, customer payment
/// methods and the support contacts customers see.
class AdminSettings extends StatelessWidget {
  const AdminSettings({super.key});
  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
        realtimeTables: const ['platform_settings'],
        load: () async =>
            await sb.from('platform_settings').select().eq('id', 1).single(),
        builder: (context, s, reload) => _Body(s: s, reload: reload),
      );
}

class _Body extends StatefulWidget {
  const _Body({required this.s, required this.reload});
  final Map<String, dynamic> s;
  final Future<void> Function() reload;
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late String lang = '${widget.s['default_lang'] ?? 'ar'}';
  late bool benefit = widget.s['allow_benefitpay'] != false;
  late bool bank = widget.s['allow_bank_transfer'] != false;
  late bool cod = widget.s['allow_cod'] != false;
  late final phone =
      TextEditingController(text: widget.s['support_phone'] ?? '');
  late final whats =
      TextEditingController(text: widget.s['support_whatsapp'] ?? '');

  Future<void> save() async {
    if (!benefit && !bank && !cod) {
      return toast(context, 'فعّل طريقة دفع واحدة على الأقل', error: true);
    }
    await guard(
        context,
        () => sb.from('platform_settings').update({
              'default_lang': lang,
              'allow_benefitpay': benefit,
              'allow_bank_transfer': bank,
              'allow_cod': cod,
              'support_phone':
                  phone.text.trim().isEmpty ? null : normPhone(phone.text),
              'support_whatsapp':
                  whats.text.trim().isEmpty ? null : normPhone(whats.text),
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', 1),
        ok: 'تم حفظ الإعدادات');
    await widget.reload();
  }

  @override
  Widget build(BuildContext context) {
    final on = [benefit, bank, cod].where((x) => x).length;
    return ListView(padding: const EdgeInsets.all(18), children: [
      PageHero(
        icon: Icons.settings_outlined,
        title: 'الإعدادات',
        subtitle: 'إعدادات تطبيقات العميل والتاجر والموظف والمندوب',
        stats: [
          ('اللغة الافتراضية', lang == 'en' ? 'English' : 'العربية'),
          ('طرق الدفع', '$on/3'),
        ],
        action: HeroButton(
            icon: Icons.save_outlined, label: 'حفظ الإعدادات', onPressed: save),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        final two = c.maxWidth >= 900;
        final w = two ? (c.maxWidth - 14) / 2 : c.maxWidth;
        return Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(
            width: w,
            child: GradientHeaderCard(
              title: 'اللغة',
              subtitle: 'لغة كل التطبيقات لمن لم يختر لغته بعد',
              icon: Icons.translate,
              colors: G.sapphire,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      for (final l in const [
                        ('ar', 'العربية', 'من اليمين لليسار'),
                        ('en', 'English', 'Left to right'),
                      ]) ...[
                        Expanded(
                            child: _Choice(
                                title: l.$2,
                                hint: l.$3,
                                selected: lang == l.$1,
                                colors: G.sapphire,
                                onTap: () => setState(() => lang = l.$1))),
                        if (l.$1 == 'ar') const SizedBox(width: 10),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    const _Note(
                        icon: Icons.info_outline,
                        text:
                            'كل مستخدم يقدر يغيّر لغته من زر اللغة أعلى التطبيق، ويُحفظ اختياره في حسابه.'),
                  ]),
            ),
          ),
          SizedBox(
            width: w,
            child: GradientHeaderCard(
              title: 'طرق الدفع في تطبيق العميل',
              subtitle: 'الطرق المتوقفة لا تظهر للعميل عند الطلب',
              icon: Icons.payments_outlined,
              colors: G.emerald,
              child: Column(children: [
                _Toggle(
                    icon: Icons.phone_iphone,
                    title: 'BenefitPay',
                    hint: 'ادفع من تطبيق بنفت',
                    value: benefit,
                    colors: G.emerald,
                    onChanged: (v) => setState(() => benefit = v)),
                _Toggle(
                    icon: Icons.account_balance_outlined,
                    title: 'تحويل بنكي',
                    hint: 'حوّل وارفع الإيصال',
                    value: bank,
                    colors: G.emerald,
                    onChanged: (v) => setState(() => bank = v)),
                _Toggle(
                    icon: Icons.payments_outlined,
                    title: 'نقداً عند الاستلام',
                    hint: 'ادفع للمندوب عند الاستلام',
                    value: cod,
                    colors: G.emerald,
                    onChanged: (v) => setState(() => cod = v)),
              ]),
            ),
          ),
          SizedBox(
            width: w,
            child: GradientHeaderCard(
              title: 'التواصل والدعم',
              subtitle: 'يظهر للعميل في صفحة معلوماتي',
              icon: Icons.support_agent_outlined,
              colors: G.violet,
              child: Column(children: [
                Field('هاتف الدعم', phone,
                    ltr: true,
                    keyboard: TextInputType.phone,
                    hint: '1700 0000'),
                const SizedBox(height: 10),
                Field('واتساب الدعم', whats,
                    ltr: true,
                    keyboard: TextInputType.phone,
                    hint: '3XXX XXXX'),
              ]),
            ),
          ),
        ]);
      }),
      const SizedBox(height: 18),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ الإعدادات')),
      ),
    ]);
  }
}

class _Choice extends StatelessWidget {
  const _Choice(
      {required this.title,
      required this.hint,
      required this.selected,
      required this.colors,
      required this.onTap});
  final String title, hint;
  final bool selected;
  final List<Color> colors;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected ? LinearGradient(colors: colors) : null,
            color: selected ? null : Colors.white,
            border: Border.all(
                color: selected
                    ? Colors.transparent
                    : colors.first.withValues(alpha: .25)),
          ),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Colors.white : colors.first),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: selected ? Colors.white : colors.first)),
                    Text(hint,
                        style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white70 : Colors.black54)),
                  ]),
            ),
          ]),
        ),
      );
}

class _Toggle extends StatelessWidget {
  const _Toggle(
      {required this.icon,
      required this.title,
      required this.hint,
      required this.value,
      required this.colors,
      required this.onChanged});
  final IconData icon;
  final String title, hint;
  final bool value;
  final List<Color> colors;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          GradientBadge(
              colors: value ? colors : [Colors.grey, Colors.grey.shade400],
              icon: icon,
              size: 40),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(hint,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
          Switch(
              value: value,
              activeTrackColor: colors.first,
              onChanged: onChanged),
        ]),
      );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: const Color(0xFF2F5BD3)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 12.5, height: 1.5))),
        ]),
      );
}
