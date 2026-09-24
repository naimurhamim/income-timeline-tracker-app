import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/entry.dart';
import '../services/notification_service.dart';

class EntryProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<EntryModel> _entries = [];
  List<EntryModel> _upcomingEntries = [];
  List<EntryModel> _receivedEntries = [];
  double _totalUpcoming = 0;
  double _totalReceived = 0;
  double _totalAll = 0;
  bool _isLoading = false;
  String? _searchQuery;
  String? _filterType;

  // Getters
  List<EntryModel> get entries => _entries;
  List<EntryModel> get upcomingEntries => _upcomingEntries;
  List<EntryModel> get receivedEntries => _receivedEntries;
  double get totalUpcoming => _totalUpcoming;
  double get totalReceived => _totalReceived;
  double get totalAll => _totalAll;

  double get estimatedNext3MonthsTotal {
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month + 3, now.day, 23, 59, 59);
    double total = 0.0;
    
    for (var entry in _upcomingEntries) {
      // Add non-recurring entries that fall within the window
      if (!entry.isRecurring) {
        if (entry.expectedDate.isBefore(endDate) || entry.expectedDate.isAtSameMomentAs(endDate)) {
          total += entry.amount;
        }
        continue;
      }
      
      // For recurring: add current expected date if within window
      if (entry.expectedDate.isBefore(endDate) || entry.expectedDate.isAtSameMomentAs(endDate)) {
        total += entry.amount;
      }
      
      // Then project future recurring occurrences
      if (entry.recurringType != null) {
        DateTime? nextDate = entry.getNextRecurringDate();
        while (nextDate != null && (nextDate.isBefore(endDate) || nextDate.isAtSameMomentAs(endDate))) {
          total += entry.amount;
          final temp = entry.copyWith(expectedDate: nextDate);
          nextDate = temp.getNextRecurringDate();
        }
      }
    }
    return total;
  }

  double getEstimatedYearlyTotal(int year) {
    double yearlyReceived = _receivedEntries
        .where((e) => (e.receivedDate ?? e.expectedDate).year == year)
        .fold(0.0, (sum, e) => sum + e.amount);

    double projected = 0.0;
    for (var entry in _upcomingEntries) {
      if (entry.expectedDate.year == year && !entry.isRecurring) {
        projected += entry.amount;
      } else if (entry.isRecurring && entry.recurringType != null) {
        // Add the current upcoming expected date if it falls in this year
        if (entry.expectedDate.year == year) {
          projected += entry.amount;
        }
        DateTime? nextDate = entry.getNextRecurringDate();
        while (nextDate != null && nextDate.year <= year) {
          if (nextDate.year == year) {
            projected += entry.amount;
          }
          final temp = entry.copyWith(expectedDate: nextDate);
          nextDate = temp.getNextRecurringDate();
        }
      }
    }
    return yearlyReceived + projected;
  }

  double getYearlyReceived(int year) {
    return _receivedEntries
        .where((e) => (e.receivedDate ?? e.expectedDate).year == year)
        .fold(0.0, (sum, e) => sum + e.amount);
  }


  
  double get thisMonthRemaining {
    final now = DateTime.now();
    return _upcomingEntries
        .where((e) =>
            e.expectedDate.isBefore(DateTime(now.year, now.month + 1, 1)))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get thisMonthReceived {
    final now = DateTime.now();
    return _receivedEntries
        .where((e) =>
            (e.receivedDate ?? e.expectedDate).year == now.year &&
            (e.receivedDate ?? e.expectedDate).month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  bool get isLoading => _isLoading;
  String? get searchQuery => _searchQuery;
  String? get filterType => _filterType;

  EntryModel? get nextUpcoming =>
      _upcomingEntries.isNotEmpty ? _upcomingEntries.first : null;

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _loadEntries(),
        _loadUpcoming(),
        _loadReceived(),
        _loadTotals(),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadEntries() async {
    _entries = await _dbHelper.getAllEntries(
      searchQuery: _searchQuery,
      type: _filterType,
    );
  }

  Future<void> _loadUpcoming() async {
    _upcomingEntries = await _dbHelper.getAllEntries(
      isReceived: false,
      searchQuery: _searchQuery,
      type: _filterType,
    );
  }

  Future<void> _loadReceived() async {
    _receivedEntries = await _dbHelper.getAllEntries(
      isReceived: true,
      searchQuery: _searchQuery,
      type: _filterType,
    );
  }

  Future<void> _loadTotals() async {
    _totalUpcoming = await _dbHelper.getTotalUpcomingAmount();
    _totalReceived = await _dbHelper.getTotalReceivedAmount();
    _totalAll = await _dbHelper.getTotalAllAmount();
  }

  Future<void> addEntry(EntryModel entry) async {
    await _dbHelper.insertEntry(entry);
    await loadAll();
    _rescheduleNotifications();
  }

  Future<void> updateEntry(EntryModel entry) async {
    await _dbHelper.updateEntry(entry);
    await loadAll();
    _rescheduleNotifications();
  }

  Future<void> deleteEntry(int id) async {
    await _dbHelper.deleteEntry(id);
    await loadAll();
    _rescheduleNotifications();
  }

  Future<void> markReceived(int id) async {
    // Get entry first to check if recurring
    final entry = await _dbHelper.getEntry(id);
    await _dbHelper.markAsReceived(id);

    // If recurring, create next occurrence
    if (entry != null && entry.isRecurring && entry.recurringType != null) {
      final nextDate = entry.getNextRecurringDate();
      if (nextDate != null) {
        final nextEntry = entry.copyWith(
          id: null,
          expectedDate: nextDate,
          isReceived: false,
          receivedDate: null,
        );
        await _dbHelper.insertEntry(nextEntry);
      }
    }

    await loadAll();
    _rescheduleNotifications();
  }

  Future<void> markUnreceived(int id) async {
    await _dbHelper.markAsUnreceived(id);
    await loadAll();
    _rescheduleNotifications();
  }

  void setSearchQuery(String? query) {
    _searchQuery = (query != null && query.isEmpty) ? null : query;
    Future.wait([_loadEntries(), _loadUpcoming(), _loadReceived()])
        .then((_) => notifyListeners());
  }

  void setFilterType(String? type) {
    _filterType = type;
    Future.wait([_loadEntries(), _loadUpcoming(), _loadReceived()])
        .then((_) => notifyListeners());
  }

  void clearFilters() {
    _searchQuery = null;
    _filterType = null;
    Future.wait([_loadEntries(), _loadUpcoming(), _loadReceived()])
        .then((_) => notifyListeners());
  }

  Map<String, double> getEstimatedAmountByType(int year) {
    final map = <String, double>{};

    // Include received entries for this year
    for (var entry in _receivedEntries) {
      final rDate = entry.receivedDate ?? entry.expectedDate;
      if (rDate.year == year) {
        map[entry.type] = (map[entry.type] ?? 0) + entry.amount;
      }
    }

    // Include upcoming entries for this year
    for (var entry in _upcomingEntries) {
      if (entry.expectedDate.year == year && !entry.isRecurring) {
        map[entry.type] = (map[entry.type] ?? 0) + entry.amount;
      } else if (entry.isRecurring && entry.recurringType != null) {
        if (entry.expectedDate.year == year) {
          map[entry.type] = (map[entry.type] ?? 0) + entry.amount;
        }
        DateTime? nextDate = entry.getNextRecurringDate();
        while (nextDate != null && nextDate.year <= year) {
          if (nextDate.year == year) {
            map[entry.type] = (map[entry.type] ?? 0) + entry.amount;
          }
          final temp = entry.copyWith(expectedDate: nextDate);
          nextDate = temp.getNextRecurringDate();
        }
      }
    }
    
    return map;
  }

  List<Map<String, dynamic>> getEstimatedMonthlySummary(int year) {
    final List<Map<String, dynamic>> results = [];
    for (int month = 1; month <= 12; month++) {
      double received = 0;
      double upcoming = 0;

      for (var entry in _entries) {
        if (entry.isReceived) {
          final rDate = entry.expectedDate;
          if (rDate.year == year && rDate.month == month) {
            received += entry.amount;
          }
        } else {
          if (entry.expectedDate.year == year && entry.expectedDate.month == month) {
            upcoming += entry.amount;
          }

          if (entry.isRecurring && entry.recurringType != null) {
            DateTime? nextDate = entry.getNextRecurringDate();
            while (nextDate != null && nextDate.year <= year) {
              if (nextDate.year == year && nextDate.month == month) {
                upcoming += entry.amount;
              }
              final temp = entry.copyWith(expectedDate: nextDate);
              nextDate = temp.getNextRecurringDate();
            }
          }
        }
      }

      results.add({
        'month': month,
        'received': received,
        'upcoming': upcoming,
      });
    }
    return results;
  }



  /// Reschedule all notifications in background
  void _rescheduleNotifications() {
    NotificationService()
        .scheduleAllEntryNotifications(_upcomingEntries)
        .catchError((e) => debugPrint('Notification reschedule error: $e'));
  }
}
