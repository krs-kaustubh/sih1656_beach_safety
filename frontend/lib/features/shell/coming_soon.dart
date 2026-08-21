import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/risk_theme.dart';
import '../../widgets/risk_backdrop.dart';

/// Shared empty state for tabs that are not built yet.
///
/// Deliberately says what is coming instead of showing a blank screen, so a
/// demo tap on Maps or Settings reads as "not yet" rather than "broken".
class ComingSoon extends StatelessWidget {
  const ComingSoon({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);

    return RiskBackdrop(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 44, color: risk.onBackdropMuted),
                const SizedBox(height: Insets.lg),
                Text(
                  title,
                  style: AppText.beachTitle.copyWith(color: risk.headerForeground),
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppText.bannerBody.copyWith(color: risk.onBackdropMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
