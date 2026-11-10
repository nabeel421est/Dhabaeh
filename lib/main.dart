import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/gate.dart';
import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('A11Y')) SemanticsBinding.instance.ensureSemantics();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const DhabaehApp());
}

const brand = Color(0xFF7A1E2C);

class DhabaehApp extends StatelessWidget {
  const DhabaehApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: brand, primary: brand, surface: const Color(0xFFFBF8F3));
    return MaterialApp(
      title: 'ذبائح البحرين',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'BH'),
      supportedLocales: const [Locale('ar', 'BH'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFBF8F3),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2DDD3))),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDDD6CA))),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFFBF8F3), surfaceTintColor: Colors.transparent),
      ),
      home: const AuthGate(),
    );
  }
}
