// File: lib/features/maps/terrain_map_painter.dart
// Description: Custom painter for rendering dark-themed terrain maps including oceans, land polygons, boundaries, labels, and risk-coded beach markers.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/risk_theme.dart';
import '../../models/beach.dart';
import 'map_geometry.dart';
import 'map_projection.dart';

// Draws the terrain map: ocean, land, borders, place labels and beach markers.
class TerrainMapPainter extends CustomPainter {
  const TerrainMapPainter({
    required this.geometry,
    required this.projection,
    required this.terrain,
    required this.beaches,
    required this.zoom,
    required this.selectedBeachId,
    required this.palette,
  });

  final MapGeometry geometry;
  final MapProjection projection;

  // Pre-reprojected relief texture covering MapGeometry.region.
  final ui.Image? terrain;

  final List<Beach> beaches;
  final double zoom;
  final int? selectedBeachId;
  final TerrainPalette palette;


  @override
  void paint(Canvas canvas, Size size) {
    _paintOcean(canvas, size);

    // Country polygons run past the mapped region — China and Kazakhstan
    // carry on for thousands of kilometres — so everything geographic is
    // clipped to the region the terrain texture covers. Without this, land
    // outside the texture draws as flat colour with a visible seam.
    final region = _regionRect();
    canvas.save();
    canvas.clipRect(region);

    final land = _buildLandPath();
    _paintLand(canvas, land);
    _paintBorders(canvas);
    _paintLabels(canvas, size);

    canvas.restore();

    _paintRegionEdge(canvas, region);
    _paintMarkers(canvas);
  }

  Rect _regionRect() => Rect.fromPoints(
        projection.toCanvas(geometry.region.west, geometry.region.north),
        projection.toCanvas(geometry.region.east, geometry.region.south),
      );

  /// Softens the straight cut where the data ends, so the boundary of the
  /// mapped area reads as a fade into open water rather than a torn edge.
  void _paintRegionEdge(Canvas canvas, Rect region) {
    final fade = (26.0 / zoom).clamp(4.0, 26.0);
    final water = palette.oceanDeep;

    void band(Rect rect, Alignment from, Alignment to) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            from.withinRect(rect),
            to.withinRect(rect),
            [water, water.withValues(alpha: 0.0)],
          ),
      );
    }

    band(Rect.fromLTWH(region.left, region.top, region.width, fade),
        Alignment.topCenter, Alignment.bottomCenter);
    band(Rect.fromLTWH(region.left, region.bottom - fade, region.width, fade),
        Alignment.bottomCenter, Alignment.topCenter);
    band(Rect.fromLTWH(region.left, region.top, fade, region.height),
        Alignment.centerLeft, Alignment.centerRight);
    band(Rect.fromLTWH(region.right - fade, region.top, fade, region.height),
        Alignment.centerRight, Alignment.centerLeft);
  }

  // Layers

  void _paintOcean(Canvas canvas, Size size) {

    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [palette.oceanShallow, palette.oceanDeep],
        ),
    );
  }

  Path _buildLandPath() {
    final path = Path();
    for (final country in geometry.countries) {
      for (final ring in country.rings) {
        if (ring.isEmpty) continue;
        final first = projection.pointToCanvas(ring.first);
        path.moveTo(first.dx, first.dy);
        for (var i = 1; i < ring.length; i++) {
          final p = projection.pointToCanvas(ring[i]);
          path.lineTo(p.dx, p.dy);
        }
        path.close();
      }
    }
    return path;
  }

  void _paintLand(Canvas canvas, Path land) {
    // Shelf halo just outside the coast, as printed atlases show shallows.
    canvas.drawPath(
      land,
      Paint()
        ..color = palette.shelf
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7 / zoom
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 / zoom),
    );

    canvas.save();
    canvas.clipPath(land);

    // Flat base first: it shows through if the texture has not decoded, and
    // covers any sliver where the vector coast sits outside the texture.
    canvas.drawPath(land, Paint()..color = palette.landBase);

    final image = terrain;
    if (image != null) {
      final topLeft = projection.toCanvas(
        geometry.region.west,
        geometry.region.north,
      );
      final bottomRight = projection.toCanvas(
        geometry.region.east,
        geometry.region.south,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        Rect.fromPoints(topLeft, bottomRight),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    canvas.restore();
  }

  void _paintBorders(Canvas canvas) {
    for (final country in geometry.countries) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..color = country.isIndia ? palette.indiaBorder : palette.border
        ..strokeWidth =
            ((country.isIndia ? 1.5 : 1.0) / zoom).clamp(0.12, 1.5)
        ..strokeJoin = StrokeJoin.round;

      for (final ring in country.rings) {
        if (ring.length < 2) continue;
        final path = Path();
        final first = projection.pointToCanvas(ring.first);
        path.moveTo(first.dx, first.dy);
        for (var i = 1; i < ring.length; i++) {
          final p = projection.pointToCanvas(ring[i]);
          path.lineTo(p.dx, p.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  /// Draws place names, dropping any that would collide with one already
  /// placed.
  ///
  /// Without this the view is unreadable: 27 countries and 30 cities all want
  /// a label, and at the opening zoom their text overlaps into noise. Greedy
  /// collision testing in priority order is what real maps do — country names
  /// first, then cities by rank, and anything that cannot fit is simply not
  /// drawn until the user zooms in and space opens up.
  void _paintLabels(Canvas canvas, Size size) {
    final placed = <Rect>[];
    final viewport = Offset.zero & size;

    bool place(Rect rect) {
      if (!viewport.overlaps(rect)) return false;
      final padded = rect.inflate(2.0 / zoom);
      for (final other in placed) {
        if (other.overlaps(padded)) return false;
      }
      placed.add(padded);
      return true;
    }

    for (final country in geometry.countries) {
      if (!country.isIndia && zoom < 1.15) continue;
      final painter = _layout(
        country.name.toUpperCase(),
        TextStyle(
          color: country.isIndia
              ? palette.countryLabel
              : palette.countryLabel.withValues(alpha: 0.72),
          fontSize: (country.isIndia ? 12.0 : 10.5) / zoom,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.6 / zoom,
        ),
      );
      final at = projection.pointToCanvas(country.labelPoint);
      final origin = at - Offset(painter.width / 2, painter.height / 2);
      if (!place(origin & Size(painter.width, painter.height))) continue;
      _paintHaloed(canvas, painter, origin);
    }

    for (final city in geometry.cities) {
      if (!_cityVisibleAt(city, zoom)) continue;

      final at = projection.pointToCanvas(city.point);
      final painter = _layout(
        city.name,
        TextStyle(
          color: palette.cityLabel,
          fontSize: (city.isCapital ? 10.0 : 9.0) / zoom,
          fontWeight: city.isCapital ? FontWeight.w700 : FontWeight.w500,
        ),
      );
      final anchor = at.translate(0, -(9.0 / zoom));
      final origin = anchor - Offset(painter.width / 2, painter.height / 2);
      // The dot only earns its place if the name fits beside it; a bare dot
      // reads as clutter rather than information.
      if (!place(origin & Size(painter.width, painter.height))) continue;

      final dot = 1.8 / zoom;
      canvas.drawCircle(at, dot + 0.7 / zoom, Paint()..color = palette.cityDotHalo);
      canvas.drawCircle(at, dot, Paint()..color = palette.cityDot);
      _paintHaloed(canvas, painter, origin);
    }
  }

  /// Cities appear as the map zooms in, biggest first, so the opening view
  /// carries only the handful that orient the viewer.
  static bool _cityVisibleAt(CityLabel city, double zoom) {
    if (city.isCapital) return true;
    return switch (city.rank) {
      0 => zoom >= 1.4,
      1 => zoom >= 2.2,
      _ => zoom >= 3.2,
    };
  }

  void _paintMarkers(Canvas canvas) {
    final radius = 7.0 / zoom;
    final ringWidth = 2.4 / zoom;

    for (final beach in beaches) {
      final centre = projection.toCanvas(beach.longitude, beach.latitude);
      final accent = RiskTheme.accentFor(beach.riskLevel, onDark: true);
      final isSelected = beach.id == selectedBeachId;

      if (isSelected) {
        canvas.drawCircle(
          centre,
          radius * 2.2,
          Paint()..color = accent.withValues(alpha: 0.28),
        );
      }

      canvas.drawCircle(
        centre,
        radius + ringWidth,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(centre, radius, Paint()..color = accent);

      if (isSelected) {
        canvas.drawCircle(
          centre,
          radius + ringWidth,
          Paint()
            ..color = const Color(0xFF10222E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 / zoom,
        );
      }
    }
  }

  TextPainter _layout(String text, TextStyle style) => TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

  /// Paints text with a dark outline so labels stay readable over both
  /// snow-white peaks and dark ocean without needing a plate behind them.
  void _paintHaloed(Canvas canvas, TextPainter body, Offset origin) {
    final span = body.text as TextSpan;
    final halo = TextPainter(
      text: TextSpan(
        text: span.text,
        style: span.style!.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 / zoom
            ..color = palette.labelHalo,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    halo.paint(canvas, origin);
    body.paint(canvas, origin);
  }

  @override
  bool shouldRepaint(TerrainMapPainter old) =>
      old.zoom != zoom ||
      old.selectedBeachId != selectedBeachId ||
      old.beaches != beaches ||
      old.terrain != terrain ||
      old.projection != projection;
}

// Dark-terrain palette for physical atlas rendering.
@immutable
class TerrainPalette {

  const TerrainPalette({
    required this.oceanShallow,
    required this.oceanDeep,
    required this.shelf,
    required this.landBase,
    required this.border,
    required this.indiaBorder,
    required this.countryLabel,
    required this.cityLabel,
    required this.cityDot,
    required this.cityDotHalo,
    required this.labelHalo,
  });

  final Color oceanShallow;
  final Color oceanDeep;
  final Color shelf;
  final Color landBase;
  final Color border;
  final Color indiaBorder;
  final Color countryLabel;
  final Color cityLabel;
  final Color cityDot;
  final Color cityDotHalo;
  final Color labelHalo;

  static const dark = TerrainPalette(
    oceanShallow: Color(0xFF16344F),
    oceanDeep: Color(0xFF091A2E),
    shelf: Color(0x4438709E),
    landBase: Color(0xFF3E4A3A),
    border: Color(0x99C39BD3),
    indiaBorder: Color(0xCCE8D5F2),
    countryLabel: Color(0xFFEBDCF5),
    cityLabel: Color(0xFFF2F5F7),
    cityDot: Color(0xFFFFFFFF),
    cityDotHalo: Color(0x88101820),
    labelHalo: Color(0xCC0A1420),
  );
}
