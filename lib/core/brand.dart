import 'package:flutter/material.dart';

/// Each app (customer, merchant, staff, driver, admin) has its own visual identity:
/// a three-stop gradient, a metallic accent, and a softly tinted surface.
class Brand {
  const Brand(
      {required this.name,
      required this.tagline,
      required this.icon,
      required this.stops,
      required this.accent,
      required this.surface});
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
    name: 'ذبائح البحرين',
    tagline: 'ذبيحتك من المسلخ إلى باب بيتك',
    icon: Icons.storefront,
    stops: [Color(0xFF2A0A16), Color(0xFF6E1630), Color(0xFFB0414F)],
    accent: Color(0xFFE2B866),
    surface: Color(0xFFFBF6F2),
  ),
  'customer': Brand(
    name: 'ذبائح البحرين',
    tagline: 'اطلب ذبيحتك بسهولة',
    icon: Icons.shopping_bag_outlined,
    stops: [Color(0xFF4A0D25), Color(0xFF8E2442), Color(0xFFD0646B)],
    accent: Color(0xFFE2B866),
    surface: Color(0xFFFCF7F4),
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
      {super.key, this.title, this.actions, this.bottom, this.leading});
  final Widget? title;
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
      title: title == null
          ? null
          : DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white), child: title!),
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
          decoration: BoxDecoration(gradient: b.gradient),
          child: const SizedBox.expand()),
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
    return Container(
      decoration: BoxDecoration(
        gradient: b.gradient,
        borderRadius: BorderRadius.circular(20),
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

/// A welcome banner at the top of an app's first screen.
class BrandBanner extends StatelessWidget {
  const BrandBanner({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final b = brandOf(context);
    return GradientCard(
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: b.accent.withValues(alpha: .6))),
          child: Icon(b.icon, color: b.accent),
        ),
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
  return activeBrand.value;
}

/// A page's opening banner: gradient, icon, title, one line of context, and a few headline numbers.
class PageHero extends StatelessWidget {
  const PageHero(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      this.stats = const [],
      this.action});
  final IconData icon;
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
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: b.accent.withValues(alpha: .7)),
              ),
              child: Icon(icon, color: b.accent, size: 26),
            ),
            const SizedBox(width: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700)),
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
                for (final s in stats)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: .22)),
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
                                  color: b.accent,
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
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
          Padding(padding: const EdgeInsets.all(16), child: child),
        ]),
      );
}

/// Named gradient pairs for pages that colour-code their sections.
class G {
  static const sky = [Color(0xFF0B6FB0), Color(0xFF47BFF0)];
  static const emerald = [Color(0xFF0D6152), Color(0xFF3CC4A0)];
  static const ruby = [Color(0xFF8E2442), Color(0xFFE07A86)];
  static const sapphire = [Color(0xFF1C4790), Color(0xFF5FA6F2)];
  static const amber = [Color(0xFF9A4A12), Color(0xFFF2A65A)];
  static const gold = [Color(0xFF8C6A12), Color(0xFFD4AF37)];
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: selected ? LinearGradient(colors: colors) : null,
              color: selected ? null : Colors.white,
              border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : colors.first.withValues(alpha: .3)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
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

/// Two-colour gradient derived from a single tone.
List<Color> toneOf(Color c) => [c, Color.lerp(c, Colors.white, .38)!];
