// File: lib/features/home/widgets/conditions_grid.dart
// Description: Grid layout widget organizing metric cards for wave height, wind speed, UV index, and upcoming tide timings.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/settings_providers.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/risk_theme.dart';
import '../../../models/conditions.dart';
import 'metric_card.dart';

// The 2x2 grid of readings under the risk banner.
class ConditionsGrid extends ConsumerWidget {
  const ConditionsGrid({super.key, required this.conditions});

  final Conditions conditions;

  // UV is the one reading coloured by severity.
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
  Widget build(BuildContext context, WidgetRef ref) {
    final risk = RiskTheme.of(context);
    final fmt = ref.watch(formatterProvider);
    final tide = conditions.nextTide;
    final uv = conditions.uvIndex;

    final wave = fmt.waveHeight(conditions.waveHeightMeters);
    final wind = fmt.windSpeed(
      conditions.windSpeedKph,
      direction: conditions.windDirection,
    );

    final cards = <Widget>[
      MetricCard(
        icon: Icons.waves_rounded,
        label: 'Wave Height',
        value: wave.value,
        unit: wave.unit,
      ),
      MetricCard(
        icon: Icons.air_rounded,
        label: 'Wind',
        value: conditions.windSpeedKph == null ? null : wind.value,
        unit: wind.unit,
      ),
      MetricCard(
        icon: Icons.wb_sunny_outlined,
        label: 'UV Index',
        value: uv == null ? null : fmt.uv(uv),
        unit: conditions.uvLabel,
        valueColor: _uvColor(risk, conditions.uvBand),
        iconColor: _uvColor(risk, conditions.uvBand),
      ),
      MetricCard(
        icon: Icons.water_rounded,
        label: 'Next Tide',
        value: tide == null ? null : fmt.clock(tide.time),
        unit: tide?.phase.label,
      ),
    ];

    return Column(
      children: [
        _EqualHeightRow(left: cards[0], right: cards[1]),
        const SizedBox(height: Insets.md),
        _EqualHeightRow(left: cards[2], right: cards[3]),
      ],
    );
  }
}

// A pair of cards that share the taller one's height.
class _EqualHeightRow extends StatelessWidget {

  const _EqualHeightRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: Insets.md),
          Expanded(child: right),
        ],
      ),
    );
  }
}
