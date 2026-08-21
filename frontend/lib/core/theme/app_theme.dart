import 'package:flutter/material.dart';

/// Consistent spacing scale used across the app.
abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
}

/// Corner radii matching the designs.
abstract final class Radii {
  static const double card = 16;
  static const double banner = 20;
  static const double field = 14;
  static const double chip = 8;
  static const double panel = 24;
}

/// Base Material theme. Per-screen colour comes from `RiskTheme`; this only
/// sets typography and platform-wide defaults.
ThemeData buildAppTheme() {
  const seed = Color(0xFF1565C0);
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
  );

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFF0B1A24),
    textTheme: base.textTheme.apply(fontFamily: 'Inter'),
    splashFactory: InkSparkle.splashFactory,
  );
}

/// Text styles named after their role in the designs rather than by size, so
/// call sites read as intent.
abstract final class AppText {
  static const beachTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.1,
  );

  static const beachRegion = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );

  static const bannerTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const bannerBody = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static const metricLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const metricValue = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const metricUnit = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const sectionHeader = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Small all-caps labels: "RISK LEVEL", "CURRENT CONDITIONS".
  static const overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
  );

  static const alertTitle = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
  );

  static const alertMeta = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  static const detailTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.15,
  );

  static const body = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );
}
