@Tags(['live'])
library;

// Printing is the point here: this test exists to show what the live service
// actually returned, so a human running it can eyeball the values.
// ignore_for_file: avoid_print

import 'package:beach_safety/data/api_beach_repository.dart';
import 'package:beach_safety/data/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the client against a real running service.
///
///   cd backend && USE_MOCK_DATA=false .venv/bin/python -m uvicorn main:app --port 8000
///   cd frontend && flutter test --run-skipped -t live test/api_integration_test.dart
///
/// Skipped by default: it needs a service on localhost and real network calls
/// to the weather providers, so it must never gate a normal test run.
void main() {
  late ApiBeachRepository repo;

  setUp(() {
    repo = ApiBeachRepository(
      client: ApiClient(baseUrl: 'http://127.0.0.1:8000'),
    );
  });
  tearDown(() => repo.dispose());

  test('fetches the roster and enriches it with live readings', () async {
    final beaches = await repo.getBeaches();
    expect(beaches, isNotEmpty);

    for (final b in beaches) {
      print('${b.name} (${b.region}) — ${b.riskLevel.label}'
          '  wave ${b.conditions.waveHeightMeters}m'
          '  wind ${b.conditions.windSpeedKph}km/h ${b.conditions.windDirection}'
          '  uv ${b.conditions.uvIndex} ${b.conditions.uvLabel}'
          '  tide ${b.conditions.nextTide?.time} ${b.conditions.nextTide?.phase.label}'
          '  temp ${b.conditions.waterTempCelsius}C');

      expect(b.name, isNotEmpty);
      expect(b.conditions.waveHeightMeters, greaterThanOrEqualTo(0));
    }

    // The live reading must actually have replaced the roster's fixtures.
    final enriched = beaches.where((b) => b.conditions.windSpeedKph != null);
    expect(enriched, isNotEmpty,
        reason: 'no beach picked up live wind — enrichment is not happening');
  });

  test('derives the weather slug from every roster name', () async {
    final beaches = await repo.getBeaches();
    for (final b in beaches) {
      expect(ApiBeachRepository.slugFor(b), isNotNull,
          reason: 'no slug derived for ${b.name}');
    }
  });

  test('the next tide is always in the future', () async {
    final beaches = await repo.getBeaches();
    for (final b in beaches) {
      final tide = b.conditions.nextTide;
      if (tide == null) continue;
      expect(tide.time.isAfter(DateTime.now().subtract(const Duration(hours: 1))),
          isTrue,
          reason: '${b.name} next tide ${tide.time} is in the past');
    }
  });

  test('alerts parse and inherit the beach severity', () async {
    final beaches = await repo.getBeaches();
    for (final b in beaches) {
      final alerts = await repo.getAlerts(b.id);
      print('${b.name}: ${alerts.length} alert(s)');
      for (final a in alerts) {
        expect(a.title, isNotEmpty);
        expect(a.beachId, b.id);
        expect(a.riskLevel, b.riskLevel);
      }
    }
  });
}
