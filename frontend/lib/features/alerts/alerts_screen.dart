// File: lib/features/alerts/alerts_screen.dart
// Description: Alerts tab screen displaying active safety warnings for the selected beach under a light severity backdrop.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/risk_theme.dart';
import '../../models/beach.dart';
import '../../models/risk_level.dart';
import '../../models/safety_alert.dart';
import '../../state/providers.dart';
import '../../widgets/severity_backdrop.dart';
import '../home/widgets/active_alerts_section.dart';
import 'alert_detail_screen.dart';

// The Alerts tab listing active alerts for the selected beach.
class AlertsScreen extends ConsumerWidget {

  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beachAsync = ref.watch(selectedBeachProvider);
    final alertsAsync = ref.watch(alertsProvider);

    final beach = beachAsync.value;
    // Before the beach resolves there is no risk level to theme from; low
    // keeps the backdrop calm rather than flashing red during a load.
    //
    // The light variant is deliberate: this tab is a list of warnings to be
    // read, so it takes a severity tint and dark text rather than the Home
    // tab's photograph and white text.
    final risk = RiskTheme.forLevel(beach?.riskLevel ?? RiskLevel.low).lightVariant;

    return RiskThemeScope(
      theme: risk,
      child: SeverityBackdrop(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => refreshAll(ref),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                Insets.xxl,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _Header(beach: beach, risk: risk),
                const SizedBox(height: Insets.xl),
                switch (alertsAsync) {
                  AsyncData(:final value) => ActiveAlertsSection(
                      alerts: value,
                      onAlertTap: (alert) => _open(context, alert),
                    ),
                  AsyncError(:final error) => _ErrorState(
                      message: error
                          .toString()
                          .replaceFirst('BeachRepositoryException: ', ''),
                      onRetry: () => ref.invalidate(beachesProvider),
                      color: risk.contentForeground,
                    ),
                  _ => const Padding(
                      padding: EdgeInsets.symmetric(vertical: Insets.xxl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, SafetyAlert alert) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AlertDetailScreen(alert: alert)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.beach, required this.risk});

  final Beach? beach;
  final RiskTheme risk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alerts',
          style: AppText.beachTitle.copyWith(color: risk.headerForeground),
        ),
        const SizedBox(height: Insets.xs),
        Text(
          beach == null ? 'Loading…' : '${beach!.name} · ${beach!.region}',
          style: AppText.beachRegion.copyWith(color: risk.onBackdropMuted),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.color,
  });

  final String message;
  final VoidCallback onRetry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xxl),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, color: color.withValues(alpha: 0.8), size: 34),
          const SizedBox(height: Insets.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 14.5),
          ),
          const SizedBox(height: Insets.lg),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
