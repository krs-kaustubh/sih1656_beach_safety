import 'package:flutter/material.dart';

import '../../../core/formatting.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/risk_theme.dart';
import '../../../models/conditions.dart';
import 'metric_card.dart';

/// The 2x2 grid of readings under the risk banner.
class ConditionsGrid extends StatelessWidget {
  const ConditionsGrid({super.key, required this.conditions});

  final Conditions conditions;

  /// UV is the one reading the designs colour by severity, since a high index
  /// is itself the warning.
  Color _uvColor(RiskTheme risk, UvBand? band) => switch (band) {
        null => risk.textSecondary,
        UvBand.low => const Color(0xFF1B7F4F),
        UvBand.moderate => const Color(0xFFB8860B),
        UvBand.high => const Color(0xFFD97706),
        UvBand.veryHigh || UvBand.extreme => risk.isDark
            ? const Color(0xFFE5484D)
            : const Color(0xFFC02A30),
      };

  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);
    final tide = conditions.nextTide;
    final uv = conditions.uvIndex;

    final cards = <Widget>[
      MetricCard(
        icon: Icons.waves_rounded,
        label: 'Wave Height',
        value: Fmt.number(conditions.waveHeightMeters),
        unit: 'm',
      ),
      MetricCard(
        icon: Icons.air_rounded,
        label: 'Wind',
        value: conditions.windSpeedKph == null
            ? null
            : Fmt.number(conditions.windSpeedKph!, decimals: 0),
        unit: [
          'km/h',
          if (conditions.windDirection != null) conditions.windDirection!,
        ].join(' '),
      ),
      MetricCard(
        icon: Icons.wb_sunny_outlined,
        label: 'UV Index',
        value: uv == null ? null : Fmt.uv(uv),
        unit: conditions.uvBand?.label,
        valueColor: _uvColor(risk, conditions.uvBand),
        iconColor: _uvColor(risk, conditions.uvBand),
      ),
      MetricCard(
        icon: Icons.water_rounded,
        label: 'Next Tide',
        value: tide == null ? null : Fmt.tideClock(tide.time),
        unit: tide?.phase.label,
      ),
    ];

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: Insets.md),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: Insets.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: Insets.md),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }
}
