import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n_en.dart';

/// UI language: 'ar' (default, RTL) or 'en' (LTR).
/// Chosen per user (saved on the device and on their profile); the admin sets
/// the default for people who never chose.
final appLang = ValueNotifier<String>('ar');
bool get isEn => appLang.value == 'en';

const _prefKey = 'lang';
bool _userChose = false;

/// Translate an Arabic UI string for the current language.
/// Exact match first, then templates with `{}` placeholders, then word by word.
T tr<T extends String?>(T s) {
  if (s == null || appLang.value != 'en' || s.isEmpty) return s;
  final String t = s;
  final hit = enStrings[t];
  if (hit != null) return hit as T;
  final cached = _cache[t];
  if (cached != null) return cached as T;
  final r = _template(t) ?? _words(t);
  _cache[t] = r;
  return r as T;
}

final _cache = <String, String>{};
List<(RegExp, String)>? _tpl;
final _arabic = RegExp(r'[\u0600-\u06FF]');

String? _template(String s) {
  if (!_arabic.hasMatch(s)) return s;
  _tpl ??= [
    for (final e in enStrings.entries)
      if (e.key.contains('{}') && e.key.replaceAll('{}', '').trim().isNotEmpty)
        (
          RegExp('^${e.key.split('{}').map(RegExp.escape).join('(.*?)')}\$',
              dotAll: true),
          e.value
        )
  ];
  for (final (re, v) in _tpl!) {
    final m = re.firstMatch(s);
    if (m == null) continue;
    final groups = [
      for (var g = 1; g <= m.groupCount; g++) tr(m.group(g) ?? '')
    ];
    // A short template (like "{} until {}") must not reword user content:
    // use it only when every value it wraps was translated too.
    final fixed = re.pattern.replaceAll(RegExp(r'[^\u0600-\u06FF]'), '');
    if (fixed.length < 6 && groups.any(_arabic.hasMatch)) continue;
    var i = 0;
    return v.replaceAllMapped('{}', (_) => groups[i++]);
  }
  return null;
}

/// Last resort for labels built from known words (e.g. dates). Text that
/// still has unknown Arabic (names, user content) is left as written.
String _words(String s) {
  final out = s.replaceAllMapped(
      RegExp(
          r'[\u0600-\u06FF][\u0600-\u06FF\s]*[\u0600-\u06FF]|[\u0600-\u06FF]'),
      (m) => enStrings[m[0]!] ?? m[0]!);
  return _arabic.hasMatch(out) ? s : out;
}

Future<void> _apply(String l) async {
  if (l != 'ar' && l != 'en') return;
  _cache.clear();
  appLang.value = l;
}

/// On start: the device choice, else the platform default.
Future<void> initLanguage() async {
  try {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_prefKey);
    if (saved != null) {
      _userChose = true;
      await _apply(saved);
      return;
    }
  } catch (_) {}
  try {
    final d = await Supabase.instance.client.rpc('app_default_language');
    if (d is String) await _apply(d);
  } catch (_) {}
}

/// After sign-in: the user's saved preference wins.
Future<void> loadUserLanguage() async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  try {
    final r = await Supabase.instance.client
        .from('profiles')
        .select('language')
        .eq('id', uid)
        .maybeSingle();
    final l = r?['language'];
    if (l is String) {
      await _apply(l);
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefKey, l);
    } else if (!_userChose) {
      final d = await Supabase.instance.client.rpc('app_default_language');
      if (d is String) await _apply(d);
    }
  } catch (_) {}
}

/// The user picks a language: applied now, saved on the device and profile.
Future<void> setLanguage(String l) async {
  _userChose = true;
  await _apply(l);
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKey, l);
  } catch (_) {}
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid != null) {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'language': l}).eq('id', uid);
    } catch (_) {}
  }
}
