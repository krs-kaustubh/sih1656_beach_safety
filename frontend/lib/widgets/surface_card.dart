import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/risk_theme.dart';

/// The rounded card used for metrics, alerts and panels.
///
/// Reads its colours from the ambient [RiskTheme] so the same widget renders
/// light on the low/moderate screens and dark on the high-risk screen.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Insets.lg),
    this.onTap,
    this.leadingAccent,
    this.radius = Radii.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Coloured bar down the left edge, used by alert cards.
  final Color? leadingAccent;

  final double radius;

  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);
    final shape = BorderRadius.circular(radius);

    return Material(
      color: risk.surface,
      borderRadius: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: risk.surfaceBorder),
            // Drawn as a border rather than a stacked container so the accent
            // follows the rounded corner instead of squaring it off.
            gradient: leadingAccent == null
                ? null
                : LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [leadingAccent!, leadingAccent!, Colors.transparent],
                    stops: const [0.0, 0.012, 0.012],
                  ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
