// File: test/beach_weather_test.dart
// Description: Unit test suite verifying BeachWeather model parsing, severity vocabulary mapping, tide time handling, alerts extraction, and slug derivation.

import 'dart:convert';

import 'package:beach_safety/data/api_beach_repository.dart';
import 'package:beach_safety/models/beach.dart';
import 'package:beach_safety/models/beach_weather.dart';
import 'package:beach_safety/models/conditions.dart';
import 'package:beach_safety/models/risk_level.dart';
import 'package:beach_safety/models/safety_alert.dart';
import 'package:flutter_test/flutter_test.dart';

// Recorded payload from a real /beaches/juhu/weather endpoint response.
const _severePayload = '''

{
  "location_id": "juhu",
  "location_name": "Juhu Beach, Mumbai",
  "latitude": 19.1075, "longitude": 72.8263,
  "timestamp": "2026-08-21T17:27:53.325833+00:00",
  "data_source": "Demo Engine (Extreme Edge Cases)",
  "severity_mode": "Severe",
  "risk_title": "Severe Hazard - Storm Surge & Gale Warning",
  "risk_description": "Extreme wave heights, gale-force winds, and critical UV radiation.",
  "temperature_c": 33.5, "sea_temperature_c": 30.4, "wave_height": 4.85,
  "wind_speed": 68.4, "wind_direction": "SW",
  "uv_index": 12.2, "uv_category": "Extreme",
  "next_tide_time": "17:40", "next_tide_type": "High",
  "alerts": [
    {"alert_type": "Cyclonic Swell Advisory",
     "title": "Dangerous Rip Currents & 4.8m Swells",
     "issued_time": "2026-08-21T17:27:53.325833+00:00",
     "location_scope": "Juhu Beach, Mumbai"},
    {"alert_type": "Extreme Solar Radiation Alert",
     "title": "UV Index 12.2 (Extreme Hazard)",
     "issued_time": "2026-08-21T17:27:53.325833+00:00",
     "location_scope": "Juhu Beach, Mumbai"}
  ]
}
''';

BeachWeather _parse(String raw) =>
    BeachWeather.fromJson(jsonDecode(raw) as Map<String, dynamic>);

void main() {
  group('severity vocabulary', () {
    test('accepts the weather endpoint wording', () {
      expect(RiskLevel.fromApi('Normal'), RiskLevel.low);
      expect(RiskLevel.fromApi('Intermediate'), RiskLevel.moderate);
      expect(RiskLevel.fromApi('Severe'), RiskLevel.high);
    });

    test('still accepts the roster wording', () {
      // The service speaks both; neither may regress.
      expect(RiskLevel.fromApi('Green'), RiskLevel.low);
      expect(RiskLevel.fromApi('Amber'), RiskLevel.moderate);
      expect(RiskLevel.fromApi('Red'), RiskLevel.high);
    });

    test('still fails cautious on anything unrecognised', () {
      expect(RiskLevel.fromApi('Chartreuse'), RiskLevel.moderate);
      expect(RiskLevel.fromApi(null), RiskLevel.moderate);
    });
  });

  group('BeachWeather.fromJson', () {
    final w = _parse(_severePayload);

    test('maps the reading onto the app types', () {
      expect(w.locationId, 'juhu');
      expect(w.riskLevel, RiskLevel.high);
      expect(w.dataSource, contains('Demo Engine'));
      expect(w.conditions.waveHeightMeters, 4.85);
      expect(w.conditions.windSpeedKph, 68.4);
      expect(w.conditions.windDirection, 'SW');
    });

    test('keeps sea and air temperature apart', () {
      // temperature_c is the atmospheric provider's air reading. Showing it
      // under "Water Temp" told swimmers the sea was several degrees colder
      // than it is, so water temperature comes from the marine provider only.
      expect(w.conditions.waterTempCelsius, 30.4);
      expect(w.conditions.airTempCelsius, 33.5);
    });

    test('reports no water temperature rather than falling back to air', () {
      final noSea = _parse(_severePayload.replaceFirst('"sea_temperature_c": 30.4,', ''));
      expect(noSea.conditions.waterTempCelsius, isNull);
      expect(noSea.conditions.airTempCelsius, 33.5);
    });

    test('prefers the service UV wording over the locally derived band', () {
      // UV 12.2 is Extreme under WHO too, but the service is the authority on
      // how it describes its own reading.
      expect(w.conditions.uvCategory, 'Extreme');
      expect(w.conditions.uvLabel, 'Extreme');
    });

    test('survives a payload missing everything optional', () {
      final bare = _parse('{"location_id":"x","severity_mode":"Normal"}');
      expect(bare.riskLevel, RiskLevel.low);
      expect(bare.conditions.waveHeightMeters, 0);
      expect(bare.conditions.windSpeedKph, isNull);
      expect(bare.conditions.nextTide, isNull);
      expect(bare.alerts, isEmpty);
    });
  });

  group('next tide', () {
    test('anchors a bare wall-clock time to the reading day', () {
      final w = _parse(_severePayload);   // observed 17:27Z, tide "17:40"
      final tide = w.conditions.nextTide!;
      expect(tide.phase, TidePhase.high);
      expect(tide.time.hour, 17);
      expect(tide.time.minute, 40);
    });

    test('rolls past midnight when the time has already gone', () {
      // The *next* tide cannot be in the past: a 01:00 tide on a reading taken
      // at 17:27 must mean tomorrow morning.
      final rolled = _parse(_severePayload.replaceFirst('"17:40"', '"01:00"'));
      final tide = rolled.conditions.nextTide!;
      final observed = _parse(_severePayload).observedAt;
      expect(tide.time.isAfter(observed), isTrue);
      expect(tide.time.difference(observed).inHours, lessThan(24));
    });

    test('ignores a malformed time rather than throwing', () {
      expect(_parse(_severePayload.replaceFirst('"17:40"', '"soon"'))
          .conditions.nextTide, isNull);
    });
  });

  group('alerts', () {
    final alerts = _parse(_severePayload).toSafetyAlerts(1);

    test('carries title, scope and beach', () {
      expect(alerts, hasLength(2));
      expect(alerts.first.title, 'Dangerous Rip Currents & 4.8m Swells');
      expect(alerts.first.zoneLabel, 'Juhu Beach, Mumbai');
      expect(alerts.first.beachId, 1);
    });

    test('inherits severity, which the service does not send per alert', () {
      for (final a in alerts) {
        expect(a.riskLevel, RiskLevel.high);
        expect(a.urgency, AlertUrgency.actNow);
      }
    });

    test('picks an icon from the alert wording', () {
      expect(alerts[0].kind, AlertKind.ripCurrent);   // "Swell"/"Rip Currents"
      expect(alerts[1].kind, AlertKind.uv);           // "Solar Radiation"
    });

    test('leaves guidance empty so the detail screen hides those sections', () {
      // The service sends no what-to-do text; the UI must not print a heading
      // over nothing.
      expect(alerts.first.whatsHappening, isEmpty);
      expect(alerts.first.whatToDo, isEmpty);
      expect(alerts.first.lifeguard, isNull);
      expect(alerts.first.affectedArea, isNull);
    });

    test('mints stable, unique ids', () {
      expect(alerts.map((a) => a.id).toSet(), hasLength(2));
      expect(alerts.first.id, startsWith('juhu-'));
    });
  });

  group('slug derivation', () {
    Beach named(String name) => Beach.fromJson({'id': 1, 'name': name});

    test('prefers the slug the service sends', () {
      // The roster now carries location_id. Guessing from the name only
      // survives while a beach's slug is its first word.
      final withSlug = Beach.fromJson({
        'id': 9,
        'location_id': 'kovalam',
        'name': 'Lighthouse Beach, Kerala',
      });
      expect(ApiBeachRepository.slugFor(withSlug), 'kovalam');
    });

    test('falls back to the name when the service sends no slug', () {
      expect(ApiBeachRepository.slugFor(named('Juhu Beach, Mumbai')), 'juhu');
      expect(ApiBeachRepository.slugFor(named('Marina Beach, Chennai')), 'marina');
      expect(
        ApiBeachRepository.slugFor(named('Radhanagar Beach, Havelock')),
        'radhanagar',
      );
    });

    test('returns null rather than guessing at an empty name', () {
      expect(ApiBeachRepository.slugFor(named('')), isNull);
    });
  });

  group('applyTo', () {
    test('live risk overrides the roster fixture', () {
      // /beaches says Juhu is Red from static fixtures; if the live reading
      // says Normal, the live one has to win.
      final roster = Beach.fromJson({
        'id': 1,
        'name': 'Juhu Beach, Mumbai',
        'safety_status': 'Red',
        'water_quality': 'Poor',
      });
      expect(roster.riskLevel, RiskLevel.high);

      final calm = _parse(_severePayload.replaceFirst('"Severe"', '"Normal"'));
      final merged = calm.applyTo(roster);

      expect(merged.riskLevel, RiskLevel.low);
      expect(merged.name, 'Juhu Beach');
      // Water quality has no live source, so the roster's value is kept.
      expect(merged.conditions.waterQuality, 'Poor');
    });
  });
}
