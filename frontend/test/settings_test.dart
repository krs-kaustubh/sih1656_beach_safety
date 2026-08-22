// File: test/settings_test.dart
// Description: Unit test suite for unit conversion math, UnitFormatter text output, AlertSeverityFilter logic, SettingsStore persistence, and SettingsController state updates.

import 'package:beach_safety/models/risk_level.dart';
import 'package:beach_safety/settings/app_settings.dart';
import 'package:beach_safety/settings/settings_providers.dart';
import 'package:beach_safety/settings/settings_store.dart';
import 'package:beach_safety/settings/unit_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {

  TestWidgetsFlutterBinding.ensureInitialized();

  group('unit conversion', () {
    test('wave height converts metres to feet', () {
      expect(DistanceUnit.metres.fromMetres(2.8), closeTo(2.8, 1e-9));
      expect(DistanceUnit.feet.fromMetres(2.8), closeTo(9.186, 0.01));
    });

    test('wind speed converts from km/h', () {
      expect(SpeedUnit.kmh.fromKmh(32), closeTo(32, 1e-9));
      expect(SpeedUnit.knots.fromKmh(32), closeTo(17.28, 0.01));
      expect(SpeedUnit.mph.fromKmh(32), closeTo(19.88, 0.01));
    });

    test('temperature converts from celsius', () {
      expect(TemperatureUnit.celsius.fromCelsius(28), closeTo(28, 1e-9));
      expect(TemperatureUnit.fahrenheit.fromCelsius(28), closeTo(82.4, 0.01));
    });
  });

  group('UnitFormatter', () {
    test('formats readings in metric by default', () {
      final fmt = UnitFormatter(AppSettings.defaults);
      expect(fmt.waveHeight(2.8).value, '2.8');
      expect(fmt.waveHeight(2.8).unit, 'm');
      expect(fmt.windSpeed(32, direction: 'SW').value, '32');
      expect(fmt.windSpeed(32, direction: 'SW').unit, 'km/h SW');
      expect(fmt.temperature(28).value, '28°C');
    });

    test('formats readings in imperial when asked', () {
      final fmt = UnitFormatter(const AppSettings(
        waveHeightUnit: DistanceUnit.feet,
        windSpeedUnit: SpeedUnit.mph,
        temperatureUnit: TemperatureUnit.fahrenheit,
      ));
      expect(fmt.waveHeight(2.8).value, '9');
      expect(fmt.waveHeight(2.8).unit, 'ft');
      expect(fmt.windSpeed(32, direction: 'SW').unit, 'mph SW');
      expect(fmt.temperature(28).value, '82°F');
    });

    test('omits the direction when the backend does not send one', () {
      final fmt = UnitFormatter(AppSettings.defaults);
      expect(fmt.windSpeed(18).unit, 'km/h');
    });

    test('renders an em dash for a missing reading', () {
      final fmt = UnitFormatter(AppSettings.defaults);
      expect(fmt.windSpeed(null).value, '—');
      expect(fmt.temperature(null).value, '—');
    });

    test('every clock follows one time format', () {
      // The bug this prevents: a 12-hour header beside a 24-hour tide readout
      // on the same screen, which is what the app shipped before settings.
      final noon = DateTime(2026, 8, 21, 12, 30);
      final evening = DateTime(2026, 8, 21, 18, 42);

      final twelve = UnitFormatter(const AppSettings(
        timeFormat: TimeFormat.twelveHour,
      ));
      expect(twelve.clock(noon), '12:30 PM');
      expect(twelve.clock(evening), '6:42 PM');

      final twentyFour = UnitFormatter(const AppSettings(
        timeFormat: TimeFormat.twentyFourHour,
      ));
      expect(twentyFour.clock(noon), '12:30');
      expect(twentyFour.clock(evening), '18:42');
    });

    test('trims a trailing .0 but keeps a meaningful decimal', () {
      expect(UnitFormatter.number(2.8), '2.8');
      expect(UnitFormatter.number(3.0), '3');
      expect(UnitFormatter.number(32.4, decimals: 0), '32');
    });
  });

  group('AlertSeverityFilter', () {
    test('all lets everything through', () {
      for (final level in RiskLevel.values) {
        expect(AlertSeverityFilter.all.allows(level), isTrue);
      }
    });

    test('moderateAndAbove hides only low-risk advisories', () {
      expect(AlertSeverityFilter.moderateAndAbove.allows(RiskLevel.low), isFalse);
      expect(AlertSeverityFilter.moderateAndAbove.allows(RiskLevel.moderate), isTrue);
      expect(AlertSeverityFilter.moderateAndAbove.allows(RiskLevel.high), isTrue);
    });

    test('severeOnly keeps just the high-risk warnings', () {
      expect(AlertSeverityFilter.severeOnly.allows(RiskLevel.low), isFalse);
      expect(AlertSeverityFilter.severeOnly.allows(RiskLevel.moderate), isFalse);
      expect(AlertSeverityFilter.severeOnly.allows(RiskLevel.high), isTrue);
    });
  });

  group('SettingsStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('returns defaults when nothing is stored', () async {
      final store = await SettingsStore.open();
      expect(store.read(), AppSettings.defaults);
    });

    test('round-trips every field', () async {
      final store = await SettingsStore.open();
      const saved = AppSettings(
        waveHeightUnit: DistanceUnit.feet,
        windSpeedUnit: SpeedUnit.knots,
        temperatureUnit: TemperatureUnit.fahrenheit,
        timeFormat: TimeFormat.twentyFourHour,
        alertFilter: AlertSeverityFilter.severeOnly,
        defaultBeachId: 3,
      );
      await store.write(saved);

      expect((await SettingsStore.open()).read(), saved);
    });

    test('clearing the default beach removes it rather than storing a zero',
        () async {
      final store = await SettingsStore.open();
      await store.write(const AppSettings(defaultBeachId: 2));
      expect(store.read().defaultBeachId, 2);

      await store.write(const AppSettings());
      expect((await SettingsStore.open()).read().defaultBeachId, isNull);
    });

    test('falls back to defaults for values this build does not recognise',
        () async {
      // An older or newer install, or a hand-edited preference file, must not
      // leave the app unable to render.
      SharedPreferences.setMockInitialValues({
        'settings.waveHeightUnit': 'furlongs',
        'settings.timeFormat': '',
      });
      final store = await SettingsStore.open();
      expect(store.read().waveHeightUnit, DistanceUnit.metres);
      expect(store.read().timeFormat, TimeFormat.twelveHour);
    });
  });

  group('SettingsController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('persists a change immediately', () async {
      final store = await SettingsStore.open();
      final container = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setWaveHeightUnit(DistanceUnit.feet);

      expect(container.read(settingsProvider).waveHeightUnit, DistanceUnit.feet);
      // A preference that survives only until the next launch is worse than
      // no preference at all, so check storage rather than just state.
      expect((await SettingsStore.open()).read().waveHeightUnit,
          DistanceUnit.feet);
    });

    test('the formatter follows the settings', () async {
      final store = await SettingsStore.open();
      final container = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      expect(container.read(formatterProvider).waveHeight(2.8).unit, 'm');

      await container
          .read(settingsProvider.notifier)
          .setWaveHeightUnit(DistanceUnit.feet);

      expect(container.read(formatterProvider).waveHeight(2.8).unit, 'ft');
    });

    test('reset restores every default', () async {
      final store = await SettingsStore.open();
      await store.write(const AppSettings(
        waveHeightUnit: DistanceUnit.feet,
        defaultBeachId: 3,
      ));
      final container = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).resetToDefaults();

      expect(container.read(settingsProvider), AppSettings.defaults);
      expect((await SettingsStore.open()).read(), AppSettings.defaults);
    });
  });
}
