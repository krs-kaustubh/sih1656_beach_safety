// File: lib/widgets/severity_backdrop.dart
// Description: Backdrop container applying a severity-tinted vertical color gradient behind alerts and lists.

import 'package:flutter/material.dart';

import '../core/theme/risk_theme.dart';

// A plain severity-tinted gradient used where a photograph would compete with content.
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
