// File: test/support/test_settings.dart
// Description: Test helper creating in-memory SettingsStore instances populated with mock SharedPreferences data.

import 'package:beach_safety/settings/app_settings.dart';
import 'package:beach_safety/settings/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// An in-memory settings store helper for widget tests.
Future<SettingsStore> testSettingsStore([AppSettings? initial]) async {

  SharedPreferences.setMockInitialValues({});
  final store = await SettingsStore.open();
  if (initial != null) await store.write(initial);
  return store;
}
