import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/data_repository.dart';
import '../models/cloud_backup_payload.dart';
import '../providers/currency_provider.dart';

/// Handles offline JSON export and Merge / Replace import.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  DataRepository get _repo => DataStore.instance.repo;

  /// Exports all categories, entries, investments, and currency to JSON and shares it.
  Future<String?> exportToJson({String? currencyCode}) async {
    try {
      final categories = await _repo.getCategories();
      final entries = await _repo.getEntries();
      final investments = await _repo.getInvestments();

      var effectiveCurrency = currencyCode;
      if (effectiveCurrency == null || effectiveCurrency.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          effectiveCurrency = prefs.getString('currency_code') ?? 'BDT';
        } catch (_) {
          effectiveCurrency = 'BDT';
        }
      }

      final payload = CloudBackupPayload(
        schemaVersion: 3,
        updatedAt: DateTime.now(),
        currencyCode: effectiveCurrency,
        categories: categories,
        entries: entries,
        investments: investments,
      );

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/money_tracker_export_$timestamp.json');
      await file.writeAsString(payload.toJsonString(pretty: true));

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Money Tracker data backup',
        ),
      );

      return file.path;
    } catch (e) {
      debugPrint('Export failed: $e');
      rethrow;
    }
  }

  /// Opens the file picker and parses a v2 or v3 MoneyTracker JSON backup.
  /// Returns `null` if cancelled by the user.
  Future<CloudBackupPayload?> pickBackupFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path;
    if (path == null) return null;

    final content = await File(path).readAsString();
    if (content.trim().isEmpty) return null;
    return CloudBackupPayload.fromJsonString(content);
  }

  /// Applies [payload] using either deduplicating Merge or full Replace.
  Future<({int categories, int entries, int investments, int skipped})>
      applyBackup(
    CloudBackupPayload payload, {
    required bool merge,
    CurrencyProvider? currencyProvider,
  }) async {
    final repo = _repo;
    if (!merge) {
      await repo.clearAll();
      final customCats =
          payload.categories.where((c) => !c.isDefault).toList();
      await repo.saveAll(
        categories: customCats,
        entries: payload.entries,
        investments: payload.investments,
      );
      if (currencyProvider != null && payload.currencyCode.isNotEmpty) {
        await currencyProvider.applyRestoredCurrency(payload.currencyCode);
      }
      return (
        categories: customCats.length,
        entries: payload.entries.length,
        investments: payload.investments.length,
        skipped: 0,
      );
    }

    final existingCats = await repo.getCategories();
    final existingEntries = await repo.getEntries();
    final existingInvestments = await repo.getInvestments();

    final merged = mergeIncoming(
      existing: existingCats,
      existingEntries: existingEntries,
      existingInvestments: existingInvestments,
      incomingCategories: payload.categories,
      incomingEntries: payload.entries,
      incomingInvestments: payload.investments,
    );

    await repo.saveAll(
      categories: merged.categories,
      entries: merged.entries,
      investments: merged.investments,
    );

    if (currencyProvider != null &&
        payload.currencyCode.isNotEmpty &&
        payload.currencyCode != 'BDT' &&
        currencyProvider.code == 'BDT') {
      await currencyProvider.applyRestoredCurrency(payload.currencyCode);
    }

    return (
      categories: merged.categories.length,
      entries: merged.entries.length,
      investments: merged.investments.length,
      skipped: merged.skippedDuplicates,
    );
  }
}
