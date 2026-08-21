import 'package:beach_safety/settings/app_settings.dart';
import 'package:beach_safety/settings/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An in-memory settings store for widget tests.
///
/// `setMockInitialValues` gives a real SharedPreferences backed by a map, so
/// persistence behaviour is exercised rather than stubbed out.
///
/// Returns the store rather than a ready-made override because Riverpod 3
/// does not export the `Override` type, so it cannot be named here.
Future<SettingsStore> testSettingsStore([AppSettings? initial]) async {
  SharedPreferences.setMockInitialValues({});
  final store = await SettingsStore.open();
  if (initial != null) await store.write(initial);
  return store;
}
