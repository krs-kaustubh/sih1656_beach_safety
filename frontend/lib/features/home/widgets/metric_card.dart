import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/risk_theme.dart';
import '../../../widgets/surface_card.dart';

/// One reading in the conditions grid: icon, label, value and unit.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;

  /// Already-formatted reading, or null when it is unavailable.
  final String? value;

  /// Trailing qualifier: "m", "km/h SW", "Low", "Extreme".
  final String? unit;

  /// Overrides the value colour — the designs tint the UV readout by band.
  final Color? valueColor;

  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);
    final hasValue = value != null;

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.md + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: iconColor ?? risk.metricIcon),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppText.metricLabel.copyWith(color: risk.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Insets.xs),
                // Baseline-aligned so the small unit sits on the value's
                // baseline instead of floating at its vertical centre.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        hasValue ? value! : '—',
                        style: AppText.metricValue.copyWith(
                          color: hasValue
                              ? (valueColor ?? risk.textPrimary)
                              : risk.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasValue && unit != null) ...[
                      const SizedBox(width: Insets.xs + 1),
                      Flexible(
                        child: Text(
                          unit!,
                          style: AppText.metricUnit.copyWith(
                            color: valueColor ?? risk.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
