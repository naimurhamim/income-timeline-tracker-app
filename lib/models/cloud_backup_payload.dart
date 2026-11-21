import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/data_repository.dart';
import 'category.dart';
import 'entry.dart';
import 'investment.dart';

/// Complete, self-contained MoneyTracker backup snapshot for Google Drive
/// (`appDataFolder`) and offline JSON Export/Import.
@immutable
class CloudBackupPayload {
  static const String backupAppId = 'money_tracker';

  const CloudBackupPayload({
    this.schemaVersion = 3,
    required this.updatedAt,
    this.currencyCode = 'BDT',
    required this.categories,
    required this.entries,
    required this.investments,
  });

  final int schemaVersion;
  final DateTime updatedAt;
  final String currencyCode;
  final List<CategoryModel> categories;
  final List<EntryModel> entries;
  final List<InvestmentModel> investments;

  bool get isMeaningfullyEmpty =>
      entries.isEmpty &&
      investments.isEmpty &&
      categories.where((c) => !c.isDefault).isEmpty;

  Map<String, dynamic> toBackupJson() {
    final nowIso = updatedAt.toIso8601String();
    return {
      'app': backupAppId,
      'version': schemaVersion,
      'schemaVersion': schemaVersion,
      'createdAt': nowIso,
      'updatedAt': nowIso,
      'currency': currencyCode,
      'categories': categories.map((c) => c.toMap()).toList(),
      'entries': entries.map((e) => e.toMap()).toList(),
      'investments': investments.map((i) => i.toMap()).toList(),
    };
  }

  String toJsonString({bool pretty = false}) {
    final map = toBackupJson();
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(map);
    }
    return jsonEncode(map);
  }

  /// Parses v2 (legacy) or v3 MoneyTracker JSON backups cleanly.
  factory CloudBackupPayload.fromBackupJson(Map<String, dynamic> map) {
    final appTag = map['app']?.toString();
    if (appTag != null && appTag.isNotEmpty && appTag != backupAppId) {
      throw const FormatException('This is not a Money Tracker backup file.');
    }

    final hasSection = map['entries'] is List ||
        map['categories'] is List ||
        map['investments'] is List;
    if (!hasSection) {
      throw const FormatException('This is not a Money Tracker backup file.');
    }

    final rawCategories = map['categories'] as List<dynamic>? ?? const [];
    final categories = <CategoryModel>[];
    for (final raw in rawCategories) {
      if (raw is Map) {
        try {
          categories.add(CategoryModel.fromMap(Map<String, dynamic>.from(raw)));
        } catch (e) {
          debugPrint('Skipping invalid category during parse: $e');
        }
      }
    }

    final rawEntries = map['entries'] as List<dynamic>? ?? const [];
    final entries = <EntryModel>[];
    for (final raw in rawEntries) {
      if (raw is Map) {
        try {
          entries.add(EntryModel.fromMap(Map<String, dynamic>.from(raw)));
        } catch (e) {
          debugPrint('Skipping invalid entry during parse: $e');
        }
      }
    }

    final rawInvestments = map['investments'] as List<dynamic>? ?? const [];
    final investments = <InvestmentModel>[];
    for (final raw in rawInvestments) {
      if (raw is Map) {
        try {
          investments
              .add(InvestmentModel.fromMap(Map<String, dynamic>.from(raw)));
        } catch (e) {
          debugPrint('Skipping invalid investment during parse: $e');
        }
      }
    }

    final rawVersion = map['schemaVersion'] ?? map['version'];
    final schemaVersion = rawVersion is num ? rawVersion.toInt() : 2;
    final parsedUpdated =
        DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
            DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
            DateTime.now();
    final currency = (map['currency']?.toString() ?? '').trim();

    return CloudBackupPayload(
      schemaVersion: schemaVersion,
      updatedAt: parsedUpdated,
      currencyCode: currency.isNotEmpty ? currency : 'BDT',
      categories: categories,
      entries: entries,
      investments: investments,
    );
  }

  factory CloudBackupPayload.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('This is not a Money Tracker backup file.');
    }
    return CloudBackupPayload.fromBackupJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  /// Merges this incoming/cloud snapshot with [local] without creating duplicates.
  CloudBackupPayload mergeWithLocal(CloudBackupPayload local) {
    final merged = mergeIncoming(
      existing: local.categories,
      existingEntries: local.entries,
      existingInvestments: local.investments,
      incomingCategories: categories,
      incomingEntries: entries,
      incomingInvestments: investments,
    );

    final categoryById = <String, CategoryModel>{
      for (final c in local.categories) c.id: c,
    };
    for (final c in merged.categories) {
      categoryById[c.id] = c;
    }

    final entryById = <String, EntryModel>{
      for (final e in local.entries) e.id: e,
    };
    for (final e in merged.entries) {
      final existing = entryById[e.id];
      if (existing == null || !existing.updatedAt.isAfter(e.updatedAt)) {
        entryById[e.id] = e;
      }
    }

    final investmentById = <String, InvestmentModel>{
      for (final inv in local.investments) inv.id: inv,
    };
    for (final inv in merged.investments) {
      final existing = investmentById[inv.id];
      if (existing == null || !existing.updatedAt.isAfter(inv.updatedAt)) {
        investmentById[inv.id] = inv;
      }
    }

    final cloudIsNewer = updatedAt.isAfter(local.updatedAt);
    final String resolvedCurrency;
    if (currencyCode.isNotEmpty &&
        currencyCode != 'BDT' &&
        (cloudIsNewer || local.currencyCode == 'BDT')) {
      resolvedCurrency = currencyCode;
    } else if (cloudIsNewer &&
        !isMeaningfullyEmpty &&
        currencyCode.isNotEmpty) {
      resolvedCurrency = currencyCode;
    } else if (local.currencyCode.isNotEmpty) {
      resolvedCurrency = local.currencyCode;
    } else {
      resolvedCurrency = 'BDT';
    }

    final mergedEntries = entryById.values.toList()
      ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
    final mergedInvestments = investmentById.values.toList()
      ..sort((a, b) {
        final cmp = b.investedDate.compareTo(a.investedDate);
        return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
      });
    final mergedCategories = categoryById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return CloudBackupPayload(
      schemaVersion: 3,
      updatedAt: DateTime.now(),
      currencyCode: resolvedCurrency,
      categories: mergedCategories,
      entries: mergedEntries,
      investments: mergedInvestments,
    );
  }

  /// Deterministic snapshot fingerprint (ignores [updatedAt] and input order).
  String computeContentFingerprint() {
    final sortedCategories = categories.map((c) => c.toMap()).toList()
      ..sort((a, b) =>
          (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? ''));
    final sortedEntries = entries.map((e) => e.toMap()).toList()
      ..sort((a, b) =>
          (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? ''));
    final sortedInvestments = investments.map((i) => i.toMap()).toList()
      ..sort((a, b) =>
          (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? ''));

    return jsonEncode({
      'currency': currencyCode,
      'categories': sortedCategories,
      'entries': sortedEntries,
      'investments': sortedInvestments,
    });
  }
}
