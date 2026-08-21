import 'package:flutter/material.dart';

import '../core/theme/risk_theme.dart';
import 'backdrop_scene.dart';

/// Full-bleed background behind the Home screen.
///
/// Draws the scene for the ambient risk level — clear day, sunset or storm —
/// matching the photographic backgrounds in the designs. Supplying
/// [imageAsset] replaces the painted scene with a real photograph, keeping a
/// tinted scrim so the content above stays legible.
class RiskBackdrop extends StatelessWidget {
  const RiskBackdrop({
    super.key,
    required this.child,
    this.imageAsset,
  });

  final Widget child;

  /// Optional photograph to use instead of the painted scene.
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);
    final surface = risk.backdrop.last;

    return ColoredBox(
      color: surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageAsset == null)
            CustomPaint(
              painter: BackdropScenePainter(
                level: risk.level,
                surfaceColor: surface,
              ),
            )
          else ...[
            Image.asset(
              imageAsset!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              // A missing asset must not take the screen down mid-demo.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            // Same fade as the painted scene, so a photo drops in without the
            // cards below losing their contrast.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    surface.withValues(alpha: 0.0),
                    surface.withValues(alpha: 0.88),
                    surface,
                  ],
                  stops: const [0.18, 0.52, 0.68],
                ),
              ),
            ),
          ],
          child,
        ],
      ),
    );
  }
}
