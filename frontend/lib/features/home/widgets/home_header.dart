import 'package:flutter/material.dart';

import '../../../core/formatting.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/risk_theme.dart';
import '../../../models/beach.dart';

/// Beach name, region and the current-time pill.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.beach, required this.time});

  final Beach beach;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                beach.name,
                style: AppText.beachTitle.copyWith(color: risk.headerForeground),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                beach.region,
                style: AppText.beachRegion.copyWith(color: risk.onBackdropMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: Insets.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: Text(
            Fmt.clock(time),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: risk.headerForeground,
            ),
          ),
        ),
      ],
    );
  }
}
