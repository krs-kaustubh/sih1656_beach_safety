// File: lib/features/alerts/widgets/risk_meter.dart
// Description: Risk meter track component visualizing Low-Moderate-Severe risk levels with segmented dots and label indicators.

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/risk_level.dart';

// Low - Moderate - Severe track component on the alert detail screen.
class RiskMeter extends StatelessWidget {

  const RiskMeter({
    super.key,
    required this.level,
    required this.accent,
    required this.trackColor,
    required this.labelColor,
  });

  final RiskLevel level;
  final Color accent;
  final Color trackColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    const levels = RiskLevel.values;
    final activeIndex = levels.indexOf(level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 14,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              const dot = 11.0;
              // Dots sit at the centre of each third so they line up with the

              final segment = width / levels.length;
              double centreOf(int i) => segment * i + segment / 2;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: centreOf(0),
                    right: width - centreOf(levels.length - 1),
                    top: 6,
                    child: Container(height: 2.5, color: trackColor),
                  ),
                  if (activeIndex > 0)
                    Positioned(
                      left: centreOf(0),
                      width: centreOf(activeIndex) - centreOf(0),
                      top: 6,
                      child: Container(height: 2.5, color: accent),
                    ),
                  for (var i = 0; i < levels.length; i++)
                    Positioned(
                      left: centreOf(i) - dot / 2,
                      top: 6 - dot / 2 + 1.25,
                      child: Container(
                        width: dot,
                        height: dot,
                        decoration: BoxDecoration(
                          color: i <= activeIndex ? accent : trackColor,
                          shape: BoxShape.circle,
                          border: i == activeIndex
                              ? Border.all(color: accent, width: 3)
                              : null,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: Insets.sm),
        Row(
          children: [
            for (var i = 0; i < levels.length; i++)
              Expanded(
                child: Text(
                  levels[i].shortLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: i == activeIndex ? FontWeight.w700 : FontWeight.w400,
                    color: i == activeIndex ? accent : labelColor,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
