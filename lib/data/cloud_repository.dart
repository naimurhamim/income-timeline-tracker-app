import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/category.dart';
import '../models/entry.dart';
import 'data_repository.dart';

/// Firestore storage for signed-in users.
///
/// Layout: `users/{uid}/entries/{id}` and `users/{uid}/categories/{id}`.
/// Firestore keeps an offline cache, so reads and writes keep working
/// without internet and sync automatically when the connection returns.
class CloudRepository implements DataRepository {
  CloudRepository(this.uid);

  final String uid;

  static const int _batchLimit = 400;
  static const Duration _serverTimeout = Duration(seconds: 60);

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get userDoc =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _entries =>
      userDoc.collection('entries');

  CollectionReference<Map<String, dynamic>> get _categories =>
      userDoc.collection('categories');

  @override
  bool get isCloud => true;

  /// Reads a collection. Uses the local cache by default so the UI stays
  /// fast and works offline; falls back to cache if the server is slow.
  Future<QuerySnapshot<Map<String, dynamic>>> _read(
    CollectionReference<Map<String, dynamic>> ref,
    bool preferServer,
  ) async {
    if (preferServer) {
      try {
        return await ref.get().timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('Server read failed, using cache: $e');
      }
    }
    try {
      return await ref.get(const GetOptions(source: Source.cache));
    } catch (_) {
      // Cache is empty (first launch on this device): read from server.
      return await ref.get();
    }
  }

  /// Writes are not awaited: with offline persistence the future only
  /// completes after the server confirms, which never happens offline.
  /// The change is applied to the local cache immediately.
  void _fireAndForget(Future<void> write, String label) {
    unawaited(write.catchError(
      (Object e) => debugPrint('Cloud write failed ($label): $e'),
    ));
  }

  // ═══════════════════════════════════
  // Entries
  // ═══════════════════════════════════

  @override
  Future<List<EntryModel>> getEntries({bool preferServer = false}) async {
    final snap = await _read(_entries, preferServer);
    final list = <EntryModel>[];
    for (final doc in snap.docs) {
      try {
        list.add(EntryModel.fromMap({...doc.data(), 'id': doc.id}));
      } catch (e) {
        debugPrint('Skipping invalid entry ${doc.id}: $e');
      }
    }
    list.sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
    return list;
  }

  @override
  Future<void> saveEntry(EntryModel entry) async {
    _fireAndForget(_entries.doc(entry.id).set(entry.toMap()), 'entry');
  }

  @override
  Future<void> deleteEntry(String id) async {
    _fireAndForget(_entries.doc(id).delete(), 'delete entry');
  }

  // ═══════════════════════════════════
  // Categories
  // ═══════════════════════════════════

  @override
  Future<List<CategoryModel>> getCategories({bool preferServer = false}) async {
    final snap = await _read(_categories, preferServer);
    final list = <CategoryModel>[];
    for (final doc in snap.docs) {
      try {
        list.add(CategoryModel.fromMap({...doc.data(), 'id': doc.id}));
      } catch (e) {
        debugPrint('Skipping invalid category ${doc.id}: $e');
      }
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Future<void> saveCategory(CategoryModel category) async {
    _fireAndForget(
        _categories.doc(category.id).set(category.toMap()), 'category');
  }

  @override
  Future<void> deleteCategory(String id) async {
    _fireAndForget(_categories.doc(id).delete(), 'delete category');
  }

  /// Adds the built-in categories if the account has none yet.
  Future<void> ensureDefaultCategories() async {
    final existing = await getCategories(preferServer: true);
    final ids = existing.map((c) => c.id).toSet();
    final missing = CategoryModel.defaultCategories
        .where((c) => !ids.contains(c.id))
        .toList();
    if (missing.isEmpty) return;
    await saveAll(categories: missing);
  }

  // ═══════════════════════════════════
  // Bulk Operations
  // ═══════════════════════════════════

  @override
  Future<void> saveAll({
    List<CategoryModel> categories = const [],
    List<EntryModel> entries = const [],
    bool waitForServer = false,
    void Function(int done, int total)? onProgress,
  }) async {
    final writes = <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[
      for (final c in categories) (_categories.doc(c.id), c.toMap()),
      for (final e in entries) (_entries.doc(e.id), e.toMap()),
    ];
    final total = writes.length;
    var done = 0;
    onProgress?.call(0, total);

    for (var i = 0; i < writes.length; i += _batchLimit) {
      final chunk = writes.skip(i).take(_batchLimit);
      final batch = _db.batch();
      for (final (ref, data) in chunk) {
        batch.set(ref, data);
      }
      final commit = batch.commit();
      if (waitForServer) {
        await commit.timeout(_serverTimeout);
      } else {
        _fireAndForget(commit, 'batch');
      }
      done += chunk.length;
      onProgress?.call(done, total);
    }
  }

  @override
  Future<void> clearAll({bool waitForServer = false}) async {
    final entries = await _read(_entries, true);
    final categories = await _read(_categories, true);
    final refs = [
      ...entries.docs.map((d) => d.reference),
      ...categories.docs
          .where((d) => !d.id.startsWith(CategoryModel.defaultIdPrefix))
          .map((d) => d.reference),
    ];

    for (var i = 0; i < refs.length; i += _batchLimit) {
      final batch = _db.batch();
      for (final ref in refs.skip(i).take(_batchLimit)) {
        batch.delete(ref);
      }
      final commit = batch.commit();
      if (waitForServer) {
        await commit.timeout(_serverTimeout);
      } else {
        _fireAndForget(commit, 'clear');
      }
    }
  }

  // ═══════════════════════════════════
  // User profile
  // ═══════════════════════════════════

  /// Creates or updates `users/{uid}` with the account details.
  Future<Map<String, dynamic>?> upsertProfile({
    required String? email,
    required String? name,
    required String? photoUrl,
  }) async {
    Map<String, dynamic>? existing;
    try {
      final snap = await userDoc.get().timeout(const Duration(seconds: 15));
      existing = snap.data();
    } catch (e) {
      debugPrint('Profile read failed: $e');
    }

    final data = <String, dynamic>{
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'lastLoginAt': FieldValue.serverTimestamp(),
      if (existing == null) 'createdAt': FieldValue.serverTimestamp(),
    };
    _fireAndForget(userDoc.set(data, SetOptions(merge: true)), 'profile');
    return existing;
  }

  Future<void> saveCurrency(String code) async {
    _fireAndForget(
      userDoc.set({'currency': code}, SetOptions(merge: true)),
      'currency',
    );
  }

  /// Reads the saved currency code from the profile (server first,
  /// falls back to the offline cache).
  Future<String?> getCurrency() async {
    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await userDoc.get().timeout(const Duration(seconds: 10));
    } catch (_) {
      try {
        snap = await userDoc.get(const GetOptions(source: Source.cache));
      } catch (e) {
        debugPrint('Currency read failed: $e');
      }
    }
    return snap?.data()?['currency'] as String?;
  }

  /// Returns true if some local changes have not reached the server yet.
  static Future<bool> hasPendingWrites({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      await FirebaseFirestore.instance.waitForPendingWrites().timeout(timeout);
      return false;
    } catch (_) {
      return true;
    }
  }
}
