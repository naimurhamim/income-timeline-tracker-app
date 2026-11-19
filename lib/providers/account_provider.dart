import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import '../data/cloud_repository.dart';
import '../data/data_repository.dart';
import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/entry.dart';
import '../models/investment.dart';

enum AccountStatus { guest, signingIn, syncing, signedIn }

/// Manages Google Sign-In and the switch between local and cloud storage.
///
/// This is separate from [AuthService], which only handles the PIN /
/// biometric app lock.
class AccountProvider extends ChangeNotifier {
  /// Web OAuth client ID (client_type 3) from google-services.json.
  /// Required so Google returns an ID token that Firebase can verify.
  static const String _serverClientId =
      '298954546465-8pkq4dtdfvcigemh0ejjfl0qpbh40uva.apps.googleusercontent.com';

  FirebaseAuth get _auth => FirebaseAuth.instance;
  GoogleSignIn get _google => GoogleSignIn.instance;
  bool _googleReady = false;

  User? _user;
  AccountStatus _status = AccountStatus.guest;
  String? _errorMessage;
  double _syncProgress = 0;
  int _localEntryCount = 0;
  int _localInvestmentCount = 0;

  User? get user => _user;
  AccountStatus get status => _status;
  String? get errorMessage => _errorMessage;
  double get syncProgress => _syncProgress;
  bool get isSignedIn => _user != null;
  bool get isBusy =>
      _status == AccountStatus.signingIn || _status == AccountStatus.syncing;
  String get displayName => _user?.displayName ?? 'Guest';
  String get email => _user?.email ?? '';
  String? get photoUrl => _user?.photoURL;

  /// Number of entries stored only on this device (guest mode).
  int get localEntryCount => _localEntryCount;

  /// Number of investments stored only on this device (guest mode).
  int get localInvestmentCount => _localInvestmentCount;

  /// Restores the previous session. [DataStore] is already pointing to the
  /// correct repository (set in `main()`), so this only updates state.
  Future<void> init() async {
    _user = _auth.currentUser;
    _status = _user != null ? AccountStatus.signedIn : AccountStatus.guest;
    if (_user != null) {
      // Keep profile fresh (name/photo may change on the Google side).
      unawaited(CloudRepository(_user!.uid)
          .upsertProfile(
            email: _user!.email,
            name: _user!.displayName,
            photoUrl: _user!.photoURL,
          )
          .catchError((Object e) {
        debugPrint('Profile refresh failed: $e');
        return null;
      }));
    } else {
      await refreshLocalCount();
    }
    notifyListeners();
  }

  Future<void> refreshLocalCount() async {
    try {
      final counts = await DatabaseHelper().countLocalData();
      _localEntryCount = counts.entries;
      _localInvestmentCount = counts.investments;
    } catch (e) {
      debugPrint('Local count failed: $e');
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    await _google.initialize(serverClientId: _serverClientId);
    _googleReady = true;
  }

  // ═══════════════════════════════════
  // Sign-In
  // ═══════════════════════════════════

  /// Signs in with Google, uploads any local data, then switches the app to
  /// cloud storage. Returns true on success.
  Future<bool> signIn() async {
    if (isBusy) return false;
    _status = AccountStatus.signingIn;
    _errorMessage = null;
    notifyListeners();

    try {
      await _ensureGoogleReady();
      final googleUser = await _google.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw StateError('Google did not return an ID token.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) throw StateError('Sign-in returned no user.');

      final cloud = CloudRepository(user.uid);
      await cloud.upsertProfile(
        email: user.email,
        name: user.displayName,
        photoUrl: user.photoURL,
      );

      try {
        await _migrateLocalToCloud(cloud);
      } catch (e) {
        debugPrint('Upload failed: $e');
        await _signOutProviders();
        _errorMessage =
            'Could not upload your data. It is still safe on this device. '
            'Please check your internet connection and try again.';
        _status = AccountStatus.guest;
        notifyListeners();
        return false;
      }

      await cloud.ensureDefaultCategories();

      _user = user;
      _localEntryCount = 0;
      _localInvestmentCount = 0;
      _status = AccountStatus.signedIn;
      // Switching the repository makes every provider reload its data.
      DataStore.instance.use(cloud);
      notifyListeners();
      return true;
    } on GoogleSignInException catch (e) {
      final cancelled = e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted;
      _errorMessage = cancelled ? null : 'Google sign-in failed: ${e.description ?? e.code.name}';
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Authentication failed.';
    } catch (e) {
      _errorMessage = 'Sign-in failed: $e';
    }

    _status = AccountStatus.guest;
    notifyListeners();
    return false;
  }

  // ═══════════════════════════════════
  // Sign-Out
  // ═══════════════════════════════════

  /// True if some changes have not reached the server yet.
  Future<bool> hasUnsyncedChanges() => CloudRepository.hasPendingWrites();

  /// Signs out and returns to guest mode. Cloud data stays in the account
  /// and is loaded again on the next sign-in.
  Future<void> signOut() async {
    await _signOutProviders();

    _user = null;
    _status = AccountStatus.guest;

    // Make sure no old data is shown in guest mode.
    final local = DatabaseHelper();
    await local.clearAll();
    _localEntryCount = 0;
    _localInvestmentCount = 0;
    DataStore.instance.use(local);

    notifyListeners();
  }

  Future<void> _signOutProviders() async {
    try {
      await _ensureGoogleReady();
      await _google.signOut();
    } catch (e) {
      debugPrint('Google sign-out error: $e');
    }
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Firebase sign-out error: $e');
    }
  }

  // ═══════════════════════════════════
  // Migration
  // ═══════════════════════════════════

  /// Uploads local guest data to the account, merging with existing cloud
  /// data. On success a JSON backup is saved and local data is cleared.
  /// Throws if the upload could not be confirmed by the server.
  Future<void> _migrateLocalToCloud(CloudRepository cloud) async {
    final local = DatabaseHelper();
    final counts = await local.countLocalData();
    if (counts.entries + counts.customCategories + counts.investments == 0) {
      return;
    }

    _status = AccountStatus.syncing;
    _syncProgress = 0;
    notifyListeners();

    final localCategories = await local.getCategories();
    final localEntries = await local.getEntries();
    final localInvestments = await local.getInvestments();

    // Merge by category name and entry/investment content so nothing is duplicated.
    final cloudCategories = await cloud.getCategories(preferServer: true);
    final cloudEntries = await cloud.getEntries(preferServer: true);
    final cloudInvestments = await cloud.getInvestments(preferServer: true);
    final merged = mergeIncoming(
      existing: cloudCategories,
      existingEntries: cloudEntries,
      existingInvestments: cloudInvestments,
      incomingCategories: localCategories,
      incomingEntries: localEntries,
      incomingInvestments: localInvestments,
    );

    await cloud.saveAll(
      categories: merged.categories,
      entries: merged.entries,
      investments: merged.investments,
      waitForServer: true,
      onProgress: (done, total) {
        _syncProgress = total > 0 ? done / total : 1;
        notifyListeners();
      },
    );

    // Upload confirmed: keep a JSON copy, then clear the device.
    await _createJsonBackup(
      categories: localCategories,
      entries: localEntries,
      investments: localInvestments,
    );
    await local.clearAll();

    _syncProgress = 1;
    notifyListeners();
  }

  /// Saves a JSON copy of local data in the app documents folder before
  /// local storage is cleared.
  Future<void> _createJsonBackup({
    required List<CategoryModel> categories,
    required List<EntryModel> entries,
    required List<InvestmentModel> investments,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/money_tracker_backup_$timestamp.json');

      final data = {
        'app': 'money_tracker',
        'version': 2,
        'createdAt': DateTime.now().toIso8601String(),
        'categories': categories.map((c) => c.toMap()).toList(),
        'entries': entries.map((e) => e.toMap()).toList(),
        'investments': investments.map((i) => i.toMap()).toList(),
      };

      await file.writeAsString(jsonEncode(data));
      debugPrint('JSON backup saved: ${file.path}');
    } catch (e) {
      debugPrint('JSON backup failed: $e');
    }
  }
}
