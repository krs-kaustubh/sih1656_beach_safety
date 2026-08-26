// File: lib/settings/settings_providers.dart
// Description: Riverpod providers and state controller for accessing AppSettings, persisting configuration edits, and exposing UnitFormatter instance.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'settings_store.dart';
import 'unit_formatter.dart';

// Overridden in main() once storage has opened, and in tests with an in-memory store.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw StateError('settingsStoreProvider was not overridden'),
);

// Current settings controller. Writes persist immediately to settings store.
class SettingsController extends Notifier<AppSettings> {

  @override
  AppSettings build() => ref.read(settingsStoreProvider).read();

  Future<void> _update(AppSettings next) async {
    if (next == state) return;
    state = next;
    await ref.read(settingsStoreProvider).write(next);
  }

  Future<void> setWaveHeightUnit(DistanceUnit unit) =>
      _update(state.copyWith(waveHeightUnit: unit));

  Future<void> setWindSpeedUnit(SpeedUnit unit) =>
      _update(state.copyWith(windSpeedUnit: unit));

  Future<void> setTemperatureUnit(TemperatureUnit unit) =>
      _update(state.copyWith(temperatureUnit: unit));

  Future<void> setTimeFormat(TimeFormat format) =>
      _update(state.copyWith(timeFormat: format));

  Future<void> setAlertFilter(AlertSeverityFilter filter) =>
      _update(state.copyWith(alertFilter: filter));

  Future<void> setAlertChannel(AlertChannel channel) =>
      _update(state.copyWith(alertChannel: channel));

  Future<void> setDefaultBeach(int? beachId) => _update(
        state.copyWith(
          defaultBeachId: beachId,
          clearDefaultBeach: beachId == null,
        ),
      );

  Future<void> setWhatsappNumber(String number) =>
      _update(state.copyWith(whatsappNumber: number));

  Future<void> resetToDefaults() => _update(AppSettings.defaults);
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

// Formatter matching the current settings. Rebuilt only when settings change.
final formatterProvider = Provider<UnitFormatter>(
  (ref) => UnitFormatter(ref.watch(settingsProvider)),
);
