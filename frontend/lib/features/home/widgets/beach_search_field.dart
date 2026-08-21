import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/risk_theme.dart';

/// The translucent "Search beaches" field over the backdrop.
///
/// Read-only and tap-to-open: the field itself is a button that raises the
/// search sheet, which keeps the keyboard off the Home screen.
class BeachSearchField extends StatelessWidget {
  const BeachSearchField({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);

    return Material(
      color: Colors.white.withValues(alpha: risk.isDark ? 0.10 : 0.22),
      borderRadius: BorderRadius.circular(Radii.field),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.field),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: risk.onBackdropMuted, size: 21),
              const SizedBox(width: Insets.sm),
              Text(
                'Search beaches',
                style: TextStyle(fontSize: 15.5, color: risk.onBackdropMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
