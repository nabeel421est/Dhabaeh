import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/gate.dart';
import 'core/brand.dart';
import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('A11Y'))
    SemanticsBinding.instance.ensureSemantics();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const DhabaehApp());
}

class DhabaehApp extends StatelessWidget {
  const DhabaehApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Brand>(
      valueListenable: activeBrand,
      builder: (context, b, _) => MaterialApp(
        title: 'ذبائح البحرين',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar', 'BH'),
        supportedLocales: const [Locale('ar', 'BH'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: brandTheme(b),
        themeAnimationDuration: const Duration(milliseconds: 450),
        home: const AuthGate(),
      ),
    );
  }
}
