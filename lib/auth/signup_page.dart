import 'package:flutter/material.dart' hide Text;
import '../core/search_pick.dart';
import 'package:latlong2/latlong.dart';

import '../core/address_map.dart';
import '../core/brand.dart';
import '../core/common.dart';
import '../core/config.dart';
import 'login_page.dart';
import '../core/ttext.dart';
import '../core/i18n.dart';

/// New customer account: personal details, full address, and a map pin
/// located from the address (the customer can tap the map to adjust it).
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final cpr = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final pass2 = TextEditingController();
  final flat = TextEditingController();
  final building = TextEditingController();
  final road = TextEditingController();
  final block = TextEditingController();
  final areaText = TextEditingController();
  String? city;
  String? area;
  List<String> zones = [];
  LatLng? pin;
  bool locating = false;
  bool busy = false;
  bool hide = true;
  String? locateNote;

  @override
  void initState() {
    super.initState();
    sb.rpc('public_zone_names').then((r) {
      if (!mounted) return;
      setState(() => zones = [for (final z in (r as List? ?? [])) '$z']);
    }).catchError((_) {});
  }

  String get areaValue => zones.isEmpty ? areaText.text.trim() : (area ?? '');

  Future<void> locate() async {
    if ((city ?? '').isEmpty || areaValue.isEmpty) {
      toast(context, 'اختر المدينة والمنطقة أولاً', error: true);
      return;
    }
    setState(() {
      locating = true;
      locateNote = null;
    });
    final p = await geocodeBahrain(
        building: building.text.trim(),
        block: block.text.trim(),
        road: road.text.trim(),
        area: areaValue,
        city: city);
    if (!mounted) return;
    setState(() {
      locating = false;
      if (p != null) {
        pin = p;
        locateNote = 'تم تحديد الموقع التقريبي، اضغط على الخريطة لتدقيقه';
      } else {
        locateNote = 'ما قدرنا نحدد العنوان، اضغط على الخريطة لتحديد موقعك';
      }
    });
  }

  Future<void> useGps() async {
    setState(() => locating = true);
    try {
      final p = await currentLocation();
      if (!mounted) return;
      setState(() {
        pin = p;
        locateNote = 'تم تحديد موقعك الحالي بدقة';
      });
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
    if (mounted) setState(() => locating = false);
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) {
      toast(context, 'أكمل الحقول المطلوبة', error: true);
      return;
    }
    final p = normPhone(phone.text);
    setState(() => busy = true);
    final ok = await guard(context, () async {
      await usersFn({
        'action': 'signup',
        'phone': p,
        'password': pass.text,
        'full_name': name.text.trim().replaceAll(RegExp(r'\s+'), ' '),
        'cpr': cpr.text.trim(),
        'email': email.text.trim(),
        'address': {
          'city': city,
          'area': areaValue,
          'building': building.text.trim(),
          'flat': flat.text.trim(),
          'road': road.text.trim(),
          'block': block.text.trim(),
          'lat': pin?.latitude,
          'lng': pin?.longitude,
        },
      });
      await sb.auth
          .signInWithPassword(email: emailForPhone(p), password: pass.text);
      return true;
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (ok == true) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  String? req(String? v, String label) =>
      (v ?? '').trim().isEmpty ? '$label مطلوب' : null;

  @override
  Widget build(BuildContext context) {
    final b = brands['login']!;
    return Scaffold(
      body: AuthBackdrop(
        maxWidth: 560,
        child: Form(
          key: form,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconButton(
                tooltip: tr('رجوع'),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .12)),
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
              ),
              const Spacer(),
            ]),
            const AuthEmblem(compact: true),
            const SizedBox(height: 6),
            const Text('أنشئ حسابك وابدأ الطلب من أفضل الملاحم',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            // ------------------------------------------------ personal details
            AuthCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthCardTitle(
                        icon: Icons.badge_outlined,
                        title: 'البيانات الشخصية',
                        subtitle: 'الحقول المعلّمة بـ * مطلوبة'),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(
                          labelText: tr('الاسم الثلاثي *'),
                          prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) {
                        final parts = (v ?? '')
                            .trim()
                            .split(RegExp(r'\s+'))
                            .where((x) => x.isNotEmpty);
                        return parts.length < 3
                            ? tr('اكتب الاسم الثلاثي')
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    PhoneField(ctrl: phone, required: true),
                    const SizedBox(height: 12),
                    _pair(
                      TextFormField(
                        controller: cpr,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                            labelText: tr('الرقم الشخصي'),
                            prefixIcon: Icon(Icons.credit_card_outlined)),
                        validator: (v) {
                          final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                          return d.isEmpty || d.length == 9
                              ? null
                              : tr('الرقم الشخصي 9 أرقام');
                        },
                      ),
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                            labelText: tr('البريد الإلكتروني'),
                            prefixIcon: Icon(Icons.alternate_email)),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          return s.isEmpty ||
                                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(s)
                              ? null
                              : tr('البريد غير صحيح');
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _pair(
                      TextFormField(
                        controller: pass,
                        obscureText: hide,
                        decoration: InputDecoration(
                          labelText: tr('كلمة المرور *'),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(hide
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => hide = !hide),
                          ),
                        ),
                        validator: (v) => (v ?? '').length >= 6
                            ? null
                            : tr('6 أحرف على الأقل'),
                      ),
                      TextFormField(
                        controller: pass2,
                        obscureText: hide,
                        decoration: InputDecoration(
                            labelText: tr('تأكيد كلمة المرور *'),
                            prefixIcon: Icon(Icons.lock_reset_outlined)),
                        validator: (v) => v == pass.text
                            ? null
                            : tr('كلمتا المرور غير متطابقتين'),
                      ),
                    ),
                  ]),
            ),
            const SizedBox(height: 16),
            // ------------------------------------------------ address
            AuthCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthCardTitle(
                        icon: Icons.home_work_outlined,
                        title: 'العنوان',
                        subtitle: 'يُستخدم للتوصيل ويتعبأ تلقائياً عند الطلب'),
                    const SizedBox(height: 18),
                    _pair(
                      SearchPickField.strings(
                          value: city,
                          items: bahrainCities,
                          decoration: InputDecoration(
                              labelText: tr('المدينة *'),
                              prefixIcon: Icon(Icons.location_city_outlined)),
                          onChanged: (v) => setState(() => city = v),
                          validator: (v) => req(v, tr('المدينة')),
                          icon: Icons.location_city_outlined),
                      zones.isEmpty
                          ? TextFormField(
                              controller: areaText,
                              decoration: InputDecoration(
                                  labelText: tr('المنطقة *'),
                                  prefixIcon: Icon(Icons.map_outlined)),
                              validator: (v) => req(v, tr('المنطقة')),
                            )
                          : SearchPickField.strings(
                              value: area,
                              items: zones,
                              decoration: InputDecoration(
                                  labelText: tr('المنطقة *'),
                                  prefixIcon: Icon(Icons.map_outlined)),
                              onChanged: (v) => setState(() => area = v),
                              validator: (v) => req(v, tr('المنطقة')),
                              icon: Icons.map_outlined),
                    ),
                    const SizedBox(height: 12),
                    _pair(
                      _num(building, 'المبنى *', Icons.apartment_outlined,
                          required: true),
                      _num(flat, 'الشقة', Icons.door_front_door_outlined),
                    ),
                    const SizedBox(height: 12),
                    _pair(
                      _num(road, 'الطريق *', Icons.signpost_outlined,
                          required: true),
                      _num(block, 'المجمع *', Icons.grid_view_outlined,
                          required: true),
                    ),
                  ]),
            ),
            const SizedBox(height: 16),
            // ------------------------------------------------ map
            AuthCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthCardTitle(
                        icon: Icons.pin_drop_outlined,
                        title: 'الموقع على الخريطة',
                        subtitle: 'نحدده من عنوانك، وتقدر تعدّله بلمسة'),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            backgroundColor: b.stops[1],
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: locating ? null : useGps,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('موقعي الحالي'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            foregroundColor: b.stops[1],
                            side: BorderSide(color: b.accent, width: 1.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: locating ? null : locate,
                          icon: locating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.travel_explore, size: 18),
                          label: const Text('من العنوان'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    AddressMap(
                      point: pin,
                      color: b.stops[1],
                      onPick: (p) => setState(() {
                        pin = p;
                        locateNote = 'تم تثبيت الموقع على النقطة المختارة';
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(
                          pin == null
                              ? Icons.touch_app_outlined
                              : Icons.check_circle,
                          size: 16,
                          color:
                              pin == null ? Colors.black45 : G.emerald.first),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            locateNote ??
                                'اختر "موقعي الحالي" إذا كنت في البيت، أو حدّد من العنوان واضغط على الخريطة للتدقيق',
                            style: const TextStyle(
                                fontSize: 12.5, color: Colors.black54)),
                      ),
                    ]),
                  ]),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'إنشاء الحساب',
              icon: Icons.check_circle_outline,
              busy: busy,
              onPressed: submit,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('عندي حساب، تسجيل الدخول',
                  style:
                      TextStyle(color: b.accent, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _pair(Widget a, Widget b) => LayoutBuilder(
        builder: (context, c) => c.maxWidth < 380
            ? Column(children: [a, const SizedBox(height: 12), b])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: a),
                const SizedBox(width: 10),
                Expanded(child: b),
              ]),
      );

  Widget _num(TextEditingController c, String label, IconData icon,
          {bool required = false}) =>
      TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration:
            InputDecoration(labelText: tr(label), prefixIcon: Icon(icon)),
        validator: required ? (v) => req(v, label.replaceAll(' *', '')) : null,
      );
}
