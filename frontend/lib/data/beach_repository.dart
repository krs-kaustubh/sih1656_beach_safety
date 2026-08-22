// File: lib/data/beach_repository.dart
// Description: Abstract interface defining the repository contract for retrieving beach data and safety alerts, along with repository exception definitions.

import '../models/beach.dart';
import '../models/safety_alert.dart';

// Data source interface for beaches and alerts.
abstract interface class BeachRepository {
  Future<List<Beach>> getBeaches();
  Future<Beach> getBeach(int id);

  // Alerts for a beach, most severe first.
  Future<List<SafetyAlert>> getAlerts(int beachId);

  Future<SafetyAlert?> getAlert(String alertId);

  // Drops any cached readings so the next fetch goes to the source.
  //
  // Pull-to-refresh has to mean this. Without it the repository would replay
  // a reading it already holds and the user would be told nothing changed
  // when it had — including a rating that had risen to High.
  void invalidateCache();
}

// Exception failure state presented by the UI.
class BeachRepositoryException implements Exception {

  const BeachRepositoryException(this.message, {this.isOffline = false});

  final String message;
  final bool isOffline;

  @override
  String toString() => 'BeachRepositoryException: $message';
}
