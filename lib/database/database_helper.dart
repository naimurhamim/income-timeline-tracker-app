import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../data/data_repository.dart';
import '../models/entry.dart';
import '../models/category.dart';
import '../models/investment.dart';

/// Local SQLite storage, used in guest mode (not signed in).
class DatabaseHelper implements DataRepository {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static const String _dbName = 'money_tracker.db';
  static const String _backupBeforeV4 = 'money_tracker_backup_v3.db';
  static const int _dbVersion = 5;

  // Table names
  static const String tableEntries = 'entries';
  static const String tableCategories = 'categories';
  static const String tableInvestments = 'investments';

  @override
  bool get isCloud => false;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Use FFI for desktop platforms
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _dbName);

    await _backupIfUpgradingToV4(path, documentsDirectory.path);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Keeps a copy of the old database file before the ID format migration,
  /// so user data can always be recovered if something goes wrong.
  Future<void> _backupIfUpgradingToV4(String path, String dir) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;

      final probe = await openDatabase(path, readOnly: true);
      final version = await probe.getVersion();
      await probe.close();

      if (version > 0 && version < 4) {
        final backup = File(join(dir, _backupBeforeV4));
        if (!await backup.exists()) {
          await file.copy(backup.path);
          debugPrint('Database backup created at ${backup.path}');
        }
      }
    } catch (e) {
      debugPrint('Database backup skipped: $e');
    }
  }

  Future<void> _createTables(DatabaseExecutor db,
      {String entries = tableEntries,
      String categories = tableCategories}) async {
    await db.execute('''
      CREATE TABLE $categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT 'category',
        color TEXT NOT NULL DEFAULT '#1B3A4B',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $entries (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        expected_date TEXT NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT,
        priority INTEGER NOT NULL DEFAULT 2,
        notes TEXT,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        recurring_type TEXT,
        recurring_end_date TEXT,
        is_received INTEGER NOT NULL DEFAULT 0,
        received_date TEXT,
        parent_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createInvestmentsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableInvestments (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT 'wallet',
        color TEXT NOT NULL DEFAULT '#1B3A4B',
        invested_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _insertDefaultCategories(DatabaseExecutor db) async {
    for (final category in CategoryModel.defaultCategories) {
      await db.insert(
        tableCategories,
        category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _createInvestmentsTable(db);
    await _insertDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $tableEntries ADD COLUMN recurring_end_date TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE $tableEntries ADD COLUMN parent_id INTEGER');
    }
    if (oldVersion < 4) {
      await _migrateToStringIds(db);
    }
    if (oldVersion < 5) {
      await _createInvestmentsTable(db);
    }
  }

  /// v4: converts integer IDs to string IDs (UUIDs) so data can be merged
  /// across devices. Runs inside the upgrade transaction, so any failure
  /// rolls back and leaves the old data untouched.
  Future<void> _migrateToStringIds(Database db) async {
    const uuid = Uuid();
    const newEntries = 'entries_v4';
    const newCategories = 'categories_v4';

    await _createTables(db, entries: newEntries, categories: newCategories);

    // Categories: built-in names get fixed IDs, custom ones get UUIDs.
    final categoryIdMap = <String, String>{};
    final oldCategories = await db.query(tableCategories);
    for (final row in oldCategories) {
      final name = row['name'] as String;
      final newId = CategoryModel.defaultIdForName(name) ?? uuid.v4();
      categoryIdMap[row['id'].toString()] = newId;
      await db.insert(
        newCategories,
        {
          'id': newId,
          'name': name,
          'icon': row['icon'] ?? 'category',
          'color': row['color'] ?? '#1B3A4B',
          'created_at': row['created_at'] ?? DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // Entries: assign UUIDs first so parent links can be remapped.
    final oldEntries = await db.query(tableEntries);
    final entryIdMap = <String, String>{
      for (final row in oldEntries) row['id'].toString(): uuid.v4(),
    };

    for (final row in oldEntries) {
      final map = Map<String, dynamic>.from(row);
      map['id'] = entryIdMap[row['id'].toString()];
      final oldCat = row['category_id'];
      map['category_id'] = oldCat == null ? null : categoryIdMap[oldCat.toString()];
      final oldParent = row['parent_id'];
      map['parent_id'] = oldParent == null ? null : entryIdMap[oldParent.toString()];
      await db.insert(newEntries, map);
    }

    await db.execute('DROP TABLE $tableEntries');
    await db.execute('DROP TABLE $tableCategories');
    await db.execute('ALTER TABLE $newEntries RENAME TO $tableEntries');
    await db.execute('ALTER TABLE $newCategories RENAME TO $tableCategories');

    // Make sure built-in categories always exist.
    await _insertDefaultCategories(db);
  }

  // ═══════════════════════════════════
  // ENTRY Operations
  // ═══════════════════════════════════

  @override
  Future<List<EntryModel>> getEntries({bool preferServer = false}) async {
    final db = await database;
    final maps = await db.query(tableEntries, orderBy: 'expected_date ASC');
    return maps.map((map) => EntryModel.fromMap(map)).toList();
  }

  @override
  Future<void> saveEntry(EntryModel entry) async {
    final db = await database;
    await db.insert(
      tableEntries,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteEntry(String id) async {
    final db = await database;
    await db.delete(tableEntries, where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════
  // CATEGORY Operations
  // ═══════════════════════════════════

  @override
  Future<List<CategoryModel>> getCategories({bool preferServer = false}) async {
    final db = await database;
    final maps = await db.query(tableCategories, orderBy: 'name ASC');
    return maps.map((map) => CategoryModel.fromMap(map)).toList();
  }

  @override
  Future<void> saveCategory(CategoryModel category) async {
    final db = await database;
    await db.insert(
      tableCategories,
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete(tableCategories, where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════
  // INVESTMENT Operations
  // ═══════════════════════════════════

  @override
  Future<List<InvestmentModel>> getInvestments({bool preferServer = false}) async {
    final db = await database;
    final maps = await db.query(
      tableInvestments,
      orderBy: 'invested_date DESC, created_at DESC',
    );
    return maps.map((map) => InvestmentModel.fromMap(map)).toList();
  }

  @override
  Future<void> saveInvestment(InvestmentModel investment) async {
    final db = await database;
    await db.insert(
      tableInvestments,
      investment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteInvestment(String id) async {
    final db = await database;
    await db.delete(tableInvestments, where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════
  // Bulk Operations
  // ═══════════════════════════════════

  @override
  Future<void> saveAll({
    List<CategoryModel> categories = const [],
    List<EntryModel> entries = const [],
    List<InvestmentModel> investments = const [],
    bool waitForServer = false,
    void Function(int done, int total)? onProgress,
  }) async {
    final db = await database;
    final total = categories.length + entries.length + investments.length;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final c in categories) {
        batch.insert(tableCategories, c.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final e in entries) {
        batch.insert(tableEntries, e.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final inv in investments) {
        batch.insert(tableInvestments, inv.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
    onProgress?.call(total, total);
  }

  @override
  Future<void> clearAll({bool waitForServer = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableEntries);
      await txn.delete(tableInvestments);
      await txn.delete(tableCategories);
      await _insertDefaultCategories(txn);
    });
  }

  /// Number of entries, custom categories, and investments stored locally.
  Future<({int entries, int customCategories, int investments})>
      countLocalData() async {
    final db = await database;
    int firstInt(List<Map<String, Object?>> rows) =>
        rows.isEmpty ? 0 : ((rows.first.values.first as num?)?.toInt() ?? 0);
    final e = firstInt(await db.rawQuery('SELECT COUNT(*) FROM $tableEntries'));
    final c = firstInt(await db.rawQuery(
        "SELECT COUNT(*) FROM $tableCategories WHERE id NOT LIKE '${CategoryModel.defaultIdPrefix}%'"));
    final i =
        firstInt(await db.rawQuery('SELECT COUNT(*) FROM $tableInvestments'));
    return (entries: e, customCategories: c, investments: i);
  }

  // ═══════════════════════════════════
  // Database Management
  // ═══════════════════════════════════

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
