import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/risk_theme.dart';
import '../../models/beach.dart';
import '../../models/safety_alert.dart';
import '../../state/providers.dart';
import '../../widgets/risk_backdrop.dart';
import '../alerts/alert_detail_screen.dart';
import 'beach_search_sheet.dart';
import 'widgets/active_alerts_section.dart';
import 'widgets/beach_search_field.dart';
import 'widgets/conditions_grid.dart';
import 'widgets/home_header.dart';
import 'widgets/risk_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late DateTime _now = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // The header shows a wall clock, so tick it rather than freezing at the
    // time the screen happened to be built.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _openAlert(SafetyAlert alert) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AlertDetailScreen(alert: alert)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final beachAsync = ref.watch(selectedBeachProvider);

    return switch (beachAsync) {
      AsyncData(:final value) => _HomeContent(
          beach: value,
          now: _now,
          onAlertTap: _openAlert,
        ),
      AsyncError(:final error) => _HomeMessage(
          message: switch (error) {
            final e => e.toString().replaceFirst('BeachRepositoryException: ', ''),
          },
          onRetry: () => ref.invalidate(beachesProvider),
        ),
      _ => const _HomeMessage(loading: true),
    };
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({
    required this.beach,
    required this.now,
    required this.onAlertTap,
  });

  final Beach beach;
  final DateTime now;
  final ValueChanged<SafetyAlert> onAlertTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final risk = RiskTheme.forLevel(beach.riskLevel);
    final alertsAsync = ref.watch(alertsProvider);

    return RiskThemeScope(
      theme: risk,
      child: RiskBackdrop(
        child: RefreshIndicator(
          onRefresh: () => refreshAll(ref),
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                Insets.xxl,
              ),
              // Always scrollable so pull-to-refresh works even when the
              // content is short enough to fit the screen.
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                HomeHeader(beach: beach, time: now),
                const SizedBox(height: Insets.lg),
                BeachSearchField(onTap: () => BeachSearchSheet.show(context)),
                const SizedBox(height: Insets.lg),
                RiskBanner(beach: beach),
                const SizedBox(height: Insets.lg),
                ConditionsGrid(conditions: beach.conditions),
                const SizedBox(height: Insets.xl),
                switch (alertsAsync) {
                  AsyncData(:final value) => ActiveAlertsSection(
                      alerts: value,
                      onAlertTap: onAlertTap,
                    ),
                  AsyncError() => const _AlertsUnavailable(),
                  _ => const Padding(
                      padding: EdgeInsets.symmetric(vertical: Insets.xl),
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
}

/// Alerts failing should not blank the conditions the user came for, so this
/// occupies only the alerts slot.
class _AlertsUnavailable extends StatelessWidget {
  const _AlertsUnavailable();

  @override
  Widget build(BuildContext context) {
    final risk = RiskTheme.of(context);
    return Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 18, color: risk.onBackdropMuted),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            'Alerts are unavailable right now.',
            style: TextStyle(color: risk.onBackdropMuted, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _HomeMessage extends StatelessWidget {
  const _HomeMessage({this.message, this.onRetry, this.loading = false});

  final String? message;
  final VoidCallback? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0B1A24),
      child: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(Insets.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.white70, size: 40),
                    const SizedBox(height: Insets.md),
                    Text(
                      message ?? 'Something went wrong.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: Insets.lg),
                      FilledButton(onPressed: onRetry, child: const Text('Try again')),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
