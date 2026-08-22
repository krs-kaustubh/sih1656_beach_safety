import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/risk_theme.dart';
import '../../../models/beach.dart';
import '../../../models/risk_level.dart';

/// The headline risk card: flag badge, "Low Risk", and a plain-language
/// explanation of what the rating means for someone standing on the sand.
class RiskBanner extends StatelessWidget {
  const RiskBanner({super.key, required this.beach});

  final Beach beach;

  /// Used when the backend has not supplied a `risk_summary`, so the banner is
  /// never left with an empty body.
  static String _fallbackSummary(RiskLevel level) => switch (level) {
        RiskLevel.low => 'Conditions are safe for swimming and other water activities.',
        RiskLevel.moderate =>
          'Take care in the water. Conditions can change quickly.',
        RiskLevel.high =>
          'Dangerous conditions. Strong currents and high waves. Avoid entering water.',
      };

  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);
    final summary =
        beach.riskSummary.isNotEmpty ? beach.riskSummary : _fallbackSummary(beach.riskLevel);

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.banner),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: risk.bannerGradient,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: risk.bannerIconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.flag_rounded, color: risk.bannerForeground, size: 26),
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  beach.riskLevel.label,
                  style: AppText.bannerTitle.copyWith(color: risk.bannerForeground),
                ),
                const SizedBox(height: Insets.xs + 2),
                Text(
                  summary,
                  style: AppText.bannerBody.copyWith(
                    color: risk.bannerForeground.withValues(alpha: 0.92),
                  ),
                ),
                if (beach.riskDrivers.isNotEmpty) ...[
                  const SizedBox(height: Insets.md),
                  _RiskDrivers(
                    drivers: beach.riskDrivers,
                    foreground: risk.bannerForeground,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Names the measurements that pushed the rating up.
///
/// A colour and a sentence say *what* the rating is; these say *why*, which is
/// the difference between being told a verdict and being able to check it.
class _RiskDrivers extends StatelessWidget {
  const _RiskDrivers({required this.drivers, required this.foreground});

  final List<String> drivers;
  final Color foreground;

  /// The service names these in snake_case; these are the human labels.
  static const _labels = <String, String>{
    'wave_height': 'Wave height',
    'wind_speed': 'Wind speed',
    'swell': 'Swell',
    'uv_index': 'UV index',
    'water_quality': 'Water quality',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.xs + 2,
      children: [
        for (final driver in drivers)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.sm + 2,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(Radii.chip),
              border: Border.all(color: foreground.withValues(alpha: 0.28)),
            ),
            child: Text(
              // An unrecognised key is still worth showing, tidied up, rather
              // than dropped — the service may add measurements we predate.
              _labels[driver] ?? driver.replaceAll('_', ' '),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: foreground.withValues(alpha: 0.95),
              ),
            ),
          ),
      ],
    );
  }
}
