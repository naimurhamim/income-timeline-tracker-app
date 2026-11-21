import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/cloud_backup_payload.dart';

/// Thrown when Google Drive rejects an expired or revoked OAuth token (HTTP 401).
class DriveAuthExpiredException implements Exception {
  const DriveAuthExpiredException([
    this.message = 'Google Drive authorization expired.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Domain error thrown for Google Drive REST API failures.
class DriveBackupException implements Exception {
  const DriveBackupException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Pure REST v3 client storing one hidden backup file in the user's own `appDataFolder`.
class GoogleDriveBackupClient {
  GoogleDriveBackupClient({
    http.Client? client,
    List<Duration>? retryDelays,
  })  : _client = client ?? http.Client(),
        _retryDelays = retryDelays ??
            const [
              Duration(milliseconds: 600),
              Duration(milliseconds: 1500),
            ];

  static const String appDataScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const String backupFileName = 'money_tracker_backup.json';

  static const Duration _timeout = Duration(seconds: 25);
  static const Set<int> _retryableStatusCodes = {429, 500, 502, 503, 504};

  final http.Client _client;
  final List<Duration> _retryDelays;

  Future<List<String>> listBackupFileIds(
      Map<String, String> authHeaders) async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'spaces': 'appDataFolder',
      'q': "name='$backupFileName' and trashed=false",
      'fields': 'files(id,name,modifiedTime)',
      'orderBy': 'modifiedTime desc',
      'pageSize': '10',
    });

    final response =
        await _sendWithRetry(() => _client.get(uri, headers: authHeaders));
    _checkAuth(response.statusCode);
    if (response.statusCode != 200) {
      throw _buildDriveException('Could not list Google Drive backups', response);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final files = decoded['files'] as List<dynamic>? ?? const [];
    return files
        .whereType<Map>()
        .map((f) => f['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Downloads the newest `money_tracker_backup.json` from `appDataFolder`
  /// and cleans up any accidental duplicate files silently.
  Future<({CloudBackupPayload? payload, String? fileId})> downloadBackup(
    Map<String, String> authHeaders,
  ) async {
    final ids = await listBackupFileIds(authHeaders);
    if (ids.isEmpty) {
      return (payload: null, fileId: null);
    }

    final primaryId = ids.first;
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$primaryId', {
      'alt': 'media',
    });
    final response =
        await _sendWithRetry(() => _client.get(uri, headers: authHeaders));
    _checkAuth(response.statusCode);
    if (response.statusCode == 404) {
      return (payload: null, fileId: null);
    }
    if (response.statusCode != 200) {
      throw _buildDriveException(
        'Could not download Google Drive backup',
        response,
      );
    }

    final raw = utf8.decode(response.bodyBytes);
    final payload = CloudBackupPayload.fromJsonString(raw);

    if (ids.length > 1) {
      await _deleteDuplicateFiles(authHeaders, ids.skip(1));
    }

    return (payload: payload, fileId: primaryId);
  }

  /// Replaces the existing single backup file in `appDataFolder` via `PATCH`,
  /// creating it with `POST multipart` only when none exists yet.
  Future<String> uploadBackup(
    Map<String, String> authHeaders,
    CloudBackupPayload payload, {
    String? knownFileId,
  }) async {
    final bytes = utf8.encode(payload.toJsonString());

    if (knownFileId != null && knownFileId.isNotEmpty) {
      final patched = await _patchMedia(authHeaders, knownFileId, bytes);
      if (patched) {
        return knownFileId;
      }
    }

    final existingIds = await listBackupFileIds(authHeaders);
    if (existingIds.isNotEmpty) {
      final targetId = existingIds.first;
      final patched = await _patchMedia(authHeaders, targetId, bytes);
      if (patched) {
        if (existingIds.length > 1) {
          await _deleteDuplicateFiles(authHeaders, existingIds.skip(1));
        }
        return targetId;
      }
    }

    return _createMultipart(authHeaders, utf8.decode(bytes));
  }

  Future<bool> _patchMedia(
    Map<String, String> authHeaders,
    String fileId,
    List<int> bodyBytes,
  ) async {
    final uri = Uri.https(
      'www.googleapis.com',
      '/upload/drive/v3/files/$fileId',
      {'uploadType': 'media', 'fields': 'id'},
    );
    final headers = <String, String>{
      ...authHeaders,
      'Content-Type': 'application/json; charset=UTF-8',
    };
    final response = await _sendWithRetry(
      () => _client.patch(uri, headers: headers, body: bodyBytes),
    );
    _checkAuth(response.statusCode);
    if (response.statusCode == 404) {
      return false;
    }
    if (response.statusCode != 200) {
      throw _buildDriveException(
        'Could not update Google Drive backup',
        response,
      );
    }
    return true;
  }

  Future<String> _createMultipart(
    Map<String, String> authHeaders,
    String contentJson,
  ) async {
    const boundary = 'money_tracker_drive_backup_v1';
    final metadataJson = jsonEncode({
      'name': backupFileName,
      'parents': ['appDataFolder'],
      'mimeType': 'application/json',
    });

    final multipartBody = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadataJson\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$contentJson\r\n'
        '--$boundary--\r\n';

    final uri = Uri.https(
      'www.googleapis.com',
      '/upload/drive/v3/files',
      {'uploadType': 'multipart', 'fields': 'id'},
    );
    final headers = <String, String>{
      ...authHeaders,
      'Content-Type': 'multipart/related; boundary=$boundary',
    };
    final encodedBody = utf8.encode(multipartBody);
    final response = await _sendWithRetry(
      () => _client.post(uri, headers: headers, body: encodedBody),
    );
    _checkAuth(response.statusCode);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _buildDriveException(
        'Could not create Google Drive backup',
        response,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final createdId = decoded['id']?.toString() ?? '';
    if (createdId.isEmpty) {
      throw const DriveBackupException(
        'Google Drive did not return a backup file ID.',
      );
    }
    return createdId;
  }

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() send,
  ) async {
    for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
      try {
        final response = await send().timeout(_timeout);
        if (_retryableStatusCodes.contains(response.statusCode) &&
            attempt < _retryDelays.length) {
          final delay = _retryDelays[attempt];
          if (delay > Duration.zero) {
            await Future<void>.delayed(delay);
          }
          continue;
        }
        return response;
      } on TimeoutException {
        if (attempt >= _retryDelays.length) rethrow;
      } on SocketException {
        if (attempt >= _retryDelays.length) rethrow;
      } on http.ClientException {
        if (attempt >= _retryDelays.length) rethrow;
      }
      final delay = _retryDelays[attempt];
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
    }
    throw const DriveBackupException(
      'Google Drive request failed after multiple attempts.',
    );
  }

  static DriveBackupException _buildDriveException(
    String action,
    http.Response response,
  ) {
    String? apiMessage;
    String? reason;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map) {
          apiMessage = err['message']?.toString().trim();
          final errors = err['errors'];
          if (errors is List && errors.isNotEmpty && errors.first is Map) {
            reason = (errors.first as Map)['reason']?.toString().trim();
          }
        }
      }
    } catch (_) {
      // Ignore malformed/empty error JSON bodies.
    }

    final lowerMsg = (apiMessage ?? '').toLowerCase();
    if (response.statusCode == 403 &&
        (reason == 'accessNotConfigured' ||
            lowerMsg.contains('has not been used in project') ||
            lowerMsg.contains('is disabled') ||
            lowerMsg.contains('google drive api'))) {
      return const DriveBackupException(
        'Google Drive API is not enabled for this Google Cloud project yet. Enable drive.googleapis.com in Google Cloud Console and try again.',
        statusCode: 403,
      );
    }

    if (response.statusCode == 503) {
      return const DriveBackupException(
        'Google Drive service is temporarily unavailable (HTTP 503). If this continues, make sure Google Drive API is enabled in Google Cloud Console and retry shortly.',
        statusCode: 503,
      );
    }

    if (apiMessage != null && apiMessage.isNotEmpty) {
      return DriveBackupException(
        '$action (HTTP ${response.statusCode}): $apiMessage',
        statusCode: response.statusCode,
      );
    }

    return DriveBackupException(
      '$action (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  Future<void> _deleteDuplicateFiles(
    Map<String, String> authHeaders,
    Iterable<String> fileIds,
  ) async {
    for (final id in fileIds) {
      try {
        final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$id');
        await _client.delete(uri, headers: authHeaders).timeout(_timeout);
      } catch (_) {
        // Best-effort cleanup; primary backup already succeeded.
      }
    }
  }

  static void _checkAuth(int statusCode) {
    if (statusCode == 401) {
      throw const DriveAuthExpiredException();
    }
  }
}
