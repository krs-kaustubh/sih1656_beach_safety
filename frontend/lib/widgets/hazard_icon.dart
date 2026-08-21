import 'package:flutter/material.dart';

import '../models/safety_alert.dart';

/// Maps an [AlertKind] to its glyph, keeping icon choice in one place so Home
/// cards and the detail header cannot drift apart.
IconData iconForAlertKind(AlertKind kind) => switch (kind) {
      AlertKind.ripCurrent => Icons.flag_rounded,
      AlertKind.uv => Icons.wb_sunny_outlined,
      AlertKind.wind => Icons.air_rounded,
      AlertKind.waterQuality => Icons.water_drop_outlined,
      AlertKind.general => Icons.info_outline_rounded,
    };

/// A glyph inside a tinted circle, as used on the alert cards.
class HazardIcon extends StatelessWidget {
  const HazardIcon({
    super.key,
    required this.kind,
    required this.color,
    this.size = 36,
  });

  final AlertKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(iconForAlertKind(kind), size: size * 0.52, color: color),
    );
  }
}
