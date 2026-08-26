// File: lib/data/mock_data.dart
// Description: Static mock dataset supplying fallback beach models, weather readings, and safety alerts for offline demo mode and testing.

import '../models/beach.dart';
import '../models/conditions.dart';
import '../models/risk_level.dart';
import '../models/safety_alert.dart';

// Observed conditions, not invented ones.
//
// Wave height, ocean current, wind, UV and sea-surface temperature were read
// from Open-Meteo's marine and forecast APIs at each beach's own coordinates
// on 26 August 2026, 14:15 IST. Tide turns are published harmonic predictions
// from tidetime.org for the same date, taken at each beach's reference port:
// Mumbai for Juhu, Chennai for Marina, Port Blair for Radhanagar (Havelock has
// no table of its own) and Karwar for Om.
//
// Water quality is the one field with no live feed behind it. The values here
// are the standing characterisations of these beaches, not a reading taken on
// the day, and they are the reason Juhu carries an advisory while the sea
// itself is unremarkable.
//
// Risk levels and the alert list below are derived from those numbers using
// the thresholds in backend/README.md, so nothing here claims a hazard the
// measurements do not support. Re-reading the sources on a later date will
// move these figures; they describe one afternoon, not a permanent state.
abstract final class MockData {

  static DateTime _todayAt(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static List<Beach> beaches() => [
        Beach(
          id: 1,
          name: 'Juhu Beach',
          region: 'Mumbai, West Coast',
          latitude: 19.0988,
          longitude: 72.8267,
          riskLevel: RiskLevel.moderate,
          riskSummary:
              'Sea conditions are moderate, but water quality is poor. Avoid swallowing '
              'water and rinse off after entering the sea.',
          conditions: Conditions(
            waveHeightMeters: 1.44,
            currentSpeedKnots: 0.8,
            windSpeedKph: 15.5,
            windDirection: 'W',
            uvIndex: 4.0,
            nextTide: TideInfo(time: _todayAt(17, 40), phase: TidePhase.high),
            waterTempCelsius: 29.6,
            airTempCelsius: 29.1,
            waterQuality: 'Poor',
          ),
        ),
        Beach(
          id: 2,
          name: 'Marina Beach',
          region: 'Chennai, East Coast',
          latitude: 13.0499,
          longitude: 80.2824,
          riskLevel: RiskLevel.low,
          riskSummary:
              'Calm sea and light winds. Conditions are safe for swimming in the '
              'patrolled area.',
          conditions: Conditions(
            waveHeightMeters: 0.86,
            currentSpeedKnots: 0.4,
            windSpeedKph: 8.4,
            windDirection: 'WSW',
            uvIndex: 3.0,
            nextTide: TideInfo(time: _todayAt(20, 14), phase: TidePhase.low),
            waterTempCelsius: 30.0,
            airTempCelsius: 35.0,
            waterQuality: 'Moderate',
          ),
        ),
        Beach(
          id: 3,
          name: 'Radhanagar Beach',
          region: 'Havelock Island, Andaman',
          latitude: 11.9841,
          longitude: 92.9548,
          riskLevel: RiskLevel.moderate,
          riskSummary:
              'A brisk southwesterly is blowing across the bay. The water is clean and '
              'the swell is small, but expect chop and drift.',
          conditions: Conditions(
            waveHeightMeters: 1.04,
            currentSpeedKnots: 0.3,
            windSpeedKph: 26.7,
            windDirection: 'WSW',
            uvIndex: 1.8,
            nextTide: TideInfo(time: _todayAt(15, 2), phase: TidePhase.high),
            waterTempCelsius: 29.1,
            airTempCelsius: 29.2,
            waterQuality: 'Excellent',
          ),
        ),
        Beach(
          id: 4,
          name: 'Om Beach',
          region: 'Gokarna, West Coast',
          latitude: 14.5106,
          longitude: 74.3170,
          riskLevel: RiskLevel.moderate,
          riskSummary:
              'The largest surf of the four beaches, with a high UV index. Clean water, '
              'but stay within your depth and cover up on the sand.',
          conditions: Conditions(
            waveHeightMeters: 1.82,
            currentSpeedKnots: 0.2,
            windSpeedKph: 16.0,
            windDirection: 'W',
            uvIndex: 7.6,
            nextTide: TideInfo(time: _todayAt(16, 36), phase: TidePhase.high),
            waterTempCelsius: 28.8,
            airTempCelsius: 28.1,
            waterQuality: 'Excellent',
          ),
        ),
      ];

  static const _ripCurrentTip =
      'If caught in a rip current, stay calm and swim parallel to shore.';

  // One alert per condition that actually crosses a threshold in the readings
  // above. Marina crosses none, so it has no alerts.
  static List<SafetyAlert> alerts() => [
        // Juhu — water quality is the only factor here that crosses a threshold.
        SafetyAlert(
          id: 'juhu-water-quality',
          beachId: 1,
          kind: AlertKind.waterQuality,
          riskLevel: RiskLevel.moderate,
          urgency: AlertUrgency.advisory,
          title: 'Poor Water Quality',
          summary: 'Bathing water at Juhu is rated Poor.',
          zoneLabel: 'Whole Coastline',
          issuedAt: _todayAt(6, 0),
          validUntil: _todayAt(21, 0),
          whatsHappening:
              'Juhu’s bathing water carries a standing Poor rating from stormwater '
              'and sewage outfalls along the shore, and the monsoon runoff season makes '
              'that worse. The sea itself is unremarkable today — 1.4 m of swell '
              'and a 15 km/h westerly — so the hazard here is what is in the water, '
              'not what it is doing.',
          whatToDo: const [
            'Do not swallow seawater, and keep it out of open cuts.',
            'Rinse with fresh water as soon as you come out.',
            'Keep small children out of the water after heavy rain.',
          ],
          lifeguard: const LifeguardStatus(towerName: 'Tower 3', onDuty: true),
          affectedArea: const AffectedArea(
            zoneName: 'Whole Coastline',
            description: 'All beach access points.',
            latitude: 19.0955,
            longitude: 72.8258,
          ),
          conditions: Conditions(
            waveHeightMeters: 1.44,
            windSpeedKph: 15.5,
            windDirection: 'W',
            nextTide: TideInfo(time: _todayAt(17, 40), phase: TidePhase.high),
            waterTempCelsius: 29.6,
            waterQuality: 'Poor',
          ),
          safetyTip:
              'Water that looks clean can still carry bacteria. Rinse off after every swim.',
        ),

        // Radhanagar — 26.7 km/h clears the 20 km/h caution threshold.
        SafetyAlert(
          id: 'radhanagar-wind',
          beachId: 3,
          kind: AlertKind.wind,
          riskLevel: RiskLevel.moderate,
          urgency: AlertUrgency.advisory,
          title: 'Breezy Conditions',
          summary: 'Southwesterly wind at 27 km/h across the bay.',
          zoneLabel: 'Whole Coastline',
          issuedAt: _todayAt(9, 0),
          validUntil: _todayAt(19, 0),
          whatsHappening:
              'A steady southwesterly is running at about 27 km/h, enough to raise chop '
              'and push floating objects along the shore. The swell behind it is small '
              'at roughly 1 m and the water is clean; the wind is the thing to plan '
              'around, not the sea state.',
          whatToDo: const [
            'Avoid inflatables and paddle craft — the wind will carry them.',
            'Secure umbrellas, mats and light belongings on the sand.',
            'Expect to drift along the beach while swimming; check your position often.',
          ],
          lifeguard: const LifeguardStatus(towerName: 'Tower 1', onDuty: true),
          affectedArea: const AffectedArea(
            zoneName: 'Whole Coastline',
            description: 'The full length of the bay.',
            latitude: 11.9820,
            longitude: 92.9540,
          ),
          conditions: Conditions(
            waveHeightMeters: 1.04,
            windSpeedKph: 26.7,
            windDirection: 'WSW',
            nextTide: TideInfo(time: _todayAt(15, 2), phase: TidePhase.high),
            waterTempCelsius: 29.1,
          ),
          safetyTip:
              'Offshore winds can push inflatables out to sea within minutes.',
        ),

        // Om — UV 7.6 sits in the High band, and 1.82 m is the largest surf here.
        SafetyAlert(
          id: 'om-uv',
          beachId: 4,
          kind: AlertKind.uv,
          riskLevel: RiskLevel.moderate,
          urgency: AlertUrgency.advisory,
          title: 'High UV',
          summary: 'UV index 7.6 (High) this afternoon.',
          zoneLabel: 'Whole Coastline',
          issuedAt: _todayAt(11, 0),
          validUntil: _todayAt(16, 0),
          timeStyle: AlertTimeStyle.window,
          whatsHappening:
              'The UV index at Om Beach is 7.6, in the High band, and is the strongest '
              'reading of the four beaches today. Unprotected skin can burn within about '
              'half an hour at this level.',
          whatToDo: const [
            'Seek shade between 11 AM and 4 PM.',
            'Apply SPF 30+ sunscreen and reapply every two hours.',
            'Wear sunglasses, a hat and a rash guard in the water.',
          ],
          lifeguard: const LifeguardStatus(towerName: 'Tower 1', onDuty: true),
          affectedArea: const AffectedArea(
            zoneName: 'Whole Coastline',
            description: 'All beach access points.',
          ),
          safetyTip: 'Sunscreen washes off in water. Reapply after every swim.',
        ),
        SafetyAlert(
          id: 'om-surf',
          beachId: 4,
          kind: AlertKind.ripCurrent,
          riskLevel: RiskLevel.moderate,
          urgency: AlertUrgency.advisory,
          title: 'Moderate Surf',
          summary: 'Swell running at 1.8 m along the beach.',
          zoneLabel: 'Whole Coastline',
          issuedAt: _todayAt(8, 30),
          validUntil: _todayAt(18, 0),
          whatsHappening:
              'Swell is running at about 1.8 m, the largest of the four beaches today, '
              'on an 8-second period from the west. Surf this size breaks hard enough to '
              'knock an adult off their feet in the shore break and can set up rips '
              'between the rock headlands at either end of the cove.',
          whatToDo: const [
            'Swim between the headlands, not beside them.',
            'If caught in a current, swim parallel to shore, not against it.',
            'Keep young swimmers within arm’s reach.',
          ],
          lifeguard: const LifeguardStatus(towerName: 'Tower 1', onDuty: true),
          affectedArea: const AffectedArea(
            zoneName: 'Whole Coastline',
            description: 'Strongest near the rock headlands at each end.',
            latitude: 14.5106,
            longitude: 74.3170,
          ),
          conditions: Conditions(
            waveHeightMeters: 1.82,
            windSpeedKph: 16.0,
            windDirection: 'W',
            nextTide: TideInfo(time: _todayAt(16, 36), phase: TidePhase.high),
            waterTempCelsius: 28.8,
          ),
          safetyTip: _ripCurrentTip,
        ),
      ];
}
