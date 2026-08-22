// File: lib/widgets/risk_backdrop.dart
// Description: Full-bleed background widget combining photograph backdrops with fallback procedural scene rendering and content gradient scrims.

import 'package:flutter/material.dart';

import '../core/theme/risk_theme.dart';
import 'backdrop_scene.dart';

// Full-bleed background behind the Home screen with photo assets or procedural fallbacks.
class RiskBackdrop extends StatelessWidget {
  const RiskBackdrop({
    super.key,
    required this.child,
    this.imageAsset,
  });

  final Widget child;

  // Overrides the risk level's own photograph.
  final String? imageAsset;

  // Where the photo starts giving way to the page colour.
  static const _fadeStops = [0.30, 0.62, 0.78];


  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);
    final surface = risk.backdrop.last;
    final asset = imageAsset ?? risk.backdropAsset;

    return ColoredBox(
      color: surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Painted underneath rather than only on error: it fills the frame
          // while the image decodes, so there is no flash of flat colour.
          CustomPaint(
            painter: BackdropScenePainter(
              level: risk.level,
              surfaceColor: surface,
            ),
          ),
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            // A missing or corrupt asset must not take the screen down
            // mid-demo, so fall through to the painted scene below. Say so in
            // debug builds though: the painted scene resembles the photo
            // closely enough that a silent failure is indistinguishable from
            // a stale asset bundle, which is a miserable thing to debug.
            errorBuilder: (_, error, _) {
              assert(() {
                debugPrint(
                  'RiskBackdrop: could not load "$asset" ($error). '
                  'Falling back to the painted scene. If you just added this '
                  'asset, restart the app — hot reload does not rebuild the '
                  'asset bundle.',
                );
                return true;
              }());
              return const SizedBox.shrink();
            },
          ),
          // Top scrim. The beach name, region and search field are white, and
          // a photo's sky can be bright anywhere — the sun sits in the top
          // corner of two of these three. This guarantees the contrast rather
          // than relying on which photo happens to be in the slot.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x73000000), Color(0x26000000), Color(0x00000000)],
                stops: [0.0, 0.18, 0.40],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  surface.withValues(alpha: 0.0),
                  surface.withValues(alpha: 0.86),
                  surface,
                ],
                stops: _fadeStops,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
