import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/data_repository.dart';
import '../models/category.dart';
import '../models/entry.dart';

/// Handles JSON export and import for guest/offline users.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  DataRepository get _repo => DataStore.instance.repo;

  // ═══════════════════════════════════
  // Export
  // ═══════════════════════════════════

  /// Exports all data to a JSON file and opens the system share sheet.
  Future<String?> exportToJson() async {
    try {
      final categories = await _repo.getCategories();
      final entries = await _repo.getEntries();

      final data = {
        'app': 'money_tracker',
        'version': 2,
        'createdAt': DateTime.now().toIso8601String(),
        'categories': categories.map((c) => c.toMap()).toList(),
        'entries': entries.map((e) => e.toMap()).toList(),
      };

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/money_tracker_export_$timestamp.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));

      // Open share sheet
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

  // ═══════════════════════════════════
  // Import
  // ═══════════════════════════════════

  /// Lets the user pick a JSON file and merges it into the current repository.
  /// Returns the number of records imported.
  Future<({int categories, int entries, int skipped})> importFromJson() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) {
      return (categories: 0, entries: 0, skipped: 0);
    }

    final path = result.files.single.path;
    if (path == null) return (categories: 0, entries: 0, skipped: 0);

    final file = File(path);
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic> ||
        (decoded['entries'] is! List && decoded['categories'] is! List)) {
      throw const FormatException('This is not a Money Tracker backup file.');
    }
    final data = decoded;

    final rawCategories = data['categories'] as List<dynamic>? ?? [];
    final rawEntries = data['entries'] as List<dynamic>? ?? [];

    final categories = <CategoryModel>[];
    for (final raw in rawCategories) {
      try {
        categories.add(CategoryModel.fromMap(raw as Map<String, dynamic>));
      } catch (e) {
        debugPrint('Skipping invalid category during import: $e');
      }
    }

    final entries = <EntryModel>[];
    for (final raw in rawEntries) {
      try {
        entries.add(EntryModel.fromMap(raw as Map<String, dynamic>));
      } catch (e) {
        debugPrint('Skipping invalid entry during import: $e');
      }
    }

    final repo = _repo;
    final merged = mergeIncoming(
      existing: await repo.getCategories(),
      existingEntries: await repo.getEntries(),
      incomingCategories: categories,
      incomingEntries: entries,
    );
    await repo.saveAll(categories: merged.categories, entries: merged.entries);

    return (
      categories: merged.categories.length,
      entries: merged.entries.length,
      skipped: merged.skippedDuplicates,
    );
  }
}
