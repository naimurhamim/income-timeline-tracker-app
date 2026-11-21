import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:money_tracker/models/category.dart';
import 'package:money_tracker/models/cloud_backup_payload.dart';
import 'package:money_tracker/models/entry.dart';
import 'package:money_tracker/models/investment.dart';
import 'package:money_tracker/services/google_drive_backup_client.dart';
import 'package:money_tracker/services/update_service.dart';
import 'package:money_tracker/theme/app_colors.dart';

void main() {
  group('CloudBackupPayload', () {
    final fixedDate = DateTime(2026, 11, 20);

    test('v3 JSON round-trip preserves categories, entries, investments & currency',
        () {
      final cat = CategoryModel(
        id: 'custom-cat-1',
        name: 'Crypto',
        icon: 'currency_bitcoin',
        color: '#2D5F4F',
        createdAt: fixedDate,
      );
      final entry = EntryModel(
        id: 'entry-1',
        title: 'Bank FD Profit',
        amount: 12000,
        expectedDate: fixedDate,
        type: 'FD',
        categoryId: 'default_fd',
        createdAt: fixedDate,
        updatedAt: fixedDate,
      );
      final inv = InvestmentModel(
        id: 'inv-1',
        title: 'Sonali Bank FD',
        amount: 500000,
        type: 'FD',
        icon: 'account_balance',
        color: '#1B3A4B',
        investedDate: fixedDate,
        createdAt: fixedDate,
        updatedAt: fixedDate,
      );

      final payload = CloudBackupPayload(
        schemaVersion: 3,
        updatedAt: fixedDate,
        currencyCode: 'USD',
        categories: [cat],
        entries: [entry],
        investments: [inv],
      );

      final decoded = CloudBackupPayload.fromJsonString(payload.toJsonString());
      expect(decoded.schemaVersion, 3);
      expect(decoded.currencyCode, 'USD');
      expect(decoded.categories.length, 1);
      expect(decoded.categories.first.name, 'Crypto');
      expect(decoded.entries.length, 1);
      expect(decoded.entries.first.title, 'Bank FD Profit');
      expect(decoded.investments.length, 1);
      expect(decoded.investments.first.amount, 500000);
    });

    test('parses legacy v2 MoneyTracker JSON export without currency/schemaVersion',
        () {
      final v2Json = jsonEncode({
        'app': 'money_tracker',
        'version': 2,
        'createdAt': fixedDate.toIso8601String(),
        'categories': [
          {
            'id': 'c1',
            'name': 'Dividend',
            'icon': 'trending_up',
            'color': '#42A5F5',
            'created_at': fixedDate.toIso8601String(),
          },
        ],
        'entries': [
          {
            'id': 'e1',
            'title': 'Savings Interest',
            'amount': 3500,
            'expected_date': fixedDate.toIso8601String(),
            'type': 'Savings',
            'created_at': fixedDate.toIso8601String(),
            'updated_at': fixedDate.toIso8601String(),
          },
        ],
      });

      final parsed = CloudBackupPayload.fromJsonString(v2Json);
      expect(parsed.schemaVersion, 2);
      expect(parsed.currencyCode, 'BDT');
      expect(parsed.categories.length, 1);
      expect(parsed.entries.length, 1);
      expect(parsed.investments, isEmpty);
    });

    test('mergeWithLocal deduplicates entries, investments and custom categories',
        () {
      final local = CloudBackupPayload(
        updatedAt: fixedDate,
        currencyCode: 'BDT',
        categories: [
          CategoryModel(
            id: 'local-cat',
            name: 'Rent',
            icon: 'home',
            color: '#1B3A4B',
          ),
        ],
        entries: [
          EntryModel(
            id: 'local-e1',
            title: 'Office Rent',
            amount: 15000,
            expectedDate: fixedDate,
            type: 'Rent',
            categoryId: 'local-cat',
          ),
        ],
        investments: [
          InvestmentModel(
            id: 'local-i1',
            title: '2 Vori Gold',
            amount: 250000,
            type: 'Gold',
            investedDate: fixedDate,
          ),
        ],
      );

      final cloud = CloudBackupPayload(
        updatedAt: fixedDate.add(const Duration(hours: 1)),
        currencyCode: 'USD',
        categories: [
          CategoryModel(
            id: 'cloud-cat',
            name: 'rent',
            icon: 'home',
            color: '#1B3A4B',
          ),
        ],
        entries: [
          EntryModel(
            id: 'cloud-e1',
            title: 'office rent',
            amount: 15000,
            expectedDate: fixedDate,
            type: 'Rent',
            categoryId: 'cloud-cat',
          ),
        ],
        investments: [
          InvestmentModel(
            id: 'cloud-i1',
            title: '2 vori gold',
            amount: 250000,
            type: 'Gold',
            investedDate: fixedDate,
          ),
        ],
      );

      final merged = cloud.mergeWithLocal(local);
      expect(merged.categories.length, 1);
      expect(merged.entries.length, 1);
      expect(merged.investments.length, 1);
      expect(merged.currencyCode, 'USD');
    });

    test('computeContentFingerprint ignores updatedAt and item ordering', () {
      final invA = InvestmentModel(
        id: 'a',
        title: 'FD A',
        amount: 1000,
        type: 'FD',
        investedDate: fixedDate,
        createdAt: fixedDate,
        updatedAt: fixedDate,
      );
      final invB = InvestmentModel(
        id: 'b',
        title: 'Gold B',
        amount: 2000,
        type: 'Gold',
        investedDate: fixedDate,
        createdAt: fixedDate,
        updatedAt: fixedDate,
      );

      final first = CloudBackupPayload(
        updatedAt: fixedDate,
        currencyCode: 'BDT',
        categories: const [],
        entries: const [],
        investments: [invA, invB],
      );
      final second = CloudBackupPayload(
        updatedAt: fixedDate.add(const Duration(days: 5)),
        currencyCode: 'BDT',
        categories: const [],
        entries: const [],
        investments: [invB, invA],
      );

      expect(
        first.computeContentFingerprint(),
        equals(second.computeContentFingerprint()),
      );
    });
  });

  group('GoogleDriveBackupClient', () {
    final samplePayload = CloudBackupPayload(
      updatedAt: DateTime(2026, 11, 21),
      currencyCode: 'BDT',
      categories: const [],
      entries: const [],
      investments: [
        InvestmentModel(
          id: 'inv-1',
          title: 'Savings',
          amount: 50000,
          type: 'Savings',
          investedDate: DateTime(2026, 11, 21),
        ),
      ],
    );

    test('uploadBackup creates multipart when no file exists and patches knownFileId',
        () async {
      final calls = <String>[];
      final mockClient = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          return http.Response(jsonEncode({'files': []}), 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/upload/drive/v3/files') {
          return http.Response(jsonEncode({'id': 'drive-file-123'}), 200);
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/upload/drive/v3/files/drive-file-123') {
          return http.Response(jsonEncode({'id': 'drive-file-123'}), 200);
        }
        return http.Response('Not found', 404);
      });

      final client = GoogleDriveBackupClient(client: mockClient);
      final createdId = await client.uploadBackup(
        const {'Authorization': 'Bearer tok'},
        samplePayload,
      );
      expect(createdId, 'drive-file-123');
      expect(calls, contains('POST /upload/drive/v3/files'));

      final patchedId = await client.uploadBackup(
        const {'Authorization': 'Bearer tok'},
        samplePayload,
        knownFileId: 'drive-file-123',
      );
      expect(patchedId, 'drive-file-123');
      expect(calls, contains('PATCH /upload/drive/v3/files/drive-file-123'));
    });

    test('downloadBackup returns parsed payload and fileId', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/drive/v3/files') {
          return http.Response(
            jsonEncode({
              'files': [
                {'id': 'file-99', 'name': GoogleDriveBackupClient.backupFileName}
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/drive/v3/files/file-99') {
          return http.Response(samplePayload.toJsonString(), 200);
        }
        return http.Response('Not found', 404);
      });

      final client = GoogleDriveBackupClient(client: mockClient);
      final res = await client.downloadBackup(
        const {'Authorization': 'Bearer tok'},
      );
      expect(res.fileId, 'file-99');
      expect(res.payload, isNotNull);
      expect(res.payload!.investments.length, 1);
      expect(res.payload!.investments.first.amount, 50000);
    });

    test('throws DriveAuthExpiredException on HTTP 401', () async {
      final mockClient = MockClient(
        (_) async => http.Response('Unauthorized', 401),
      );
      final client = GoogleDriveBackupClient(client: mockClient);

      expect(
        () => client.downloadBackup(const {'Authorization': 'Bearer expired'}),
        throwsA(isA<DriveAuthExpiredException>()),
      );
    });

    test('retries HTTP 503 up to two times before succeeding', () async {
      var attempts = 0;
      final mockClient = MockClient((request) async {
        attempts++;
        if (attempts < 3) {
          return http.Response('Service Unavailable', 503);
        }
        return http.Response(
          jsonEncode({
            'files': [
              {'id': 'recovered-file-1'}
            ],
          }),
          200,
        );
      });

      final client = GoogleDriveBackupClient(
        client: mockClient,
        retryDelays: const [Duration.zero, Duration.zero],
      );
      final ids = await client.listBackupFileIds(
        const {'Authorization': 'Bearer tok'},
      );
      expect(attempts, 3);
      expect(ids, ['recovered-file-1']);
    });

    test('maps HTTP 403 accessNotConfigured JSON error to actionable message',
        () async {
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 403,
              'message':
                  'Google Drive API has not been used in project 123 before or it is disabled.',
              'errors': [
                {'reason': 'accessNotConfigured'}
              ],
            },
          }),
          403,
        ),
      );
      final client = GoogleDriveBackupClient(
        client: mockClient,
        retryDelays: const [Duration.zero],
      );

      expect(
        () => client.listBackupFileIds(const {'Authorization': 'Bearer tok'}),
        throwsA(
          isA<DriveBackupException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having(
                (e) => e.message,
                'message',
                allOf(contains('drive.googleapis.com'), contains('not enabled')),
              ),
        ),
      );
    });

    test('returns clear guidance after repeated HTTP 503 failures', () async {
      var attempts = 0;
      final mockClient = MockClient((_) async {
        attempts++;
        return http.Response('Service Unavailable', 503);
      });
      final client = GoogleDriveBackupClient(
        client: mockClient,
        retryDelays: const [Duration.zero, Duration.zero],
      );

      try {
        await client.listBackupFileIds(const {'Authorization': 'Bearer tok'});
        fail('Expected DriveBackupException');
      } on DriveBackupException catch (e) {
        expect(attempts, 3);
        expect(e.statusCode, 503);
        expect(e.message, contains('HTTP 503'));
        expect(e.message, contains('Google Drive API is enabled'));
      }
    });
  });

  group('UpdateService', () {
    test('compares semantic versions accurately', () {
      expect(UpdateService.isNewerVersion('v3.0.0', '2.1.0+7'), isTrue);
      expect(UpdateService.isNewerVersion('2.1.0', '3.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('v3.0.0', '3.0.0'), isFalse);
    });

    test('parseReleaseNotes strips raw Markdown symbols (#, *, **, `, links)',
        () {
      const md = '''
## What's New in v3.0.0
* **Glassmorphism UI:** Sleek frosted cards with *adaptive* dark contrast.
- Fixed `raw` Markdown and [GitHub Link](https://github.com/naimurhamim).
1. Private Google Drive sync ready.
''';

      final blocks = UpdateService.parseReleaseNotes(md);
      expect(blocks.length, 4);
      expect(blocks[0].kind, ReleaseNoteKind.heading);
      expect(blocks[1].kind, ReleaseNoteKind.bullet);
      expect(blocks[2].kind, ReleaseNoteKind.bullet);
      expect(blocks[3].kind, ReleaseNoteKind.numbered);
      expect(blocks[3].marker, '1.');

      for (final block in blocks) {
        final joined = block.segments.map((s) => s.text).join();
        expect(joined.contains('#'), isFalse);
        expect(joined.contains('*'), isFalse);
        expect(joined.contains('`'), isFalse);
        expect(joined.contains('['), isFalse);
      }

      expect(
        blocks[1].segments.any((s) => s.bold && s.text == 'Glassmorphism UI:'),
        isTrue,
      );
      expect(
        blocks[1].segments.any((s) => s.italic && s.text == 'adaptive'),
        isTrue,
      );
      expect(
        blocks[2].segments.any((s) => s.code && s.text == 'raw'),
        isTrue,
      );
    });
  });

  group('AppColors.adaptiveColor', () {
    test('lifts dark teal/green colors in dark mode and keeps light mode intact',
        () {
      const darkTeal = Color(0xFF1B3A4B);
      const darkGreen = Color(0xFF2D5F4F);

      expect(AppColors.adaptiveColor(darkTeal, false), equals(darkTeal));
      expect(AppColors.adaptiveColor(darkGreen, false), equals(darkGreen));

      final liftedTeal = AppColors.adaptiveColor(darkTeal, true);
      final liftedGreen = AppColors.adaptiveColor(darkGreen, true);

      expect(HSLColor.fromColor(liftedTeal).lightness, greaterThanOrEqualTo(0.62));
      expect(HSLColor.fromColor(liftedGreen).lightness, greaterThanOrEqualTo(0.62));
    });
  });
}
