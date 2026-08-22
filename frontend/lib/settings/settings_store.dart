// File: lib/settings/settings_store.dart
// Description: Local storage persistence wrapper backed by SharedPreferences for saving and reading AppSettings options across app sessions.

import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

// Persists AppSettings to device storage with fallback defaults.
class SettingsStore {
  SettingsStore(this._prefs);


  final SharedPreferences _prefs;

  static Future<SettingsStore> open() async =>
      SettingsStore(await SharedPreferences.getInstance());

  static const _waveUnit = 'settings.waveHeightUnit';
  static const _windUnit = 'settings.windSpeedUnit';
  static const _tempUnit = 'settings.temperatureUnit';
  static const _timeFormat = 'settings.timeFormat';
  static const _alertFilter = 'settings.alertFilter';
  static const _alertChannel = 'settings.alertChannel';
  static const _whatsappNumber = 'settings.whatsappNumber';
  static const _defaultBeach = 'settings.defaultBeachId';

  T _readEnum<T extends Enum>(String key, List<T> values, T fallback) {
    final name = _prefs.getString(key);
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  AppSettings read() => AppSettings(
        waveHeightUnit:
            _readEnum(_waveUnit, DistanceUnit.values, DistanceUnit.metres),
        windSpeedUnit: _readEnum(_windUnit, SpeedUnit.values, SpeedUnit.kmh),
        temperatureUnit: _readEnum(
            _tempUnit, TemperatureUnit.values, TemperatureUnit.celsius),
        timeFormat:
            _readEnum(_timeFormat, TimeFormat.values, TimeFormat.twelveHour),
        alertFilter: _readEnum(
            _alertFilter, AlertSeverityFilter.values, AlertSeverityFilter.all),
        alertChannel:
            _readEnum(_alertChannel, AlertChannel.values, AlertChannel.off),
        whatsappNumber: _prefs.getString(_whatsappNumber),
        defaultBeachId: _prefs.getInt(_defaultBeach),
      );

  Future<void> write(AppSettings settings) async {
    await Future.wait([
      _prefs.setString(_waveUnit, settings.waveHeightUnit.name),
      _prefs.setString(_windUnit, settings.windSpeedUnit.name),
      _prefs.setString(_tempUnit, settings.temperatureUnit.name),
      _prefs.setString(_timeFormat, settings.timeFormat.name),
      _prefs.setString(_alertFilter, settings.alertFilter.name),
      _prefs.setString(_alertChannel, settings.alertChannel.name),
      if (settings.whatsappNumber case final number?)
        _prefs.setString(_whatsappNumber, number)
      else
        _prefs.remove(_whatsappNumber),
      if (settings.defaultBeachId != null)
        _prefs.setInt(_defaultBeach, settings.defaultBeachId!)
      else
        _prefs.remove(_defaultBeach),
    ]);
  }
}
