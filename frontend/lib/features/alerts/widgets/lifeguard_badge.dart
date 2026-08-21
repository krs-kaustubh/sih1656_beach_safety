import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/safety_alert.dart';

/// Shield, tower name and duty state, shown beside the risk meter.
class LifeguardBadge extends StatelessWidget {
  const LifeguardBadge({
    super.key,
    required this.status,
    required this.accent,
    required this.textColor,
  });

  final LifeguardStatus status;
  final Color accent;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          status.onDuty ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
          color: accent,
          size: 26,
        ),
        const SizedBox(width: Insets.sm),
        // Flexible, not fixed: "Tower 3" is short but a real tower name can be
        // long, and this badge sits in a half-width column.
        Flexible(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status.towerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              status.statusLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            ],
          ),
        ),
      ],
    );
  }
}
