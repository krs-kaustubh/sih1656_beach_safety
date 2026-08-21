import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/settings_providers.dart';
import '../../settings/unit_formatter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/risk_theme.dart';
import '../../models/safety_alert.dart';
import 'widgets/affected_area_card.dart';
import 'widgets/conditions_strip.dart';
import 'widgets/lifeguard_badge.dart';
import 'widgets/risk_meter.dart';

/// Full detail for one alert.
///
/// Themed by the *alert's* risk level rather than the beach's, so a moderate
/// advisory keeps its amber treatment even when opened from a high-risk beach.
class AlertDetailScreen extends ConsumerWidget {
  const AlertDetailScreen({super.key, required this.alert});

  final SafetyAlert alert;

  void _share(BuildContext context, UnitFormatter fmt) {
    final text = '${alert.title} — ${alert.zoneLabel}\n'
        '${fmt.alertValidity(alert)}\n\n'
        '${alert.whatsHappening}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alert details copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(formatterProvider);
    final risk = RiskTheme.forLevel(alert.riskLevel);
    final accent = RiskTheme.accentFor(alert.riskLevel, onDark: risk.isDark);
    final text = risk.textPrimary;
    final muted = risk.textSecondary;

    // Alerts may carry their own snapshot; otherwise show nothing rather than
    // borrowing another beach's readings.
    final conditions = alert.conditions;

    return RiskThemeScope(
      theme: risk,
      child: Scaffold(
        backgroundColor: risk.detailBackdrop,
        body: Column(
          children: [
            _DetailHeader(
              alert: alert,
              risk: risk,
              formatter: fmt,
              onShare: () => _share(context, fmt),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: risk.detailSurface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Radii.card),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.lg,
                    Insets.lg,
                    Insets.lg,
                    Insets.xxl,
                  ),
                  children: [
                    _Panel(
                      borderColor: muted,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Overline('RISK LEVEL', color: muted),
                                const SizedBox(height: Insets.md),
                                RiskMeter(
                                  level: alert.riskLevel,
                                  accent: accent,
                                  trackColor: muted.withValues(alpha: 0.3),
                                  labelColor: muted,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Insets.lg),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Overline('LIFEGUARD STATUS', color: muted),
                                const SizedBox(height: Insets.md),
                                if (alert.lifeguard != null)
                                  LifeguardBadge(
                                    status: alert.lifeguard!,
                                    accent: accent,
                                    textColor: text,
                                  )
                                else
                                  Text(
                                    'Unknown',
                                    style: TextStyle(color: muted, fontSize: 14),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (conditions != null) ...[
                      const SizedBox(height: Insets.md),
                      _Panel(
                        borderColor: muted,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Overline('CURRENT CONDITIONS', color: accent),
                            const SizedBox(height: Insets.md),
                            ConditionsStrip(
                              conditions: conditions,
                              textColor: text,
                              mutedColor: muted,
                              accent: accent,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: Insets.xl),
                    _HappeningAndActions(
                      alert: alert,
                      accent: accent,
                      textColor: text,
                      mutedColor: muted,
                    ),
                    if (alert.affectedArea != null) ...[
                      const SizedBox(height: Insets.xl),
                      _Overline('AFFECTED AREA', color: accent),
                      const SizedBox(height: Insets.md),
                      AffectedAreaCard(
                        area: alert.affectedArea!,
                        accent: accent,
                        textColor: text,
                        mutedColor: muted,
                        onViewFullMap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Full map arrives with the Maps tab'),
                            ),
                          );
                        },
                      ),
                    ],
                    if (alert.safetyTip != null) ...[
                      const SizedBox(height: Insets.xl),
                      _SafetyTip(
                        tip: alert.safetyTip!,
                        accent: accent,
                        textColor: text,
                        mutedColor: muted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.alert,
    required this.risk,
    required this.formatter,
    required this.onShare,
  });

  final SafetyAlert alert;
  final RiskTheme risk;
  final UnitFormatter formatter;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    const fg = Colors.white;

    return Container(
      width: double.infinity,
      color: risk.detailHeader,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    label: const Text('BACK TO ALERTS'),
                    style: TextButton.styleFrom(
                      foregroundColor: fg,
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded, size: 15),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: fg,
                      side: BorderSide(color: fg.withValues(alpha: 0.45)),
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Text(
                  '${alert.riskLevel.shortLabel.toUpperCase()} · ${alert.urgency.label}',
                  style: const TextStyle(
                    color: fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              Text(alert.title, style: AppText.detailTitle.copyWith(color: fg)),
              const SizedBox(height: Insets.sm),
              _HeaderMetaRow(
                icon: Icons.place_outlined,
                text: alert.zoneLabel,
              ),
              const SizedBox(height: Insets.xs),
              _HeaderMetaRow(
                icon: Icons.schedule_rounded,
                text: formatter.alertValidity(alert),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderMetaRow extends StatelessWidget {
  const _HeaderMetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: 0.9);
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: Insets.sm - 2),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13.5, color: color)),
        ),
      ],
    );
  }
}

/// "WHAT'S HAPPENING" and "WHAT TO DO" side by side.
///
/// They stack on narrow screens, where two columns would squeeze the prose
/// into unreadable ribbons.
class _HappeningAndActions extends StatelessWidget {
  const _HappeningAndActions({
    required this.alert,
    required this.accent,
    required this.textColor,
    required this.mutedColor,
  });

  final SafetyAlert alert;
  final Color accent;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    // The live service sends alerts without guidance text — only a type, a
    // title, a time and a scope. Rendering the headings anyway would leave
    // "WHAT TO DO" standing over nothing.
    final hasHappening = alert.whatsHappening.trim().isNotEmpty;
    final hasActions = alert.whatToDo.isNotEmpty;
    if (!hasHappening && !hasActions) return const SizedBox.shrink();

    final happening = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Overline("WHAT'S HAPPENING", color: accent),
        const SizedBox(height: Insets.sm),
        Text(
          alert.whatsHappening,
          style: AppText.body.copyWith(color: textColor),
        ),
      ],
    );

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Overline('WHAT TO DO', color: accent),
        const SizedBox(height: Insets.sm),
        for (final step in alert.whatToDo)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm + 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, size: 15, color: accent),
                const SizedBox(width: Insets.sm - 1),
                Expanded(
                  child: Text(step, style: AppText.body.copyWith(color: textColor)),
                ),
              ],
            ),
          ),
      ],
    );

    if (!hasActions) return happening;
    if (!hasHappening) return actions;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The designs pair these columns on a standard ~360dp phone, so the
        // breakpoint sits below that and only stacks on genuinely small
        // screens where two columns of prose would be unreadable.
        if (constraints.maxWidth < 330) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [happening, const SizedBox(height: Insets.xl), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: happening),
            const SizedBox(width: Insets.xl),
            Expanded(child: actions),
          ],
        );
      },
    );
  }
}

class _SafetyTip extends StatelessWidget {
  const _SafetyTip({
    required this.tip,
    required this.accent,
    required this.textColor,
    required this.mutedColor,
  });

  final String tip;
  final Color accent;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 19, color: accent),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Overline('SAFETY TIP', color: accent),
                const SizedBox(height: Insets.xs + 1),
                Text(tip, style: AppText.body.copyWith(color: textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, required this.borderColor});

  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md + 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: borderColor.withValues(alpha: 0.22)),
      ),
      child: child,
    );
  }
}

class _Overline extends StatelessWidget {
  const _Overline(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.overline.copyWith(color: color));
}
