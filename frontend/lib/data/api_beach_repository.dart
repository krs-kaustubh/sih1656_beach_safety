import '../models/beach.dart';
import '../models/safety_alert.dart';
import 'api_client.dart';
import 'beach_repository.dart';

/// Live repository backed by the FastAPI service.
///
/// `/beaches` and `/beaches/{id}` exist today. The alerts endpoints are
/// written against the shape the designs imply and degrade to an empty list
/// while the backend has not shipped them yet, so switching the app over to
/// the API does not have to wait for alerts to land.
class ApiBeachRepository implements BeachRepository {
  ApiBeachRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<List<Beach>> getBeaches() async {
    final json = await _client.getJson('/beaches');
    final list = (json as Map<String, dynamic>)['beaches'] as List<dynamic>;
    return list
        .map((e) => Beach.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Beach> getBeach(int id) async {
    final json = await _client.getJson('/beaches/$id');
    return Beach.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<List<SafetyAlert>> getAlerts(int beachId) async {
    try {
      final json = await _client.getJson('/beaches/$beachId/alerts');
      final list = switch (json) {
        Map<String, dynamic> map => map['alerts'] as List<dynamic>? ?? const [],
        List<dynamic> raw => raw,
        _ => const <dynamic>[],
      };
      final alerts = list
          .map((e) => SafetyAlert.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.riskLevel.index.compareTo(a.riskLevel.index));
      return alerts;
    } on BeachRepositoryException catch (e) {
      // The endpoint does not exist yet. An empty alert list is a correct and
      // safe rendering ("No Active Alerts"), so do not fail the whole screen.
      if (e.message == 'Not found.') return const [];
      rethrow;
    }
  }

  @override
  Future<SafetyAlert?> getAlert(String alertId) async {
    try {
      final json = await _client.getJson('/alerts/$alertId');
      return SafetyAlert.fromJson(json as Map<String, dynamic>);
    } on BeachRepositoryException catch (e) {
      if (e.message == 'Not found.') return null;
      rethrow;
    }
  }
}
