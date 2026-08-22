import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// Persists [AppSettings] to device storage.
///
/// Every read falls back to the default when a key is missing or holds a value
/// this build no longer recognises, so an old install or a hand-edited
/// preference file cannot leave the app in an unrenderable state.
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
  static const _defaultBeach = 'settings.defaultBeachId';
  static const _whatsappNumber = 'settings.whatsappNumber';

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
        defaultBeachId: _prefs.getInt(_defaultBeach),
        whatsappNumber: _prefs.getString(_whatsappNumber) ?? '',
      );

  Future<void> write(AppSettings settings) async {
    await Future.wait([
      _prefs.setString(_waveUnit, settings.waveHeightUnit.name),
      _prefs.setString(_windUnit, settings.windSpeedUnit.name),
      _prefs.setString(_tempUnit, settings.temperatureUnit.name),
      _prefs.setString(_timeFormat, settings.timeFormat.name),
      _prefs.setString(_alertFilter, settings.alertFilter.name),
      if (settings.defaultBeachId != null)
        _prefs.setInt(_defaultBeach, settings.defaultBeachId!)
      else
        _prefs.remove(_defaultBeach),
      _prefs.setString(_whatsappNumber, settings.whatsappNumber),
    ]);
  }
}