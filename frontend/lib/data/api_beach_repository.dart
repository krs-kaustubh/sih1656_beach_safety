import '../models/beach.dart';
import '../models/beach_weather.dart';
import '../models/safety_alert.dart';
import 'api_client.dart';
import 'beach_repository.dart';

/// Live repository backed by the FastAPI service.
///
/// Two endpoints are combined:
///  * `/beaches` — the roster: ids, names, coordinates. Its `safety_status`
///    comes from static fixtures, so it is not trusted for risk.
///  * `/beaches/{slug}/weather` — the live reading: risk, conditions, alerts.
///
/// The roster is fetched once and each beach enriched with its live reading,
/// so the map and the search sheet show current risk rather than fixture data.
class ApiBeachRepository implements BeachRepository {
  ApiBeachRepository({ApiClient? client, this.freshness = const Duration(minutes: 2)})
      : _client = client ?? ApiClient();

  final ApiClient _client;

  /// How long a reading is reused before being refetched. Home and Alerts both
  /// need the same payload, and pull-to-refresh invalidates it anyway.
  final Duration freshness;

  final Map<int, _Cached> _weather = {};

  @override
  Future<List<Beach>> getBeaches() async {
    final json = await _client.getJson('/beaches');
    final list = (json as Map<String, dynamic>)['beaches'] as List<dynamic>;
    final roster = list
        .map((e) => Beach.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    // Enrich in parallel: a handful of beaches means a handful of requests,
    // and doing them in sequence would show a visibly slow first paint.
    final readings = await Future.wait(roster.map(_tryReadingFor));

    return [
      for (final (index, beach) in roster.indexed)
        readings[index]?.applyTo(beach) ?? beach,
    ];
  }

  @override
  Future<Beach> getBeach(int id) async {
    final json = await _client.getJson('/beaches/$id');
    final beach = Beach.fromJson(json as Map<String, dynamic>);
    final reading = await _tryReadingFor(beach);
    return reading?.applyTo(beach) ?? beach;
  }

  @override
  Future<List<SafetyAlert>> getAlerts(int beachId) async {
    final cached = _weather[beachId];
    final reading = cached != null && cached.isFresh(freshness)
        ? cached.value
        : await _readingFor(await getBeach(beachId));

    final alerts = reading.toSafetyAlerts(beachId)
      ..sort((a, b) => b.riskLevel.index.compareTo(a.riskLevel.index));
    return alerts;
  }

  @override
  Future<SafetyAlert?> getAlert(String alertId) async {
    // Alerts have no endpoint of their own; ids are minted from the reading
    // they came in, so the beach is recoverable from the id's prefix.
    final slug = alertId.split('-').first;
    for (final entry in _weather.entries) {
      if (entry.value.value.locationId == slug) {
        return entry.value.value
            .toSafetyAlerts(entry.key)
            .where((a) => a.id == alertId)
            .firstOrNull;
      }
    }
    return null;
  }

  /// A live reading, or null if this beach has none available.
  ///
  /// One beach's feed failing should not blank the whole roster, so the
  /// failure is absorbed and that beach falls back to what `/beaches` said
  /// about it. That is still the service's own answer, just a static one.
  Future<BeachWeather?> _tryReadingFor(Beach beach) async {
    try {
      return await _readingFor(beach);
    } on Exception {
      return null;
    }
  }

  /// Fetches (or reuses) the live reading for a beach.
  Future<BeachWeather> _readingFor(Beach beach) async {
    final cached = _weather[beach.id];
    if (cached != null && cached.isFresh(freshness)) return cached.value;

    final slug = slugFor(beach);
    if (slug == null) {
      throw BeachRepositoryException(
        'No live weather feed is configured for ${beach.name}.',
      );
    }

    final json = await _client.getJson('/beaches/$slug/weather');
    final reading = BeachWeather.fromJson(json as Map<String, dynamic>);
    _weather[beach.id] = _Cached(reading, DateTime.now());
    return reading;
  }

  /// The weather endpoint's key for a beach.
  ///
  /// The roster now carries `location_id`, so this is normally just read off
  /// the response. The name-derived fallback remains for older builds of the
  /// service that predate that field; it works only while a beach's slug is
  /// its first word, which is why the service sending it is the real fix.
  static String? slugFor(Beach beach) {
    final provided = beach.locationId?.trim();
    if (provided != null && provided.isNotEmpty) return provided;

    final first = beach.name.split(RegExp(r'[\s,]+')).firstOrNull;
    if (first == null || first.isEmpty) return null;
    return first.toLowerCase();
  }

  void dispose() => _client.dispose();
}

class _Cached {
  const _Cached(this.value, this.at);
  final BeachWeather value;
  final DateTime at;

  bool isFresh(Duration ttl) => DateTime.now().difference(at) < ttl;
}
