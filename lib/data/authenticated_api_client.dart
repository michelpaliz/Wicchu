import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthenticatedApiClient {
  AuthenticatedApiClient({
    http.Client? client,
    FlutterSecureStorage? storage,
    String? apiBaseUrl,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
       _apiBaseUrl =
           apiBaseUrl ??
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: 'https://hexora.dev',
           );

  static const accessTokenKey = 'wicchu_access_token';
  static const refreshTokenKey = 'wicchu_refresh_token';

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String _apiBaseUrl;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) => _send('POST', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) => _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> upload(
    String path, {
    required List<int> bytes,
    required String filename,
    required String mimeType,
    bool allowRefresh = true,
  }) async {
    final token = await _storage.read(key: accessTokenKey);
    if (token == null || token.isEmpty) {
      throw const ApiException('Please sign in again.', statusCode: 401);
    }
    final request =
        http.MultipartRequest('POST', Uri.parse('$_apiBaseUrl$path'))
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['Accept'] = 'application/json'
          ..files.add(
            http.MultipartFile.fromBytes(
              'media',
              bytes,
              filename: filename,
              contentType: MediaType.parse(mimeType),
            ),
          );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401 && allowRefresh && await _refreshToken()) {
      return upload(
        path,
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
        allowRefresh: false,
      );
    }
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded is Map<String, dynamic>
            ? decoded['message'] as String? ?? 'Media upload failed.'
            : 'Media upload failed.',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('The server returned an invalid response.');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool allowRefresh = true,
  }) async {
    final token = await _storage.read(key: accessTokenKey);
    if (token == null || token.isEmpty) {
      throw const ApiException('Please sign in again.', statusCode: 401);
    }

    final uri = Uri.parse('$_apiBaseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ),
      'PUT' => await _client.put(uri, headers: headers, body: jsonEncode(body)),
      'PATCH' => await _client.patch(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ),
      'DELETE' => await _client.delete(uri, headers: headers),
      _ => throw ArgumentError.value(method, 'method'),
    };

    if (response.statusCode == 401 && allowRefresh && await _refreshToken()) {
      return _send(method, path, body: body, allowRefresh: false);
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message'] as String?
          : null;
      throw ApiException(
        message ?? 'The server could not complete the request.',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('The server returned an invalid response.');
    }
    return decoded;
  }

  Future<bool> _refreshToken() async {
    final refreshToken = await _storage.read(key: refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final response = await _client.post(
      Uri.parse('$_apiBaseUrl/api/auth/refresh'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    if (response.statusCode != 200) {
      await Future.wait([
        _storage.delete(key: accessTokenKey),
        _storage.delete(key: refreshTokenKey),
      ]);
      return false;
    }
    final body = jsonDecode(response.body);
    final accessToken = body is Map<String, dynamic>
        ? body['accessToken'] as String?
        : null;
    if (accessToken == null || accessToken.isEmpty) return false;
    await _storage.write(key: accessTokenKey, value: accessToken);
    return true;
  }
}
