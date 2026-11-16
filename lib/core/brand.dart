import 'package:flutter/material.dart' hide Text;
import 'ttext.dart';

/// Each app (customer, merchant, staff, driver, admin) has its own visual identity:
/// a three-stop gradient, a metallic accent, and a softly tinted surface.
class Brand {
  const Brand(
      {required this.name,
      required this.tagline,
      required this.icon,
      required this.stops,
      required this.accent,
      required this.surface,
      this.lux = false});

  /// The deluxe look (deep layered gradients, gold rims and glows), used by the customer app.
  final bool lux;
  final String name;
  final String tagline;
  final IconData icon;
  final List<Color> stops; // dark -> mid -> light
  final Color accent;
  final Color surface;

  Color get primary => stops[1];
  Color get dark => stops[0];
  LinearGradient get gradient => LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: stops);

  /// Four-stop velvet gradient with a darker floor, for the deluxe look.
  LinearGradient get deep => LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          stops: const [
            0,
            .38,
            .78,
            1
          ],
          colors: [
            Color.lerp(stops[0], Colors.black, .25)!,
            stops[1],
            stops[2],
            Color.lerp(stops[2], accent, .35)!,
          ]);

  /// Metallic gold used for rims, rules and badges.
  List<Color> get gold => [
        Color.lerp(accent, Colors.white, .55)!,
        accent,
        Color.lerp(accent, const Color(0xFF6B4410), .45)!,
      ];
  LinearGradient get soft => LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [
          Color.lerp(stops[2], Colors.white, .86)!,
          Color.lerp(accent, Colors.white, .88)!
        ],
      );
}

const brands = <String, Brand>{
  'login': Brand(
    name: 'ذبائح',
    tagline: 'ذبيحتك من الملحمة إلى باب بيتك',
    icon: Icons.storefront,
    stops: [Color(0xFF22050F), Color(0xFF5E0F2C), Color(0xFF9C2347)],
    accent: Color(0xFFE7C077),
    surface: Color(0xFFFBF7F1),
  ),
  'customer': Brand(
    name: 'ذبائح',
    tagline: 'اطلب ذبيحتك بسهولة',
    icon: Icons.shopping_bag_outlined,
    stops: [Color(0xFF2E0715), Color(0xFF6E1435), Color(0xFFB03C62)],
    accent: Color(0xFFE7C077),
    surface: Color(0xFFFBF7F1),
    lux: true,
  ),
  'merchant_owner': Brand(
    name: 'تاجر ذبائح',
    tagline: 'إدارة المسلخ',
    icon: Icons.storefront_outlined,
    stops: [Color(0xFF042F2A), Color(0xFF0D6152), Color(0xFF28A385)],
    accent: Color(0xFFE6C877),
    surface: Color(0xFFF3F8F6),
  ),
  'merchant_staff': Brand(
    name: 'موظف المسلخ',
    tagline: 'طلبات المتجر',
    icon: Icons.badge_outlined,
    stops: [Color(0xFF07313F), Color(0xFF136A82), Color(0xFF3AAFC4)],
    accent: Color(0xFFF2CF7A),
    surface: Color(0xFFF2F8FA),
  ),
  'driver': Brand(
    name: 'مندوب ذبائح',
    tagline: 'التوصيل',
    icon: Icons.local_shipping_outlined,
    stops: [Color(0xFF0B1934), Color(0xFF1C4790), Color(0xFF3D8BEA)],
    accent: Color(0xFFFFA24A),
    surface: Color(0xFFF3F6FB),
  ),
  'admin': Brand(
    name: 'الإدارة العامة',
    tagline: 'لوحة تحكم المنصة',
    icon: Icons.admin_panel_settings_outlined,
    stops: [Color(0xFF06375A), Color(0xFF0B7BC0), Color(0xFF4CC3F2)],
    accent: Color(0xFFF4C752),
    surface: Color(0xFFF1F7FB),
  ),
};

/// The identity of whichever app is open. MaterialApp rebuilds its theme from it,
/// so pushed pages and dialogs share the same look.
final activeBrand = ValueNotifier<Brand>(brands['login']!);

ThemeData brandTheme(Brand b) {
  final scheme = ColorScheme.fromSeed(
      seedColor: b.primary,
      primary: b.primary,
      secondary: b.accent,
      surface: b.surface);
  final line = Color.lerp(b.primary, Colors.white, .82)!;
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: null,
    scaffoldBackgroundColor: b.surface,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: b.dark.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: b.primary, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: b.primary,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: b.primary,
        side: BorderSide(color: Color.lerp(b.primary, Colors.white, .5)!),
        minimumSize: const Size(64, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: Color.lerp(b.primary, Colors.white, .82),
      side: BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: Color.lerp(b.primary, Colors.white, .8),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? b.dark : Colors.black45)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? b.dark : Colors.black54,
          )),
    ),
    listTileTheme: ListTileThemeData(
        selectedColor: b.dark,
        selectedTileColor: Color.lerp(b.primary, Colors.white, .88)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? b.primary : null),
    ),
    dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
          color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
    ),
  );
}

/// App bar painted with the open app's gradient, with a thin accent line at the bottom.
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GradientAppBar(
      {super.key,
      this.title,
      this.actions,
      this.bottom,
      this.leading,
      this.logo = false});
  final Widget? title;

  /// Shows the brand emblem before the title (the main screen of each app).
  final bool logo;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + 3 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final b = brandOf(context);
    return AppBar(
      titleSpacing: logo ? 8 : null,
      title: title == null
          ? null
          : DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: logo
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      const AppLogo(size: 38, glow: false),
                      const SizedBox(width: 10),
                      Flexible(child: title!),
                    ])
                  : title!),
      actions: actions,
      leading: leading,
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(3 + (bottom?.preferredSize.height ?? 0)),
        child: Column(children: [
          if (bottom != null) bottom!,
          Container(
              height: 3,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                b.accent.withValues(alpha: 0),
                b.accent,
                b.accent.withValues(alpha: 0)
              ]))),
        ]),
      ),
      flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: b.lux ? b.deep : b.gradient),
          child: b.lux
              ? Stack(children: [
                  PositionedDirectional(
                      end: -40, top: -70, child: _Light(b.accent, 200, .22)),
                  PositionedDirectional(
                      start: 60,
                      bottom: -90,
                      child: _Light(b.stops[2], 180, .30)),
                  const SizedBox.expand(),
                ])
              : const SizedBox.expand()),
    );
  }
}

/// A card filled with the app's gradient, for headline numbers and welcome banners.
class GradientCard extends StatelessWidget {
  const GradientCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18),
      this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final b = brandOf(context);
    if (b.lux) return _luxCard(b);
    return Container(
      decoration: BoxDecoration(
        gradient: b.gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: b.accent.withValues(alpha: .38), width: 1),
        boxShadow: [
          BoxShadow(
              color: b.dark.withValues(alpha: .25),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Stack(children: [
            PositionedDirectional(
              end: -30,
              top: -40,
              child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .07))),
            ),
            PositionedDirectional(
              start: -20,
              bottom: -50,
              child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: b.accent.withValues(alpha: .12))),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0, .45, .55, 1],
                      colors: [
                        Colors.white.withValues(alpha: .10),
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0),
                        b.accent.withValues(alpha: .10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
                padding: padding,
                child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Colors.white),
                    child: IconTheme.merge(
                        data: const IconThemeData(color: Colors.white),
                        child: child))),
          ]),
        ),
      ),
    );
  }
}

extension on GradientCard {
  // Deluxe card: velvet gradient inside a gold gradient rim, soft gold and
  // rose lights, a gold hairline along the top and a deep shadow.
  Widget _luxCard(Brand b) => Container(
        padding: const EdgeInsets.all(1.3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                b.gold[0],
                b.accent.withValues(alpha: .25),
                b.gold[1].withValues(alpha: .7),
              ]),
          boxShadow: [
            BoxShadow(
                color: b.dark.withValues(alpha: .38),
                blurRadius: 26,
                offset: const Offset(0, 12)),
            BoxShadow(
                color: b.accent.withValues(alpha: .12),
                blurRadius: 30,
                spreadRadius: -6),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: b.deep),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Stack(children: [
                  PositionedDirectional(
                      end: -70, top: -90, child: _Light(b.accent, 260, .26)),
                  PositionedDirectional(
                      start: -60,
                      bottom: -110,
                      child: _Light(b.stops[2], 260, .45)),
                  Positioned(
                    top: 0,
                    left: 30,
                    right: 30,
                    child: Container(
                        height: 1.2,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                          b.accent.withValues(alpha: 0),
                          b.gold[0],
                          b.accent.withValues(alpha: 0),
                        ]))),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: const [0, .35, .5, 1],
                            colors: [
                              Colors.white.withValues(alpha: .09),
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0),
                              Colors.black.withValues(alpha: .12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                      padding: padding,
                      child: DefaultTextStyle.merge(
                          style: const TextStyle(color: Colors.white),
                          child: IconTheme.merge(
                              data: const IconThemeData(color: Colors.white),
                              child: child))),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// A soft radial pool of light.
class _Light extends StatelessWidget {
  const _Light(this.color, this.size, this.alpha);
  final Color color;
  final double size, alpha;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                color.withValues(alpha: alpha),
                color.withValues(alpha: 0)
              ])),
        ),
      );
}

/// Warm ivory backdrop with faint wine and gold lights, behind deluxe pages.
class LuxBackdrop extends StatelessWidget {
  const LuxBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final b = brandOf(context);
    if (!b.lux) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              b.surface,
              Color.lerp(b.surface, b.accent, .10)!,
              Color.lerp(b.surface, b.stops[2], .06)!,
            ]),
      ),
      child: Stack(children: [
        PositionedDirectional(
            top: 120, end: -140, child: _Light(b.accent, 360, .22)),
        PositionedDirectional(
            top: 520,
            start: -170,
            child: _Light(const Color(0xFFE0457B), 380, .14)),
        PositionedDirectional(
            bottom: -60,
            end: -120,
            child: _Light(const Color(0xFF7B4FE0), 360, .12)),
        Positioned.fill(child: child),
      ]),
    );
  }
}

/// A welcome banner at the top of an app's first screen.
class BrandBanner extends StatelessWidget {
  const BrandBanner({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return GradientCard(
      child: Row(children: [
        const AppLogo(size: 54),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(subtitle,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .8), fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

/// The open app's identity, read through the theme so the widget repaints when the app changes.
Brand brandOf(BuildContext context) {
  Theme.of(context);
  final scope = context.dependOnInheritedWidgetOfExactType<BrandScope>();
  return scope?.brand ?? activeBrand.value;
}

/// Gives a subtree its own gradient identity (used for the sections inside التحكم الإداري).
class BrandScope extends InheritedWidget {
  const BrandScope({super.key, required this.brand, required super.child});
  final Brand brand;
  @override
  bool updateShouldNotify(BrandScope old) => old.brand != brand;
}

/// A page's opening banner: gradient, icon, title, one line of context, and a few headline numbers.
class PageHero extends StatelessWidget {
  const PageHero(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      this.stats = const [],
      this.action,
      this.logo = false});
  final IconData icon;
  final bool logo;
  final String title;
  final String subtitle;
  final List<(String, String)> stats;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final b = brandOf(context);
    return GradientCard(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 20,
        runSpacing: 14,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (logo)
              const AppLogo(size: 64)
            else
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: b.lux ? null : Colors.white.withValues(alpha: .14),
                  gradient: b.lux
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: b.gold)
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: b.accent.withValues(alpha: .7)),
                  boxShadow: b.lux
                      ? [
                          BoxShadow(
                              color: b.accent.withValues(alpha: .4),
                              blurRadius: 16)
                        ]
                      : null,
                ),
                child: Icon(icon, color: b.lux ? b.dark : b.accent, size: 26),
              ),
            const SizedBox(width: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (b.lux)
                      ShaderMask(
                        shaderCallback: (r) => LinearGradient(
                                colors: [Colors.white, b.gold[0], b.accent])
                            .createShader(r),
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      )
                    else
                      Text(title,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                    if (b.lux)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        width: 54,
                        height: 2,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(colors: b.gold)),
                      ),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ]),
            ),
          ]),
          Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (si, s) in stats.indexed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: b.lux ? null : Colors.white.withValues(alpha: .14),
                      gradient: b.lux
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                  for (final c
                                      in luxChips[si % luxChips.length])
                                    c.withValues(alpha: .85)
                                ])
                          : null,
                      boxShadow: b.lux
                          ? [
                              BoxShadow(
                                  color: luxChips[si % luxChips.length][0]
                                      .withValues(alpha: .45),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5))
                            ]
                          : null,
                      borderRadius: BorderRadius.circular(b.lux ? 16 : 14),
                      border: Border.all(
                          color: b.lux
                              ? b.accent.withValues(alpha: .45)
                              : Colors.white.withValues(alpha: .22)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.$1,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text(s.$2,
                              style: TextStyle(
                                  color: b.lux ? Colors.white : b.accent,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700)),
                        ]),
                  ),
                if (action != null) action!,
              ]),
        ],
      ),
    );
  }
}

/// Vivid gradients for the headline-number chips of the deluxe look.
const luxChips = [
  [Color(0xFFE0457B), Color(0xFFF59AB0)], // rose
  [Color(0xFFE08A1E), Color(0xFFF7C562)], // amber
  [Color(0xFF7B4FE0), Color(0xFFB69BFA)], // violet
  [Color(0xFF13A08F), Color(0xFF6EE0C4)], // teal
];

/// A light button that sits on a gradient banner.
class HeroButton extends StatelessWidget {
  const HeroButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
        style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: brandOf(context).dark),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
}

/// A small rounded square filled with a gradient, holding an icon or initial.
class GradientBadge extends StatelessWidget {
  const GradientBadge(
      {super.key, required this.colors, this.icon, this.text, this.size = 46});
  final List<Color> colors;
  final IconData? icon;
  final String? text;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .3),
          gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: colors),
          boxShadow: [
            BoxShadow(
                color: colors.first.withValues(alpha: .3),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: icon != null
            ? Icon(icon, color: Colors.white, size: size * .5)
            : Text(text ?? '',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: size * .4)),
      );
}

/// Gradient pairs per account role, so a role reads the same everywhere.
const roleIcons = {
  'admin': Icons.admin_panel_settings_outlined,
  'merchant_owner': Icons.storefront_outlined,
  'merchant_staff': Icons.badge_outlined,
  'driver': Icons.delivery_dining_outlined,
  'customer': Icons.shopping_bag_outlined,
};
const roleHints = {
  'admin': 'لوحة إدارة المنصة كاملة',
  'merchant_owner': 'متجرك وطلباته ومحفظته',
  'merchant_staff': 'طلبات المتجر حسب صلاحياتك',
  'driver': 'الطلبات المتاحة ومحفظة التوصيل',
  'customer': 'تصفح الملاحم واطلب',
};

const roleGradients = <String, List<Color>>{
  'admin': [Color(0xFF06375A), Color(0xFF4CC3F2)],
  'merchant_owner': [Color(0xFF0D6152), Color(0xFF3CC4A0)],
  'merchant_staff': [Color(0xFF136A82), Color(0xFF5CC8DA)],
  'driver': [Color(0xFF1C4790), Color(0xFF5FA6F2)],
  'customer': [Color(0xFF8E2442), Color(0xFFE07A86)],
};

/// A white card whose header is a gradient band with an icon and title.
class GradientHeaderCard extends StatelessWidget {
  const GradientHeaderCard(
      {super.key,
      required this.title,
      required this.icon,
      required this.colors,
      required this.child,
      this.subtitle,
      this.trailing});
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Color> colors;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final b = brandOf(context);
    final card = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: b.lux
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: b.accent.withValues(alpha: .35)))
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: colors)),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                  ]),
            ),
            if (trailing != null) trailing!,
          ]),
        ),
        if (b.lux)
          Container(
              height: 2,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                b.accent.withValues(alpha: .1),
                b.gold[0],
                b.accent.withValues(alpha: .1),
              ]))),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]),
    );
    if (!b.lux) return card;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: b.dark.withValues(alpha: .10),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ],
      ),
      child: card,
    );
  }
}

/// Named gradient pairs for pages that colour-code their sections.
/// The app's emblem: a gold ram on a wine roundel.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.glow = true});
  final double size;
  final bool glow;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: glow
            ? [
                BoxShadow(
                    color: const Color(0xFFE7C077).withValues(alpha: .35),
                    blurRadius: size * .35,
                    spreadRadius: 1),
                BoxShadow(
                    color: Colors.black.withValues(alpha: .25),
                    blurRadius: size * .2,
                    offset: Offset(0, size * .06)),
              ]
            : null,
      ),
      child: Image.asset('assets/brand/badge.png',
          width: size, height: size, filterQuality: FilterQuality.medium),
    );
  }
}

class G {
  static const wine = [Color(0xFF4A0B22), Color(0xFFA8355A)];
  static const bronze = [Color(0xFF5A3410), Color(0xFFC8914A)];
  static const plum = [Color(0xFF2E1440), Color(0xFF8A56A8)];
  static const midnight = [Color(0xFF0F2340), Color(0xFF4677B4)];
  static const forest = [Color(0xFF0B3B33), Color(0xFF3A9478)];
  static const rose = [Color(0xFF6B1E3A), Color(0xFFD7899E)];
  static const sky = [Color(0xFF0B6FB0), Color(0xFF47BFF0)];
  static const emerald = [Color(0xFF0D6152), Color(0xFF3CC4A0)];
  static const ruby = [Color(0xFF8E2442), Color(0xFFE07A86)];
  static const sapphire = [Color(0xFF1C4790), Color(0xFF5FA6F2)];
  static const amber = [Color(0xFF9A4A12), Color(0xFFF2A65A)];
  static const gold = [Color(0xFF8A6416), Color(0xFFE2BC64)];
  static const violet = [Color(0xFF3A2878), Color(0xFF7A5AD4)];
  static const teal = [Color(0xFF136A82), Color(0xFF5CC8DA)];
}

/// A rounded filter pill: gradient when selected, outlined otherwise. count < 0 hides the count.
class TonePill extends StatelessWidget {
  const TonePill(
      {super.key,
      required this.label,
      required this.colors,
      required this.selected,
      required this.onTap,
      this.count = -1,
      this.icon});
  final String label;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;
  final int count;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final lux = brandOf(context).lux;
    final gold = brandOf(context).accent;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected
                ? LinearGradient(
                    colors: lux
                        ? [
                            Color.lerp(colors.first, Colors.black, .3)!,
                            ...colors
                          ]
                        : colors)
                : null,
            color: selected ? null : Colors.white,
            border: Border.all(
                color: selected
                    ? (lux ? gold : Colors.transparent)
                    : (lux
                        ? gold.withValues(alpha: .45)
                        : colors.first.withValues(alpha: .3))),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: colors.first.withValues(alpha: .28),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16, color: selected ? Colors.white : colors.first),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : colors.first)),
            if (count >= 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: .25)
                        : colors.first.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(999)),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : colors.first)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Two-colour gradient derived from a single tone.
List<Color> toneOf(Color c) => [c, Color.lerp(c, Colors.white, .38)!];

/// A product photo shown whole inside a framed card: the same photo blurred and
/// tinted with the store's gradient fills the background, and the sharp photo
/// sits in the middle with a white frame and a soft shadow. With [zoom] a tap
/// opens it full screen.
class ProductPhoto extends StatelessWidget {
  const ProductPhoto(
      {super.key,
      required this.url,
      required this.colors,
      this.zoom = false,
      this.padding = 10});
  final String url;
  final List<Color> colors;
  final bool zoom;
  final double padding;

  void _open(BuildContext context) => showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (c) => GestureDetector(
          onTap: () => Navigator.pop(c),
          child: Stack(children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 16,
              end: 16,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(c),
                icon: const Icon(Icons.close),
              ),
            ),
          ]),
        ),
      );

  /// Photos whose background was removed in the editor are saved as `…-cut.png`.
  bool get _cutout => url.toLowerCase().endsWith('-cut.png');

  @override
  Widget build(BuildContext context) {
    // The photo fills the whole picture area with no frame: a normal photo
    // covers it edge to edge; a cut-out product sits on the store gradient.
    final photo = Image.network(
      url,
      fit: _cutout ? BoxFit.contain : BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (_, child, p) => p == null
          ? child
          : Center(
              child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white.withValues(alpha: .9)))),
      errorBuilder: (_, __, ___) => Center(
          child: Icon(Icons.broken_image_outlined,
              size: 44, color: Colors.white.withValues(alpha: .85))),
    );
    final body = Stack(fit: StackFit.expand, children: [
      DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [colors.last, colors.first]))),
      if (_cutout)
        PositionedDirectional(
            end: -30,
            top: -30,
            child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .10)))),
      if (_cutout)
        Padding(padding: const EdgeInsets.fromLTRB(6, 8, 6, 4), child: photo)
      else
        photo,
      if (zoom)
        PositionedDirectional(
          bottom: 10,
          end: 10,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .3),
                shape: BoxShape.circle),
            child:
                const Icon(Icons.zoom_out_map, size: 16, color: Colors.white),
          ),
        ),
    ]);
    return zoom
        ? Semantics(
            button: true,
            label: 'تكبير الصورة',
            child: GestureDetector(onTap: () => _open(context), child: body))
        : body;
  }
}
