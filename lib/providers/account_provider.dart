import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/data_repository.dart';
import '../database/database_helper.dart';
import '../models/cloud_backup_payload.dart';
import '../models/google_account_profile.dart';
import '../services/cloud_backup_service.dart';
import 'category_provider.dart';
import 'currency_provider.dart';
import 'entry_provider.dart';
import 'investment_provider.dart';

/// Coordinates cached Google identity, private Google Drive (`appDataFolder`)
/// auto-backup, and one-time read-only legacy Firebase -> SQLite migration.
class AccountProvider extends ChangeNotifier {
  AccountProvider({CloudBackupService? service})
      : _service = service ?? CloudBackupService();

  static const String _profileKey = 'google_account_profile_v1';
  static const String _firebaseMigratedKey = 'firebase_to_local_migrated_v3';

  final CloudBackupService _service;

  CategoryProvider? _categories;
  EntryProvider? _entries;
  InvestmentProvider? _investments;
  CurrencyProvider? _currency;

  Timer? _debounceTimer;
  GoogleAccountProfile? _profile;
  bool _isBusy = false;
  bool _isSyncing = false;
  bool _suppressAutoSync = false;
  bool _uploadInFlight = false;
  bool _queuedUpload = false;
  String? _lastSyncedFingerprint;
  String? _errorMessage;
  String? _migrationNotice;

  bool get isAvailable => _service.isAvailable;
  bool get isSignedIn => _profile != null;
  bool get isBusy => _isBusy;
  bool get isSyncing => _isSyncing;
  String get displayName =>
      (_profile?.displayName != null &&
              _profile!.displayName!.trim().isNotEmpty)
          ? _profile!.displayName!.trim()
          : 'Money Tracker';
  String get email => _profile?.email ?? '';
  String? get photoUrl => _profile?.photoUrl;
  DateTime? get lastSyncedAt => _profile?.lastSyncedAt;
  String? get errorMessage => _errorMessage;
  String? get migrationNotice => _migrationNotice;

  /// Connects local data providers so mutations auto-backup to Drive and
  /// restores refresh every active screen immediately.
  void bindProviders({
    required CategoryProvider categories,
    required EntryProvider entries,
    required InvestmentProvider investments,
    required CurrencyProvider currency,
  }) {
    _categories = categories;
    _entries = entries;
    _investments = investments;
    _currency = currency;

    categories.setOnDataChanged(scheduleAutoBackup);
    entries.setOnDataChanged(scheduleAutoBackup);
    investments.setOnDataChanged(scheduleAutoBackup);
    currency.setOnDataChanged(scheduleAutoBackup);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void dismissMigrationNotice() {
    _migrationNotice = null;
    notifyListeners();
  }

  /// One-time automatic migration on startup: if a user previously stored
  /// data in Firebase Firestore on v2.x, safely merge and save it into local
  /// SQLite so nothing is lost when switching to local-first + Drive backup.
  Future<bool> migrateLegacyFirebaseOnStartupIfNeeded({
    required CurrencyProvider currencyProvider,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_firebaseMigratedKey) == true) return false;

      if (Firebase.apps.isEmpty) {
        await prefs.setBool(_firebaseMigratedKey, true);
        return false;
      }

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        await prefs.setBool(_firebaseMigratedKey, true);
        return false;
      }

      final legacy = await _service.fetchLegacyFirebaseBackup(
        allowCurrentFirebaseUserOnly: true,
      );

      if (legacy == null || legacy.isMeaningfullyEmpty) {
        await prefs.setBool(_firebaseMigratedKey, true);
        await _service.signOutLegacyFirebase();
        return false;
      }

      await _writeSafetyJsonBackup(
        legacy,
        prefix: 'money_tracker_firebase_migrated',
      );

      final db = DatabaseHelper();
      final local = await _buildLocalPayload(db, currencyProvider.code);
      final merged = legacy.mergeWithLocal(local);

      await db.clearAll();
      await db.saveAll(
        categories: merged.categories.where((c) => !c.isDefault).toList(),
        entries: merged.entries,
        investments: merged.investments,
      );
      await currencyProvider.applyRestoredCurrency(merged.currencyCode);

      await prefs.setBool(_firebaseMigratedKey, true);
      await _service.signOutLegacyFirebase();

      _migrationNotice =
          'Your previous Firebase data has been saved locally on this device. Sign in with Google anytime to back up to your private Google Drive.';
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Startup Firebase migration failed: $e');
      return false;
    }
  }

  /// Restores cached Google profile and silently reconciles with Google Drive.
  Future<void> init() async {
    _profile = await _loadCachedProfile();
    notifyListeners();

    if (!_service.isAvailable) return;

    final live = await _service.restoreSilentSession();
    if (live == null) return;

    _profile = _mergeAccountInfo(existing: _profile, fresh: live);
    await _saveCachedProfile(_profile);
    notifyListeners();

    await _reconcileWithDrive(promptIfNecessary: false);
  }

  Future<bool> signIn() async {
    if (_isBusy || !isAvailable) return false;
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final signed = await _service.signInWithGoogle();
      if (signed == null) return false;

      _profile = _mergeAccountInfo(existing: _profile, fresh: signed);
      await _saveCachedProfile(_profile);
      notifyListeners();

      await _reconcileWithDrive(promptIfNecessary: true);
      return true;
    } catch (e) {
      _errorMessage = 'Sign-in failed: $e';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Signs out of Google without deleting any local data on the device.
  Future<void> signOut() async {
    if (_isBusy) return;
    _debounceTimer?.cancel();
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.signOut();
      _profile = null;
      _lastSyncedFingerprint = null;
      await _saveCachedProfile(null);
    } catch (e) {
      _errorMessage = 'Sign-out failed: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void scheduleAutoBackup() {
    if (!isAvailable || _profile == null || _suppressAutoSync) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(_runSingleUpload(silent: true, promptIfNecessary: false));
    });
  }

  Future<bool> backupNow({bool silent = false}) {
    return _runSingleUpload(silent: silent, promptIfNecessary: !silent);
  }

  Future<bool> restoreFromDrive() async {
    if (!isAvailable || _profile == null || _isBusy) return false;

    _isBusy = true;
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!_service.isSignedInSessionActive) {
        await _service.restoreSilentSession();
        if (!_service.isSignedInSessionActive) {
          final signed = await _service.signInWithGoogle();
          if (signed == null) return false;
          _profile = _mergeAccountInfo(existing: _profile, fresh: signed);
        }
      }

      final res = await _service.fetchDriveBackup(promptIfNecessary: true);
      if (res.payload == null) {
        _errorMessage = 'No backup found in your Google Drive yet.';
        return false;
      }

      await _applyPayloadLocally(res.payload!);
      _lastSyncedFingerprint = res.payload!.computeContentFingerprint();
      _profile = _profile!.copyWith(
        driveFileId: res.fileId,
        lastSyncedAt: DateTime.now(),
      );
      await _saveCachedProfile(_profile);
      return true;
    } catch (e) {
      _errorMessage = 'Restore failed: $e';
      return false;
    } finally {
      _isBusy = false;
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Triggers an immediate provider reload & debounced Drive backup after manual import.
  Future<void> reloadAfterImport({bool scheduleBackup = true}) async {
    _suppressAutoSync = true;
    try {
      await _categories?.loadCategories();
      await _entries?.loadAll();
      await _investments?.loadInvestments();
      _entries?.syncNotificationsAndAlerts();
    } finally {
      _suppressAutoSync = false;
    }
    if (scheduleBackup) {
      scheduleAutoBackup();
    }
  }

  Future<void> _reconcileWithDrive({required bool promptIfNecessary}) async {
    if (_profile == null || !_service.isAvailable) return;
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final driveRes = await _service.fetchDriveBackup(
        promptIfNecessary: promptIfNecessary,
      );
      final local = await _buildLocalPayload(
        DatabaseHelper(),
        _currency?.code ?? 'BDT',
      );

      if (driveRes.payload != null) {
        var finalPayload = driveRes.payload!;

        if (local.isMeaningfullyEmpty) {
          await _applyPayloadLocally(finalPayload);
        } else {
          final merged = driveRes.payload!.mergeWithLocal(local);
          await _applyPayloadLocally(merged);
          finalPayload = merged;
        }

        // One-time read-only legacy Firebase merge if not yet migrated.
        var migratedNow = false;
        if (!(_profile?.migratedFromFirebase ?? false)) {
          final legacy = await _service.fetchLegacyFirebaseBackup();
          if (legacy != null && !legacy.isMeaningfullyEmpty) {
            final withLegacy = legacy.mergeWithLocal(finalPayload);
            await _applyPayloadLocally(withLegacy);
            finalPayload = withLegacy;
            migratedNow = true;
          }
        }

        var fileId = driveRes.fileId;
        if (finalPayload.computeContentFingerprint() !=
            driveRes.payload!.computeContentFingerprint()) {
          fileId = await _service.saveDriveBackup(
            finalPayload,
            knownFileId: fileId,
            promptIfNecessary: promptIfNecessary,
          );
        }

        if (migratedNow) {
          await _service.signOutLegacyFirebase();
          _migrationNotice =
              'Migrated your old Firebase backup to your private Google Drive.';
        }

        _lastSyncedFingerprint = finalPayload.computeContentFingerprint();
        _profile = _profile!.copyWith(
          driveFileId: fileId,
          lastSyncedAt: DateTime.now(),
          migratedFromFirebase:
              (_profile?.migratedFromFirebase ?? false) || migratedNow,
        );
      } else {
        CloudBackupPayload? legacy;
        if (!(_profile?.migratedFromFirebase ?? false)) {
          legacy = await _service.fetchLegacyFirebaseBackup();
        }

        var initialPayload = local;
        if (legacy != null && !legacy.isMeaningfullyEmpty) {
          initialPayload = legacy.mergeWithLocal(local);
          await _applyPayloadLocally(initialPayload);
        }

        final createdFileId = await _service.saveDriveBackup(
          initialPayload,
          promptIfNecessary: promptIfNecessary,
        );

        if (legacy != null) {
          await _service.signOutLegacyFirebase();
          _migrationNotice =
              'Old Firebase backup saved locally and backed up to your private Google Drive.';
        }

        _lastSyncedFingerprint = initialPayload.computeContentFingerprint();
        _profile = _profile!.copyWith(
          driveFileId: createdFileId,
          lastSyncedAt: DateTime.now(),
          migratedFromFirebase: true,
        );
      }

      await _saveCachedProfile(_profile);
    } catch (e) {
      _errorMessage = 'Google Drive sync failed: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> _runSingleUpload({
    required bool silent,
    required bool promptIfNecessary,
  }) async {
    if (!isAvailable || _profile == null) return false;

    final initialPayload = await _buildLocalPayload(
      DatabaseHelper(),
      _currency?.code ?? 'BDT',
    );
    final initialHash = initialPayload.computeContentFingerprint();
    if (silent && initialHash == _lastSyncedFingerprint) {
      return true;
    }

    if (_uploadInFlight) {
      _queuedUpload = true;
      return true;
    }

    _uploadInFlight = true;
    if (!silent) {
      _isBusy = true;
    }
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    var succeeded = true;
    try {
      do {
        _queuedUpload = false;
        if (!_service.isSignedInSessionActive) {
          await _service.restoreSilentSession();
          if (!_service.isSignedInSessionActive && promptIfNecessary) {
            final signed = await _service.signInWithGoogle();
            if (signed != null) {
              _profile = _mergeAccountInfo(existing: _profile, fresh: signed);
            }
          }
        }

        final payload = await _buildLocalPayload(
          DatabaseHelper(),
          _currency?.code ?? 'BDT',
        );
        final fingerprint = payload.computeContentFingerprint();
        if (silent && fingerprint == _lastSyncedFingerprint) {
          continue;
        }

        final nextId = await _service.saveDriveBackup(
          payload,
          knownFileId: _profile?.driveFileId,
          promptIfNecessary: promptIfNecessary,
        );
        _lastSyncedFingerprint = fingerprint;
        _profile = _profile!.copyWith(
          driveFileId: nextId,
          lastSyncedAt: DateTime.now(),
        );
        await _saveCachedProfile(_profile);
      } while (_queuedUpload);
    } catch (e) {
      succeeded = false;
      _errorMessage = 'Drive backup failed: $e';
    } finally {
      _uploadInFlight = false;
      if (!silent) {
        _isBusy = false;
      }
      _isSyncing = false;
      notifyListeners();
    }
    return succeeded;
  }

  Future<CloudBackupPayload> _buildLocalPayload(
    DataRepository repo,
    String currencyCode,
  ) async {
    final categories = await repo.getCategories();
    final entries = await repo.getEntries();
    final investments = await repo.getInvestments();
    return CloudBackupPayload(
      schemaVersion: 3,
      updatedAt: DateTime.now(),
      currencyCode: currencyCode,
      categories: categories,
      entries: entries,
      investments: investments,
    );
  }

  Future<void> _applyPayloadLocally(CloudBackupPayload payload) async {
    _suppressAutoSync = true;
    try {
      final db = DatabaseHelper();
      await db.clearAll();
      await db.saveAll(
        categories: payload.categories.where((c) => !c.isDefault).toList(),
        entries: payload.entries,
        investments: payload.investments,
      );
      if (_currency != null && payload.currencyCode.isNotEmpty) {
        await _currency!.applyRestoredCurrency(payload.currencyCode);
      }
      await _categories?.loadCategories();
      await _entries?.loadAll();
      await _investments?.loadInvestments();
      _entries?.syncNotificationsAndAlerts();
    } finally {
      _suppressAutoSync = false;
    }
  }

  GoogleAccountProfile _mergeAccountInfo({
    GoogleAccountProfile? existing,
    required GoogleAccountProfile fresh,
  }) {
    final sameUser = existing != null &&
        existing.email.toLowerCase() == fresh.email.toLowerCase();
    if (!sameUser) return fresh;
    return existing.copyWith(
      id: fresh.id,
      email: fresh.email,
      displayName: fresh.displayName ?? existing.displayName,
      photoUrl: fresh.photoUrl ?? existing.photoUrl,
    );
  }

  Future<GoogleAccountProfile?> _loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profileKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return GoogleAccountProfile.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCachedProfile(GoogleAccountProfile? profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (profile == null) {
        await prefs.remove(_profileKey);
      } else {
        await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
      }
    } catch (_) {}
  }

  Future<void> _writeSafetyJsonBackup(
    CloudBackupPayload payload, {
    required String prefix,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/${prefix}_$timestamp.json');
      await file.writeAsString(payload.toJsonString(pretty: true));
    } catch (e) {
      debugPrint('Safety JSON backup failed: $e');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _categories?.setOnDataChanged(null);
    _entries?.setOnDataChanged(null);
    _investments?.setOnDataChanged(null);
    _currency?.setOnDataChanged(null);
    super.dispose();
  }
}
