import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../settings/app_settings.dart';
import '../../settings/settings_providers.dart';
import '../../state/providers.dart';
import 'emergency_contacts.dart';

/// Settings: units, the beach the app opens on, which alerts to surface, and
/// emergency numbers.
///
/// Every control here takes effect immediately and persists. Nothing on this
/// screen is a placeholder — a switch that does nothing is worse than an
/// absent one, especially with someone else holding the phone.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _surface = Color(0xFF12222E);
  static const _background = Color(0xFF0B1A24);
  static const _text = Color(0xFFEAF2F8);
  static const _muted = Color(0xFF93A9B8);
  static const _accent = Color(0xFF4FA8DC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final beaches = ref.watch(beachesProvider).value ?? const [];

    return ColoredBox(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.lg,
            Insets.lg,
            MediaQuery.paddingOf(context).bottom + Insets.xxl,
          ),
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: _text,
              ),
            ),
            const SizedBox(height: Insets.xl),

            _Section(
              title: 'Units',
              children: [
                _ChoiceRow<DistanceUnit>(
                  label: 'Wave height',
                  value: settings.waveHeightUnit,
                  options: DistanceUnit.values,
                  labelOf: (u) => u.symbol,
                  onChanged: controller.setWaveHeightUnit,
                ),
                _ChoiceRow<SpeedUnit>(
                  label: 'Wind speed',
                  value: settings.windSpeedUnit,
                  options: SpeedUnit.values,
                  labelOf: (u) => u.symbol,
                  onChanged: controller.setWindSpeedUnit,
                ),
                _ChoiceRow<TemperatureUnit>(
                  label: 'Water temperature',
                  value: settings.temperatureUnit,
                  options: TemperatureUnit.values,
                  labelOf: (u) => u.symbol,
                  onChanged: controller.setTemperatureUnit,
                ),
                _ChoiceRow<TimeFormat>(
                  label: 'Time format',
                  value: settings.timeFormat,
                  options: TimeFormat.values,
                  labelOf: (f) => f.shortLabel,
                  onChanged: controller.setTimeFormat,
                ),
              ],
            ),

            _Section(
              title: 'Alerts',
              footnote: 'Filters what the Home and Alerts tabs show. The '
                  'beach\'s own risk rating is never hidden.',
              children: [
                for (final filter in AlertSeverityFilter.values)
                  _RadioRow<AlertSeverityFilter>(
                    title: filter.label,
                    subtitle: filter.description,
                    value: filter,
                    groupValue: settings.alertFilter,
                    onChanged: controller.setAlertFilter,
                  ),
              ],
            ),

            _Section(
              title: 'Beach shown on launch',
              children: [
                _RadioRow<int?>(
                  title: 'First available',
                  subtitle: 'Whichever beach the service lists first',
                  value: null,
                  groupValue: settings.defaultBeachId,
                  onChanged: controller.setDefaultBeach,
                ),
                for (final beach in beaches)
                  _RadioRow<int?>(
                    title: beach.name,
                    subtitle: beach.region,
                    value: beach.id,
                    groupValue: settings.defaultBeachId,
                    onChanged: controller.setDefaultBeach,
                  ),
              ],
            ),

            _Section(
              title: 'Emergency contacts',
              footnote: 'National numbers. Verify against official sources '
                  'before relying on them.',
              children: [
                for (final contact in emergencyContacts)
                  _ContactRow(contact: contact),
              ],
            ),

            const SizedBox(height: Insets.sm),
            Center(
              child: TextButton(
                onPressed: () async {
                  await controller.resetToDefaults();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings reset')),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: _muted),
                child: const Text('Reset to defaults'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.footnote,
  });

  final String title;
  final List<Widget> children;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Insets.xs, bottom: Insets.sm),
            child: Text(
              title.toUpperCase(),
              style: AppText.overline.copyWith(
                color: SettingsScreen._muted,
              ),
            ),
          ),
          // Material, not a DecoratedBox: the rows are InkWells, and without
          // their own Material here the ripple would paint on the Scaffold
          // beneath this opaque background and never be seen. It also lets
          // the screen render standalone, outside AppShell.
          Material(
            color: SettingsScreen._surface,
            borderRadius: BorderRadius.circular(Radii.card),
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(children: children),
            ),
          ),
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.only(
                left: Insets.xs,
                top: Insets.sm,
                right: Insets.sm,
              ),
              child: Text(
                footnote!,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: SettingsScreen._muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A label with a segmented set of choices — used where the options are short
/// enough to sit side by side, like unit symbols.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm + 2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: SettingsScreen._text),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in options)
                    Padding(
                      padding: const EdgeInsets.only(left: Insets.xs + 2),
                      child: _Pill(
                        label: labelOf(option),
                        selected: option == value,
                        onTap: () => onChanged(option),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? SettingsScreen._accent.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(Radii.chip),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.chip),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.sm,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? SettingsScreen._accent
                    : SettingsScreen._muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioRow<T> extends StatelessWidget {
  const _RadioRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      child: Semantics(
        selected: selected,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.md,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected
                    ? SettingsScreen._accent
                    : SettingsScreen._muted,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: SettingsScreen._text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: SettingsScreen._muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact});

  final EmergencyContact contact;

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: contact.number);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      // Emulators and tablets often have no dialler. Say so rather than
      // failing silently — the number itself is still on screen.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No dialler available. Call ${contact.number}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _call(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.md,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFC02A30).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.call_rounded,
                  size: 20, color: Color(0xFFE5484D)),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: SettingsScreen._text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: SettingsScreen._muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              contact.number,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE5484D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
