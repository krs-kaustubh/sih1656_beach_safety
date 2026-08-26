// File: lib/data/api_client.dart
// Description: HTTP network client wrapping request execution, timeout handling, base URL platform defaults, and exception translation.

import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'beach_repository.dart';

/// Where the FastAPI backend lives.
///
/// Overridable at build time so a demo build can point at a LAN address
/// without a code edit:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000
///
/// The default resolves per platform because `localhost` on a device does not
/// mean the developer's machine: the Android emulator reaches the host through
/// the 10.0.2.2 alias, while the iOS simulator shares the host's loopback.
/// On web, `dart:io`'s Platform is unavailable entirely, so kIsWeb is checked
/// first — Chrome and the backend both run on the developer's machine, so
/// plain loopback is correct there.
class ApiConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }
}

// Thin JSON wrapper over HTTP client translating transport and status failures into BeachRepositoryException.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;


  final http.Client _client;
  final String _baseUrl;

  static const _timeout = Duration(seconds: 10);

  Future<dynamic> getJson(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode == 404) {
        throw const BeachRepositoryException('Not found.');
      }
      if (response.statusCode >= 400) {
        throw BeachRepositoryException(
          'The server returned ${response.statusCode}.',
        );
      }
      return jsonDecode(response.body);
    } on SocketException {
      throw const BeachRepositoryException(
        'Cannot reach the server. Check your connection.',
        isOffline: true,
      );
    } on FormatException {
      throw const BeachRepositoryException('The server sent an unreadable response.');
    }
  }

  /// POST with query parameters, no request body.
  ///
  /// `check-safety` takes its inputs as query params (matches the FastAPI
  /// route signature), so this builds the URI with [query] rather than a
  /// JSON body.
  Future<dynamic> postQuery(String path, Map<String, String> query) async {
    final uri =
        Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    try {
      final response = await _client.post(uri).timeout(_timeout);

      if (response.statusCode == 404) {
        throw const BeachRepositoryException('Not found.');
      }
      if (response.statusCode >= 400) {
        throw BeachRepositoryException(
          'The server returned ${response.statusCode}.',
        );
      }
      return jsonDecode(response.body);
    } on SocketException {
      throw const BeachRepositoryException(
        'Cannot reach the server. Check your connection.',
        isOffline: true,
      );
    } on FormatException {
      throw const BeachRepositoryException('The server sent an unreadable response.');
    }
  }

  void dispose() => _client.close();
}
