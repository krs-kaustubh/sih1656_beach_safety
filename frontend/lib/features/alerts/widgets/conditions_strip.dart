import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/settings_providers.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/conditions.dart';

/// The four-across "CURRENT CONDITIONS" row on the alert detail screen.
class ConditionsStrip extends ConsumerWidget {
  const ConditionsStrip({
    super.key,
    required this.conditions,
    required this.textColor,
    required this.mutedColor,
    required this.accent,
  });

  final Conditions conditions;
  final Color textColor;
  final Color mutedColor;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(formatterProvider);
    final tide = conditions.nextTide;

    final wave = fmt.waveHeight(conditions.waveHeightMeters);
    final wind = fmt.windSpeed(
      conditions.windSpeedKph,
      direction: conditions.windDirection,
    );
    final temp = fmt.temperature(conditions.waterTempCelsius);

    final items = <_ConditionItem>[
      _ConditionItem(
        icon: Icons.waves_rounded,
        label: 'Wave Height',
        value: wave.value,
        unit: wave.unit,
      ),
      _ConditionItem(
        icon: Icons.air_rounded,
        label: 'Wind',
        value: conditions.windSpeedKph == null ? null : wind.value,
        unit: wind.unit,
      ),
      _ConditionItem(
        icon: Icons.water_rounded,
        label: 'Tide',
        value: tide?.phase.label,
        unit: tide == null ? null : fmt.clock(tide.time),
        valueColor: accent,
      ),
      _ConditionItem(
        icon: Icons.thermostat_rounded,
        label: 'Water Temp',
        value: conditions.waterTempCelsius == null ? null : temp.value,
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: _ConditionCell(
              item: items[i],
              textColor: textColor,
              mutedColor: mutedColor,
            ),
          ),
          if (i != items.length - 1)
            Container(
              width: 1,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: Insets.xs),
              color: mutedColor.withValues(alpha: 0.22),
            ),
        ],
      ],
    );
  }
}

class _ConditionItem {
  const _ConditionItem({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? unit;
  final Color? valueColor;
}

class _ConditionCell extends StatelessWidget {
  const _ConditionCell({
    required this.item,
    required this.textColor,
    required this.mutedColor,
  });

  final _ConditionItem item;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, size: 17, color: mutedColor),
            const SizedBox(width: Insets.xs + 1),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(fontSize: 10.5, color: mutedColor, height: 1.2),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.xs + 1),
        Text(
          item.value ?? '—',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: item.value == null ? mutedColor : (item.valueColor ?? textColor),
          ),
        ),
        if (item.unit != null)
          Text(
            item.unit!,
            style: TextStyle(fontSize: 10.5, color: mutedColor, height: 1.3),
          ),
      ],
    );
  }
}
