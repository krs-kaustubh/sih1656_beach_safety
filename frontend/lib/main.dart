// File: lib/main.dart
// Description: Application entry point initializing Flutter bindings, UI system overlay styles, settings storage, Riverpod state scope, and root widget tree.

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'settings/settings_providers.dart';
import 'settings/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Content runs under the status bar, so its icons must stay light.
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // Settings are read synchronously once the app is running — units and the
  // default beach affect the very first frame — so storage has to be open
  // before the first build rather than resolved behind a loading state.
  final store = await SettingsStore.open();

  runApp(
    ProviderScope(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
      child: const BeachSafetyApp(),
    ),
  );
}

class BeachSafetyApp extends StatelessWidget {
  const BeachSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lehar',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}
