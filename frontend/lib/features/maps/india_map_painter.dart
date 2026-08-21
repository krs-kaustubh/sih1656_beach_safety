import 'package:flutter/material.dart';

import '../../core/theme/risk_theme.dart';
import '../../models/beach.dart';
import 'india_geometry.dart';
import 'map_projection.dart';

/// Draws the landmass and the beach markers.
///
/// Markers are divided by [zoom] so they keep a constant on-screen size as the
/// user zooms — a pin that grows to fill the screen is useless for picking.
class IndiaMapPainter extends CustomPainter {
  const IndiaMapPainter({
    required this.geometry,
    required this.projection,
    required this.beaches,
    required this.zoom,
    required this.selectedBeachId,
    required this.palette,
  });

  final IndiaGeometry geometry;
  final MapProjection projection;
  final List<Beach> beaches;
  final double zoom;
  final int? selectedBeachId;
  final MapPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.water);

    final land = Path();
    for (final ring in geometry.rings) {
      if (ring.isEmpty) continue;
      final first = projection.pointToCanvas(ring.first);
      land.moveTo(first.dx, first.dy);
      for (var i = 1; i < ring.length; i++) {
        final p = projection.pointToCanvas(ring[i]);
        land.lineTo(p.dx, p.dy);
      }
      land.close();
    }

    // Soft halo just outside the coast, the way printed atlases show shallows.
    canvas.drawPath(
      land,
      Paint()
        ..color = palette.shelf
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 / zoom
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 / zoom),
    );

    canvas.drawPath(land, Paint()..color = palette.land);
    canvas.drawPath(
      land,
      Paint()
        ..color = palette.coastline
        ..style = PaintingStyle.stroke
        ..strokeWidth = (0.9 / zoom).clamp(0.15, 0.9),
    );

    _paintMarkers(canvas);
  }

  void _paintMarkers(Canvas canvas) {
    final radius = 7.0 / zoom;
    final ringWidth = 2.2 / zoom;

    for (final beach in beaches) {
      final centre = projection.toCanvas(beach.longitude, beach.latitude);
      final accent = RiskTheme.accentFor(beach.riskLevel, onDark: false);
      final isSelected = beach.id == selectedBeachId;

      if (isSelected) {
        canvas.drawCircle(
          centre,
          radius * 2.1,
          Paint()..color = accent.withValues(alpha: 0.22),
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
            ..color = palette.coastline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 / zoom,
        );
      }
    }
  }

  @override
  bool shouldRepaint(IndiaMapPainter old) =>
      old.zoom != zoom ||
      old.selectedBeachId != selectedBeachId ||
      old.beaches != beaches ||
      old.projection != projection;
}

/// Colours for the map surface. Green land on white water, as in a physical
/// atlas, kept separate from the risk palettes so the map does not restyle
/// itself when the selected beach changes.
@immutable
class MapPalette {
  const MapPalette({
    required this.water,
    required this.land,
    required this.coastline,
    required this.shelf,
  });

  final Color water;
  final Color land;
  final Color coastline;

  /// The shallow-water halo hugging the coast.
  final Color shelf;

  static const light = MapPalette(
    water: Color(0xFFFAFDFE),
    land: Color(0xFF9FCF9B),
    coastline: Color(0xFF3F7D46),
    shelf: Color(0xFFD8ECEF),
  );
}
