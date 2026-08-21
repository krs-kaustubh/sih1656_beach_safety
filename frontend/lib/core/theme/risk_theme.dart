import 'package:flutter/material.dart';

import '../../models/risk_level.dart';

/// The complete colour set for one risk level.
///
/// In the designs each risk level is not just an accent colour — it restyles
/// the whole screen, including whether surfaces are light or dark. Grouping it
/// into one object means a widget only ever reads `RiskTheme.of(context)`
/// instead of branching on [RiskLevel] in a dozen places.
@immutable
class RiskTheme {
  const RiskTheme({
    required this.level,
    required this.backdrop,
    required this.bannerGradient,
    required this.bannerForeground,
    required this.bannerIconBackground,
    required this.surface,
    required this.surfaceBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.metricIcon,
    required this.headerForeground,
    required this.contentForeground,
    required this.backdropAsset,
    required this.detailHeader,
    required this.detailBackdrop,
    required this.detailSurface,
    required this.isDark,
  });

  final RiskLevel level;

  /// Vertical gradient standing in for the photographic backdrop.
  final List<Color> backdrop;

  final List<Color> bannerGradient;
  final Color bannerForeground;
  final Color bannerIconBackground;

  /// Metric cards, alert cards, panels.
  final Color surface;
  final Color surfaceBorder;

  final Color textPrimary;
  final Color textSecondary;

  /// Highlight colour: UV readout, active nav item, section accents.
  final Color accent;

  final Color metricIcon;

  /// Text drawn over the *top* of [backdrop], which is dark on every scene.
  final Color headerForeground;

  /// Text drawn further down the page, where the light scenes have faded to a
  /// pale surface and [headerForeground] would be nearly invisible.
  final Color contentForeground;

  /// Photograph behind Home for this risk level. `BackdropScenePainter` draws
  /// the equivalent scene if the asset cannot be loaded.
  final String backdropAsset;

  /// Solid header block at the top of the alert detail screen.
  final Color detailHeader;

  /// Page background behind the detail panel.
  final Color detailBackdrop;

  /// The panel holding the detail body.
  final Color detailSurface;

  final bool isDark;

  Color get onBackdropMuted => headerForeground.withValues(alpha: 0.72);

  static const RiskTheme _low = RiskTheme(
    level: RiskLevel.low,
    backdrop: [Color(0xFF0B5AAE), Color(0xFF3E9BD6), Color(0xFFBFD9DD), Color(0xFFEDE7DC)],
    bannerGradient: [Color(0xFF3AA76D), Color(0xFF12796F)],
    bannerForeground: Colors.white,
    bannerIconBackground: Color(0x33FFFFFF),
    surface: Color(0xFFF7F5F0),
    surfaceBorder: Color(0x14000000),
    textPrimary: Color(0xFF15242E),
    textSecondary: Color(0xFF5B6B77),
    accent: Color(0xFF1B7F4F),
    metricIcon: Color(0xFF1E5A8A),
    headerForeground: Colors.white,
    contentForeground: Color(0xFF15242E),
    backdropAsset: 'assets/backdrops/low.jpg',
    detailHeader: Color(0xFF0E4F4A),
    detailBackdrop: Color(0xFF07242B),
    detailSurface: Color(0xFFFFFFFF),
    isDark: false,
  );

  static const RiskTheme _moderate = RiskTheme(
    level: RiskLevel.moderate,
    backdrop: [Color(0xFF6E3F0C), Color(0xFFC97B18), Color(0xFFF0B860), Color(0xFFFBEBD2)],
    bannerGradient: [Color(0xFFF7AC24), Color(0xFFE8901A)],
    bannerForeground: Color(0xFF3D2400),
    bannerIconBackground: Color(0x33000000),
    surface: Color(0xFFFDF7EA),
    surfaceBorder: Color(0x14000000),
    textPrimary: Color(0xFF2B1A05),
    textSecondary: Color(0xFF7A6242),
    accent: Color(0xFFC9720C),
    metricIcon: Color(0xFF23557F),
    headerForeground: Colors.white,
    contentForeground: Color(0xFF2B1A05),
    backdropAsset: 'assets/backdrops/moderate.jpg',
    detailHeader: Color(0xFFE08A0B),
    detailBackdrop: Color(0xFF3A2405),
    detailSurface: Color(0xFFFFFAF1),
    isDark: false,
  );

  static const RiskTheme _high = RiskTheme(
    level: RiskLevel.high,
    backdrop: [Color(0xFF1A0C10), Color(0xFF5A1620), Color(0xFF2A1015), Color(0xFF0B0709)],
    bannerGradient: [Color(0xFFB3202B), Color(0xFF7E1119)],
    bannerForeground: Colors.white,
    bannerIconBackground: Color(0x33FFFFFF),
    surface: Color(0xFF1F1A1C),
    surfaceBorder: Color(0x1FFFFFFF),
    textPrimary: Color(0xFFF5EEEF),
    textSecondary: Color(0xFFB0A2A5),
    accent: Color(0xFFE5484D),
    metricIcon: Color(0xFFD8CFD1),
    headerForeground: Colors.white,
    contentForeground: Colors.white,
    backdropAsset: 'assets/backdrops/high.jpg',
    detailHeader: Color(0xFF8E1420),
    detailBackdrop: Color(0xFF120A0C),
    detailSurface: Color(0xFF1A1113),
    isDark: true,
  );

  /// Severity colour for a single item (an alert row, a meter dot) shown on a
  /// screen whose own theme may be a different risk level — a Moderate alert
  /// listed on a High-risk Home screen still needs to read as amber.
  ///
  /// [onDark] lightens the colours so they keep contrast on dark surfaces.
  static Color accentFor(RiskLevel level, {required bool onDark}) =>
      switch ((level, onDark)) {
        (RiskLevel.low, false) => const Color(0xFF1B7F4F),
        (RiskLevel.low, true) => const Color(0xFF3DD68C),
        (RiskLevel.moderate, false) => const Color(0xFFE08A0B),
        (RiskLevel.moderate, true) => const Color(0xFFF5A524),
        (RiskLevel.high, false) => const Color(0xFFC02A30),
        (RiskLevel.high, true) => const Color(0xFFE5484D),
      };

  /// Light counterpart of this palette, used where the screen sits on a tinted
  /// gradient rather than a photograph.
  ///
  /// The Alerts tab needs the severity to read at a glance without a
  /// photographic backdrop competing with it, which means light surfaces and
  /// dark text even at high risk. Keeping it as a variant of the same object
  /// means the shared alert widgets need no changes — they still just read
  /// `RiskTheme.of(context)`.
  RiskTheme get lightVariant => switch (level) {
        RiskLevel.low => _lowLight,
        RiskLevel.moderate => _moderateLight,
        RiskLevel.high => _highLight,
      };

  static const RiskTheme _lowLight = RiskTheme(
    level: RiskLevel.low,
    backdrop: [Color(0xFFD8F0DE), Color(0xFFEAF7ED), Color(0xFFF6FBF7), Color(0xFFFFFFFF)],
    bannerGradient: [Color(0xFF3AA76D), Color(0xFF12796F)],
    bannerForeground: Colors.white,
    bannerIconBackground: Color(0x33FFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0x14000000),
    textPrimary: Color(0xFF14261C),
    textSecondary: Color(0xFF5A6B60),
    accent: Color(0xFF1B7F4F),
    metricIcon: Color(0xFF1E5A8A),
    headerForeground: Color(0xFF10301F),
    contentForeground: Color(0xFF10301F),
    backdropAsset: 'assets/backdrops/low.jpg',
    detailHeader: Color(0xFF0E4F4A),
    detailBackdrop: Color(0xFF07242B),
    detailSurface: Color(0xFFFFFFFF),
    isDark: false,
  );

  static const RiskTheme _moderateLight = RiskTheme(
    level: RiskLevel.moderate,
    backdrop: [Color(0xFFFCE7C6), Color(0xFFFDF2DF), Color(0xFFFEF9F0), Color(0xFFFFFFFF)],
    bannerGradient: [Color(0xFFF7AC24), Color(0xFFE8901A)],
    bannerForeground: Color(0xFF3D2400),
    bannerIconBackground: Color(0x33000000),
    surface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0x14000000),
    textPrimary: Color(0xFF2B1E08),
    textSecondary: Color(0xFF6F5C3E),
    accent: Color(0xFFC9720C),
    metricIcon: Color(0xFF23557F),
    headerForeground: Color(0xFF4A3208),
    contentForeground: Color(0xFF4A3208),
    backdropAsset: 'assets/backdrops/moderate.jpg',
    detailHeader: Color(0xFFE08A0B),
    detailBackdrop: Color(0xFF3A2405),
    detailSurface: Color(0xFFFFFAF1),
    isDark: false,
  );

  static const RiskTheme _highLight = RiskTheme(
    level: RiskLevel.high,
    backdrop: [Color(0xFFF9D8D8), Color(0xFFFCE8E8), Color(0xFFFEF4F4), Color(0xFFFFFFFF)],
    bannerGradient: [Color(0xFFB3202B), Color(0xFF7E1119)],
    bannerForeground: Colors.white,
    bannerIconBackground: Color(0x33FFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0x14000000),
    textPrimary: Color(0xFF2A1416),
    textSecondary: Color(0xFF6E585A),
    accent: Color(0xFFC02A30),
    metricIcon: Color(0xFF8A4045),
    headerForeground: Color(0xFF4A1114),
    contentForeground: Color(0xFF4A1114),
    backdropAsset: 'assets/backdrops/high.jpg',
    detailHeader: Color(0xFF8E1420),
    detailBackdrop: Color(0xFF120A0C),
    detailSurface: Color(0xFF1A1113),
    // Light, despite the risk level: isDark describes the surfaces, and
    // everything downstream picks contrast from it. Marking this dark would
    // hand white alert cards the light-on-dark red meant for the storm screen.
    isDark: false,
  );

  static RiskTheme forLevel(RiskLevel level) => switch (level) {
        RiskLevel.low => _low,
        RiskLevel.moderate => _moderate,
        RiskLevel.high => _high,
      };

  /// Reads the risk theme provided by the nearest [RiskThemeScope].
  ///
  /// Defaults to the low-risk palette when no scope is present, which keeps
  /// widget tests and previews from having to build a full screen.
  static RiskTheme of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RiskThemeScope>();
    return scope?.theme ?? _low;
  }
}

/// Makes a [RiskTheme] available to the subtree.
class RiskThemeScope extends InheritedWidget {
  const RiskThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  final RiskTheme theme;

  @override
  bool updateShouldNotify(RiskThemeScope oldWidget) => oldWidget.theme != theme;
}
