import '../models/beach.dart';
import '../models/safety_alert.dart';

/// Data source for beaches and alerts.
///
/// The UI depends only on this interface, so swapping [MockBeachRepository]
/// for [ApiBeachRepository] is a one-line change in `providers.dart` and needs
/// no widget edits.
abstract interface class BeachRepository {
  Future<List<Beach>> getBeaches();
  Future<Beach> getBeach(int id);

  /// Alerts for a beach, most severe first.
  Future<List<SafetyAlert>> getAlerts(int beachId);

  Future<SafetyAlert?> getAlert(String alertId);
}

/// A failure the UI knows how to present.
///
/// Wrapping transport errors here keeps `SocketException` and friends out of
/// the widget layer and gives every error state a message worth showing.
class BeachRepositoryException implements Exception {
  const BeachRepositoryException(this.message, {this.isOffline = false});

  final String message;
  final bool isOffline;

  @override
  String toString() => 'BeachRepositoryException: $message';
}
