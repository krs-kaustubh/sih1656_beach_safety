// File: lib/widgets/home_widget_service.dart
// Description: Publishes the selected beach's current rating and conditions to the Android home screen widget.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/beach.dart';
import '../models/risk_level.dart';
import '../settings/unit_formatter.dart';

// Keys the Kotlin provider reads. Kept in one place because a typo on either
// side shows up as a blank tile rather than as an error.
const _keyRisk = 'widget_risk';
const _keyBeach = 'widget_beach';
const _keyTemperature = 'widget_temperature';
const _keyWave = 'widget_wave';
const _keyWind = 'widget_wind';
const _keyUv = 'widget_uv';
const _keyTide = 'widget_tide';

const _androidProvider = 'LeharWidgetProvider';

// Writes a beach's current picture to the home screen widget.
//
// Android only: iOS needs a WidgetKit extension, which is out of scope. On any
// other platform this is a no-op rather than an error, so callers need no
// platform check of their own.
class HomeWidgetService {
  const HomeWidgetService();

  // Values the widget shows, formatted the same way the app shows them so the
  // two never disagree on screen.
  Future<void> publish(Beach beach, UnitFormatter formatter) async {
    if (!_isSupported) return;

    final conditions = beach.conditions;

    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>(_keyRisk, _riskKey(beach.riskLevel)),
        HomeWidget.saveWidgetData<String>(_keyBeach, beach.name),
        HomeWidget.saveWidgetData<String>(
          _keyTemperature,
          formatter
              .temperature(
                conditions.airTempCelsius ?? conditions.waterTempCelsius,
              )
              .value,
        ),
        HomeWidget.saveWidgetData<String>(
          _keyWave,
          _reading(formatter.waveHeight(conditions.waveHeightMeters)),
        ),
        HomeWidget.saveWidgetData<String>(
          _keyWind,
          _reading(
            formatter.windSpeed(
              conditions.windSpeedKph,
              direction: conditions.windDirection,
            ),
          ),
        ),
        HomeWidget.saveWidgetData<String>(
          _keyUv,
          conditions.uvIndex == null
              ? '—'
              : [
                  formatter.uv(conditions.uvIndex!),
                  ?conditions.uvCategory,
                ].join(' '),
        ),
        HomeWidget.saveWidgetData<String>(_keyTide, _tide(beach, formatter)),
      ]);

      await HomeWidget.updateWidget(androidName: _androidProvider);
    } on Exception catch (error) {
      // A widget that cannot be written is not a reason to fail the screen the
      // user is actually looking at.
      debugPrint('Could not update the home screen widget: $error');
    }
  }

  // "09:45 Low" — the same pairing the app's tide readout uses.
  String _tide(Beach beach, UnitFormatter formatter) {
    final tide = beach.conditions.nextTide;
    if (tide == null) return '—';
    return '${formatter.clock(tide.time)} ${tide.phase.label}';
  }

  // Value and unit as one string, since a widget tile has room for one line.
  String _reading(Reading reading) =>
      reading.unit == null ? reading.value : '${reading.value} ${reading.unit}';

  // The provider matches on these exact strings.
  String _riskKey(RiskLevel level) => switch (level) {
        RiskLevel.low => 'low',
        RiskLevel.moderate => 'moderate',
        RiskLevel.high => 'high',
      };

  bool get _isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }
}
