import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/entry.dart';
import '../models/category.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static const String _dbName = 'money_tracker.db';
  static const int _dbVersion = 2;

  // Table names
  static const String tableEntries = 'entries';
  static const String tableCategories = 'categories';

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

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create categories table
    await db.execute('''
      CREATE TABLE $tableCategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT 'category',
        color TEXT NOT NULL DEFAULT '#1B3A4B',
        created_at TEXT NOT NULL
      )
    ''');

    // Create entries table
    await db.execute('''
      CREATE TABLE $tableEntries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        expected_date TEXT NOT NULL,
        type TEXT NOT NULL,
        category_id INTEGER,
        priority INTEGER NOT NULL DEFAULT 2,
        notes TEXT,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        recurring_type TEXT,
        recurring_end_date TEXT,
        is_received INTEGER NOT NULL DEFAULT 0,
        received_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES $tableCategories(id) ON DELETE SET NULL
      )
    ''');

    // Insert default categories
    for (final category in CategoryModel.defaultCategories) {
      await db.insert(tableCategories, category.toMap()..remove('id'));
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $tableEntries ADD COLUMN recurring_end_date TEXT');
    }
  }

  // ═══════════════════════════════════
  // ENTRY CRUD Operations
  // ═══════════════════════════════════

  Future<int> insertEntry(EntryModel entry) async {
    final db = await database;
    final map = entry.toMap()..remove('id');
    return await db.insert(tableEntries, map);
  }

  Future<int> updateEntry(EntryModel entry) async {
    final db = await database;
    return await db.update(
      tableEntries,
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteEntry(int id) async {
    final db = await database;
    return await db.delete(tableEntries, where: 'id = ?', whereArgs: [id]);
  }

  Future<EntryModel?> getEntry(int id) async {
    final db = await database;
    final maps = await db.query(
      tableEntries,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return EntryModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<EntryModel>> getAllEntries({
    bool? isReceived,
    String? type,
    String? searchQuery,
    String orderBy = 'expected_date ASC',
  }) async {
    final db = await database;

    String? where;
    List<dynamic>? whereArgs;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (isReceived != null) {
      conditions.add('is_received = ?');
      args.add(isReceived ? 1 : 0);
    }

    if (type != null && type.isNotEmpty) {
      conditions.add('type = ?');
      args.add(type);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('(title LIKE ? OR notes LIKE ?)');
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }

    if (conditions.isNotEmpty) {
      where = conditions.join(' AND ');
      whereArgs = args;
    }

    final maps = await db.query(
      tableEntries,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );

    return maps.map((map) => EntryModel.fromMap(map)).toList();
  }

  Future<List<EntryModel>> getUpcomingEntries({int? limit}) async {
    final db = await database;
    final maps = await db.query(
      tableEntries,
      where: 'is_received = 0',
      orderBy: 'expected_date ASC',
      limit: limit,
    );
    return maps.map((map) => EntryModel.fromMap(map)).toList();
  }

  Future<int> markAsReceived(int id) async {
    final db = await database;
    return await db.update(
      tableEntries,
      {
        'is_received': 1,
        'received_date': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAsUnreceived(int id) async {
    final db = await database;
    return await db.update(
      tableEntries,
      {
        'is_received': 0,
        'received_date': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ═══════════════════════════════════
  // SUMMARY Queries
  // ═══════════════════════════════════

  Future<double> getTotalUpcomingAmount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM $tableEntries WHERE is_received = 0',
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getTotalReceivedAmount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM $tableEntries WHERE is_received = 1',
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getTotalAllAmount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM $tableEntries',
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getYearlyTotal(int year) async {
    final db = await database;
    final startDate = DateTime(year, 1, 1).toIso8601String();
    final endDate = DateTime(year, 12, 31, 23, 59, 59).toIso8601String();
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM $tableEntries WHERE expected_date >= ? AND expected_date <= ?',
      [startDate, endDate],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getMonthlyTotal(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate =
        DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM $tableEntries WHERE expected_date >= ? AND expected_date <= ?',
      [startDate, endDate],
    );
    return (result.first['total'] as num).toDouble();
  }





  // ═══════════════════════════════════
  // CATEGORY CRUD Operations
  // ═══════════════════════════════════

  Future<int> insertCategory(CategoryModel category) async {
    final db = await database;
    final map = category.toMap()..remove('id');
    return await db.insert(tableCategories, map);
  }

  Future<int> updateCategory(CategoryModel category) async {
    final db = await database;
    return await db.update(
      tableCategories,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete(tableCategories, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CategoryModel>> getAllCategories() async {
    final db = await database;
    final maps = await db.query(tableCategories, orderBy: 'name ASC');
    return maps.map((map) => CategoryModel.fromMap(map)).toList();
  }

  Future<CategoryModel?> getCategory(int id) async {
    final db = await database;
    final maps = await db.query(
      tableCategories,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return CategoryModel.fromMap(maps.first);
    }
    return null;
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
