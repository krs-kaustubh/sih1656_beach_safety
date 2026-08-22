// File: lib/widgets/backdrop_scene.dart
// Description: Custom procedural painter drawing dynamic backdrop scenes (clear day, sunset, storm) for the home screen dashboard.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/risk_level.dart';

// Paints the procedural scene behind the Home screen: clear day, sunset, or storm.
class BackdropScenePainter extends CustomPainter {
  const BackdropScenePainter({
    required this.level,
    required this.surfaceColor,
  });

  final RiskLevel level;

  // Colour the scene dissolves into behind the content.
  final Color surfaceColor;

  // Fraction of the height where sky meets water.
  static const _horizon = 0.34;

  // Where the scene has fully given way to surfaceColor.
  static const _fadeEnd = 0.60;


  @override
  void paint(Canvas canvas, Size size) {
    switch (level) {
      case RiskLevel.low:
        _paintClearDay(canvas, size);
      case RiskLevel.moderate:
        _paintSunset(canvas, size);
      case RiskLevel.high:
        _paintStorm(canvas, size);
    }
    _paintContentFade(canvas, size);
  }

  // Scenes

  void _paintClearDay(Canvas canvas, Size size) {

    final horizonY = size.height * _horizon;

    _fillRect(
      canvas,
      Rect.fromLTWH(0, 0, size.width, horizonY),
      const [Color(0xFF0A4E9E), Color(0xFF2E86C8), Color(0xFF8FCBE8)],
    );

    _sunGlow(
      canvas,
      centre: Offset(size.width * 0.82, horizonY * 0.42),
      radius: size.width * 0.30,
      core: Colors.white,
      halo: const Color(0xFFBFE4F7),
    );

    // A low skyline on the left, as in the Juhu design.
    _skyline(canvas, size, horizonY, const Color(0xFF0E3E63).withValues(alpha: 0.55));

    _fillRect(
      canvas,
      Rect.fromLTWH(0, horizonY, size.width, size.height * 0.26),
      const [Color(0xFF1E7FB8), Color(0xFF4FB3C9), Color(0xFF9AD3D8)],
    );

    _sunReflection(canvas, size, horizonY, const Color(0xFFDCF2FB), 0.82);
    _surf(canvas, size, horizonY + size.height * 0.16, Colors.white.withValues(alpha: 0.5));
  }

  void _paintSunset(Canvas canvas, Size size) {
    final horizonY = size.height * _horizon;

    _fillRect(
      canvas,
      Rect.fromLTWH(0, 0, size.width, horizonY),
      const [Color(0xFF5E3208), Color(0xFFB8660F), Color(0xFFF0A63A)],
    );

    _sunGlow(
      canvas,
      centre: Offset(size.width * 0.52, horizonY * 0.86),
      radius: size.width * 0.42,
      core: const Color(0xFFFFE6A8),
      halo: const Color(0xFFF2A63C),
    );

    // Banded cloud, the shape that gives a sunset its depth.
    _cloudBank(canvas, size, horizonY, const Color(0xFF6B3708).withValues(alpha: 0.42));

    _fillRect(
      canvas,
      Rect.fromLTWH(0, horizonY, size.width, size.height * 0.26),
      const [Color(0xFFB9701A), Color(0xFFE0A044), Color(0xFFF3CE8C)],
    );

    _sunReflection(canvas, size, horizonY, const Color(0xFFFFE2A6), 0.52);
    _surf(canvas, size, horizonY + size.height * 0.16,
        const Color(0xFFFFF0D0).withValues(alpha: 0.55));
  }

  void _paintStorm(Canvas canvas, Size size) {
    final horizonY = size.height * _horizon;

    _fillRect(
      canvas,
      Rect.fromLTWH(0, 0, size.width, horizonY),
      const [Color(0xFF140A0D), Color(0xFF4A1119), Color(0xFF7A1D26)],
    );

    // Heavy cloud mass lit from within.
    _cloudBank(canvas, size, horizonY, const Color(0xFF0C0508).withValues(alpha: 0.62));
    _sunGlow(
      canvas,
      centre: Offset(size.width * 0.66, horizonY * 0.52),
      radius: size.width * 0.34,
      core: const Color(0xFFE8737C).withValues(alpha: 0.55),
      halo: const Color(0xFF8E1420).withValues(alpha: 0.30),
    );

    _lightning(canvas, size, horizonY);

    _fillRect(
      canvas,
      Rect.fromLTWH(0, horizonY, size.width, size.height * 0.26),
      const [Color(0xFF3A1218), Color(0xFF230E12), Color(0xFF15080B)],
    );

    _surf(canvas, size, horizonY + size.height * 0.14,
        const Color(0xFFD98A92).withValues(alpha: 0.34));
  }

  // Building blocks

  void _fillRect(Canvas canvas, Rect rect, List<Color> colors) {

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          colors,
          _evenStops(colors.length),
        ),
    );
  }

  static List<double> _evenStops(int count) =>
      List.generate(count, (i) => i / (count - 1));

  void _sunGlow(
    Canvas canvas, {
    required Offset centre,
    required double radius,
    required Color core,
    required Color halo,
  }) {
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(centre, radius, [
          core,
          halo.withValues(alpha: 0.45),
          halo.withValues(alpha: 0.0),
        ], const [0.0, 0.35, 1.0]),
    );
  }

  /// Elongated ellipses read as cloud at this scale and cost almost nothing.
  void _cloudBank(Canvas canvas, Size size, double horizonY, Color color) {
    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.045);

    const spots = [
      Offset(0.16, 0.30), Offset(0.44, 0.16), Offset(0.72, 0.34),
      Offset(0.92, 0.14), Offset(0.30, 0.62), Offset(0.66, 0.68),
    ];
    for (final spot in spots) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * spot.dx, horizonY * spot.dy),
          width: size.width * 0.52,
          height: horizonY * 0.30,
        ),
        paint,
      );
    }
  }

  void _skyline(Canvas canvas, Size size, double horizonY, Color color) {
    final paint = Paint()..color = color;
    final rand = math.Random(7); // Fixed seed: the skyline must not flicker.
    var x = 0.0;
    while (x < size.width * 0.46) {
      final w = size.width * (0.03 + rand.nextDouble() * 0.035);
      final h = horizonY * (0.10 + rand.nextDouble() * 0.20);
      canvas.drawRect(Rect.fromLTWH(x, horizonY - h, w, h), paint);
      x += w + size.width * 0.008;
    }
  }

  /// Bright column under the sun, broken into ripples.
  void _sunReflection(
    Canvas canvas, Size size, double horizonY, Color color, double centreX) {
    final rand = math.Random(11);
    for (var i = 0; i < 16; i++) {
      final t = i / 15;
      final y = horizonY + size.height * 0.26 * t;
      final width = size.width * (0.06 + t * 0.22) * (0.6 + rand.nextDouble() * 0.7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * centreX, y),
            width: width,
            height: size.height * 0.006,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = color.withValues(alpha: 0.42 * (1 - t)),
      );
    }
  }

  /// The foam line where water meets sand.
  void _surf(Canvas canvas, Size size, double y, Color color) {
    final path = Path()..moveTo(0, y);
    for (var x = 0.0; x <= size.width; x += size.width / 12) {
      path.quadraticBezierTo(
        x + size.width / 24, y - size.height * 0.008,
        x + size.width / 12, y,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.006
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.004),
    );
  }

  void _lightning(Canvas canvas, Size size, double horizonY) {
    final start = Offset(size.width * 0.74, horizonY * 0.08);
    final path = Path()..moveTo(start.dx, start.dy);
    const zigzag = [
      Offset(-0.055, 0.30), Offset(0.030, 0.34), Offset(-0.075, 0.62),
      Offset(0.020, 0.68), Offset(-0.045, 1.00),
    ];
    for (final step in zigzag) {
      path.lineTo(
        start.dx + size.width * step.dx,
        start.dy + (horizonY - start.dy) * step.dy,
      );
    }

    // Glow first, then the hot core on top of it.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF8A94).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.020
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.022),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFE9EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.005
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Dissolves the scene into the page colour so cards stay readable.
  void _paintContentFade(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      0,
      size.height * _horizon,
      size.width,
      size.height * (1 - _horizon),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [
            surfaceColor.withValues(alpha: 0.0),
            surfaceColor.withValues(alpha: 0.88),
            surfaceColor,
          ],
          [0.0, (_fadeEnd - _horizon) / (1 - _horizon), 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(BackdropScenePainter oldDelegate) =>
      oldDelegate.level != level || oldDelegate.surfaceColor != surfaceColor;
}
