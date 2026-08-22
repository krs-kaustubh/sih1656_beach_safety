// File: lib/features/alerts/widgets/affected_area_card.dart
// Description: Affected area widget displaying a map thumbnail schematic alongside zone title, description, and full map button trigger.

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/safety_alert.dart';

// AFFECTED AREA component with map thumbnail beside zone description.
class AffectedAreaCard extends StatelessWidget {

  const AffectedAreaCard({
    super.key,
    required this.area,
    required this.accent,
    required this.textColor,
    required this.mutedColor,
    required this.onViewFullMap,
  });

  final AffectedArea area;
  final Color accent;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onViewFullMap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.card),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: MapThumbnail(accent: accent, area: area),
            ),
            Expanded(
              flex: 4,
              child: Container(
                color: mutedColor.withValues(alpha: 0.07),
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          area.zoneName,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: Insets.xs),
                        Text(
                          area.description,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    OutlinedButton.icon(
                      onPressed: onViewFullMap,
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('View full map'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                        minimumSize: const Size(0, 34),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Stand-in for the zone map showing shoreline and tower location.
class MapThumbnail extends StatelessWidget {

  const MapThumbnail({super.key, required this.accent, required this.area});

  final Color accent;
  final AffectedArea area;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _ShorelinePainter(accent: accent)),
          Positioned(
            left: Insets.sm,
            bottom: Insets.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                '250 m',
                style: TextStyle(fontSize: 9, color: Colors.black87),
              ),
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF7A1520),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_rounded,
                      size: 11, color: Colors.white),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'Tower 3',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShorelinePainter extends CustomPainter {
  const _ShorelinePainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEDE7DC),
    );

    // Sea on the left of a diagonal shoreline.
    final sea = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.42, 0)
      ..lineTo(w * 0.20, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(sea, Paint()..color = const Color(0xFFA8C4D6));

    // The affected stretch, hugging the shoreline.
    final zone = Path()
      ..moveTo(w * 0.30, h * 0.10)
      ..lineTo(w * 0.62, h * 0.10)
      ..lineTo(w * 0.44, h * 0.92)
      ..lineTo(w * 0.14, h * 0.92)
      ..close();
    canvas.drawPath(zone, Paint()..color = accent.withValues(alpha: 0.30));
    canvas.drawPath(
      zone,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Suggestion of streets inland.
    final street = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 3;
    for (var i = 1; i <= 3; i++) {
      final y = h * (i / 4);
      canvas.drawLine(Offset(w * 0.55, y), Offset(w, y), street);
    }
  }

  @override
  bool shouldRepaint(_ShorelinePainter oldDelegate) => oldDelegate.accent != accent;
}
