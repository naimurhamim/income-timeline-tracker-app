import 'package:flutter/foundation.dart';
import '../models/category.dart';
import '../models/entry.dart';

/// Common storage interface used by the providers.
///
/// Two implementations exist:
/// - [DatabaseHelper] (local SQLite) for guest mode.
/// - [CloudRepository] (Firestore with offline cache) when signed in.
abstract class DataRepository {
  /// Whether this repository stores data in the cloud.
  bool get isCloud;

  // Entries
  Future<List<EntryModel>> getEntries({bool preferServer = false});
  Future<void> saveEntry(EntryModel entry);
  Future<void> deleteEntry(String id);

  // Categories
  Future<List<CategoryModel>> getCategories({bool preferServer = false});
  Future<void> saveCategory(CategoryModel category);
  Future<void> deleteCategory(String id);

  /// Inserts or replaces many records at once.
  ///
  /// When [waitForServer] is true (cloud only) the future completes only
  /// after the server confirmed the write, or throws on timeout.
  Future<void> saveAll({
    List<CategoryModel> categories = const [],
    List<EntryModel> entries = const [],
    bool waitForServer = false,
    void Function(int done, int total)? onProgress,
  });

  /// Removes every entry and every custom category.
  Future<void> clearAll({bool waitForServer = false});
}

/// Holds the currently active repository. Providers listen to this and
/// reload their data whenever the user signs in or out.
class DataStore extends ValueNotifier<DataRepository> {
  DataStore._(super.value);

  static DataStore? _instance;

  static DataStore get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('DataStore.init() must be called first');
    }
    return i;
  }

  static void init(DataRepository initial) {
    _instance ??= DataStore._(initial);
  }

  DataRepository get repo => value;

  void use(DataRepository repository) => value = repository;
}

/// Result of [mergeIncoming]: only the records that should be written.
typedef MergeResult = ({
  List<CategoryModel> categories,
  List<EntryModel> entries,
  int skippedDuplicates,
});

/// Content fingerprint used to detect the same entry saved with a
/// different ID (e.g. typed in by hand on two devices).
String entryFingerprint(EntryModel e) {
  final d = e.expectedDate;
  return [
    e.title.trim().toLowerCase(),
    e.amount.toStringAsFixed(2),
    '${d.year}-${d.month}-${d.day}',
    e.type.trim().toLowerCase(),
    e.isReceived ? 'r' : 'u',
  ].join('|');
}

/// Prepares incoming data (from another device or a JSON file) for merging
/// into existing data without creating duplicates.
///
/// - Built-in categories are skipped (they already exist everywhere).
/// - A custom category whose name matches an existing one (case-insensitive)
///   is not added again; entries pointing to it are remapped instead.
/// - An entry with the same ID as an existing one overwrites it.
/// - An entry with a different ID but the same content (see
///   [entryFingerprint]) is skipped as a duplicate.
MergeResult mergeIncoming({
  required List<CategoryModel> existing,
  required List<CategoryModel> incomingCategories,
  required List<EntryModel> incomingEntries,
  List<EntryModel> existingEntries = const [],
}) {
  String key(String name) => name.trim().toLowerCase();

  // ── Categories ──
  final existingIds = existing.map((c) => c.id).toSet();
  final idByName = {for (final c in existing) key(c.name): c.id};
  final idMap = <String, String>{};
  final toAdd = <CategoryModel>[];

  for (final c in incomingCategories) {
    final defaultId = CategoryModel.defaultIdForName(c.name);
    if (c.isDefault || defaultId != null) {
      if (defaultId != null && defaultId != c.id) idMap[c.id] = defaultId;
      continue;
    }
    if (existingIds.contains(c.id)) continue;
    final match = idByName[key(c.name)];
    if (match != null) {
      idMap[c.id] = match;
    } else {
      toAdd.add(c);
      idByName[key(c.name)] = c.id;
    }
  }

  // ── Entries ──
  final existingEntryIds = existingEntries.map((e) => e.id).toSet();
  final idByFingerprint = <String, String>{
    for (final e in existingEntries) entryFingerprint(e): e.id,
  };
  final entryIdMap = <String, String>{};
  final kept = <EntryModel>[];
  var skipped = 0;

  for (final e in incomingEntries) {
    if (!existingEntryIds.contains(e.id)) {
      final fp = entryFingerprint(e);
      final match = idByFingerprint[fp];
      if (match != null && match != e.id) {
        entryIdMap[e.id] = match;
        skipped++;
        continue;
      }
    }
    kept.add(e);
  }

  final entries = kept.map((e) {
    final newCat = e.categoryId == null ? null : idMap[e.categoryId];
    final newParent = e.parentId == null ? null : entryIdMap[e.parentId];
    if (newCat == null && newParent == null) return e;
    return e.copyWith(
      categoryId: newCat ?? e.categoryId,
      parentId: newParent ?? e.parentId,
      updatedAt: e.updatedAt,
    );
  }).toList();

  return (categories: toAdd, entries: entries, skippedDuplicates: skipped);
}
