// File: lib/features/home/widgets/active_alerts_section.dart
// Description: Active alerts list section component on the home screen displaying alert cards or a no-alerts status card.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/settings_providers.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/risk_theme.dart';
import '../../../models/risk_level.dart';
import '../../../models/safety_alert.dart';
import '../../../widgets/hazard_icon.dart';
import '../../../widgets/surface_card.dart';

// Active Alerts list section or empty state card when there are none.
class ActiveAlertsSection extends StatelessWidget {

  const ActiveAlertsSection({
    super.key,
    required this.alerts,
    required this.onAlertTap,
  });

  final List<SafetyAlert> alerts;
  final ValueChanged<SafetyAlert> onAlertTap;

  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Alerts',
          style: AppText.sectionHeader.copyWith(color: risk.contentForeground),
        ),
        const SizedBox(height: Insets.md),
        if (alerts.isEmpty)
          const _NoAlertsCard()
        else
          for (final alert in alerts) ...[
            _AlertCard(alert: alert, onTap: () => onAlertTap(alert)),
            if (alert != alerts.last) const SizedBox(height: Insets.md),
          ],
      ],
    );
  }
}

class _AlertCard extends ConsumerWidget {
  const _AlertCard({required this.alert, required this.onTap});

  final SafetyAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final risk = RiskTheme.of(context);
    final accent = RiskTheme.accentFor(alert.riskLevel, onDark: risk.isDark);
    final fmt = ref.watch(formatterProvider);

    return SurfaceCard(
      onTap: onTap,
      leadingAccent: accent,
      padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.md, Insets.md, Insets.md),
      child: Row(
        children: [
          HazardIcon(kind: alert.kind, color: accent),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  alert.title,
                  style: AppText.alertTitle.copyWith(color: risk.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  fmt.alertMeta(alert),
                  style: AppText.alertMeta.copyWith(color: risk.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: risk.textSecondary, size: 20),
        ],
      ),
    );
  }
}

class _NoAlertsCard extends StatelessWidget {
  const _NoAlertsCard();

  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);
    final accent = RiskTheme.accentFor(RiskLevel.low, onDark: risk.isDark);

    return SurfaceCard(
      leadingAccent: accent,
      padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.lg, Insets.md, Insets.lg),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: accent, size: 30),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No Active Alerts',
                  style: AppText.alertTitle.copyWith(color: risk.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  'All conditions are safe.',
                  style: AppText.alertMeta.copyWith(color: risk.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
