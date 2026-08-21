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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
