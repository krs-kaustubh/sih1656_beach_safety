import 'package:flutter/material.dart';

import '../core/theme/risk_theme.dart';

/// A plain severity-tinted gradient, used where a photograph would compete
/// with the content.
///
/// The Alerts tab is a list of warnings to be read, not a view of the beach.
/// A tint that says "green / amber / red" at a glance carries the severity
/// without the photograph's busy detail sitting behind the text.
class SeverityBackdrop extends StatelessWidget {
  const SeverityBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: risk.backdrop,
          // Weighted towards the top so the tint reads immediately, then
          // clears to near-white where the alert cards sit.
          stops: const [0.0, 0.22, 0.45, 1.0],
        ),
      ),
      child: child,
    );
  }
}
