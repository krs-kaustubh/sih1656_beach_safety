// File: lib/data/api_client.dart
// Description: HTTP network client wrapping request execution, timeout handling, base URL platform defaults, and exception translation.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'beach_repository.dart';

// Where the FastAPI backend lives. Overridable at build time via --dart-define=API_BASE_URL.
class ApiConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
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

  // Asks the service to send a WhatsApp escalation warning for a beach.
  //
  // The message text is composed server-side, so this only names the beach and
  // the recipient. Returns whether the service accepted it for delivery; a
  // false here is normal when conditions eased before the call landed.
  Future<bool> postWhatsappEscalation({
    required String slug,
    required String chatId,
    bool test = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/beaches/$slug/notify-escalation').replace(
      queryParameters: {
        'chat_id': chatId,
        if (test) 'test': 'true',
      },
    );
    try {
      final response = await _client.post(uri).timeout(_timeout);
      if (response.statusCode >= 400) return false;
      final body = jsonDecode(response.body);
      return body is Map<String, dynamic> && body['sent'] == true;
    } on SocketException {
      return false;
    } on FormatException {
      return false;
    }
  }

  void dispose() => _client.close();
}
