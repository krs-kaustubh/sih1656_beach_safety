import 'package:flutter/material.dart';

import '../core/theme/risk_theme.dart';

/// Full-bleed background behind the Home screen.
///
/// The designs use a photograph per risk level (clear day, sunset, storm).
/// Until those assets exist this paints the equivalent gradient, and
/// [imageAsset] is the seam where a photo drops in without touching callers:
/// pass an asset path and the gradient becomes a scrim over the image.
class RiskBackdrop extends StatelessWidget {
  const RiskBackdrop({
    super.key,
    required this.child,
    this.imageAsset,
  });

  final Widget child;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: risk.backdrop,
          stops: const [0.0, 0.32, 0.62, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageAsset != null)
            Image.asset(
              imageAsset!,
              fit: BoxFit.cover,
              // A missing asset must not take the screen down mid-demo.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          if (imageAsset != null)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    risk.backdrop.first.withValues(alpha: 0.85),
                    risk.backdrop.last.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
