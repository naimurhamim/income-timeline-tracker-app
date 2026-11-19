import 'package:flutter/foundation.dart';
import '../data/data_repository.dart';
import '../models/investment.dart';

/// Manages principal capital investment records (FD, Savings, Gold, Pension, custom).
class InvestmentProvider extends ChangeNotifier {
  InvestmentProvider() {
    DataStore.instance.addListener(_onRepositoryChanged);
  }

  DataRepository get _repo => DataStore.instance.repo;

  List<InvestmentModel> _investments = [];
  bool _isLoading = false;
  String? _selectedTypeFilter;
  String _searchQuery = '';

  List<InvestmentModel> get allInvestments => _investments;
  bool get isLoading => _isLoading;
  String? get selectedTypeFilter => _selectedTypeFilter;
  String get searchQuery => _searchQuery;

  List<InvestmentModel> get filteredInvestments {
    final filter = _selectedTypeFilter?.trim().toLowerCase();
    final query = _searchQuery.trim().toLowerCase();

    return _investments.where((inv) {
      if (filter != null &&
          filter.isNotEmpty &&
          inv.type.trim().toLowerCase() != filter) {
        return false;
      }
      if (query.isNotEmpty) {
        final inTitle = inv.title.toLowerCase().contains(query);
        final inType = inv.type.toLowerCase().contains(query);
        final inNotes = inv.notes?.toLowerCase().contains(query) ?? false;
        if (!inTitle && !inType && !inNotes) return false;
      }
      return true;
    }).toList();
  }

  double get totalInvested =>
      _investments.fold(0.0, (sum, inv) => sum + inv.amount);

  double get filteredTotal =>
      filteredInvestments.fold(0.0, (sum, inv) => sum + inv.amount);

  /// Total invested grouped by type, sorted from largest to smallest.
  Map<String, double> get totalsByType {
    final grouped = <String, double>{};
    final labels = <String, String>{};
    for (final inv in _investments) {
      final key = inv.type.trim().toLowerCase();
      final canonical =
          InvestmentModel.presetForType(inv.type)?.name ?? inv.type.trim();
      labels.putIfAbsent(key, () => canonical);
      grouped[key] = (grouped[key] ?? 0.0) + inv.amount;
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => grouped[b]!.compareTo(grouped[a]!));

    return {
      for (final key in sortedKeys) labels[key]!: grouped[key]!,
    };
  }

  /// Built-in types followed by any custom types used in existing investments.
  List<InvestmentTypePreset> get allAvailableTypePresets {
    final presets = <InvestmentTypePreset>[...InvestmentModel.defaultTypes];
    final seen = presets.map((p) => p.name.trim().toLowerCase()).toSet();

    for (final inv in _investments) {
      final normalized = inv.type.trim().toLowerCase();
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      presets.add(InvestmentTypePreset(
        name: inv.type.trim(),
        icon: inv.icon,
        color: inv.color,
      ));
    }
    return presets;
  }

  void _onRepositoryChanged() {
    _selectedTypeFilter = null;
    _searchQuery = '';
    loadInvestments(preferServer: true);
  }

  Future<void> loadInvestments({bool preferServer = false}) async {
    final repo = _repo;
    _isLoading = true;
    notifyListeners();

    try {
      final loaded = await repo.getInvestments();
      if (!identical(repo, DataStore.instance.repo)) return;
      _investments = loaded;

      if (repo.isCloud && preferServer) {
        repo.getInvestments(preferServer: true).then((fresh) {
          if (!identical(repo, DataStore.instance.repo)) return;
          _investments = fresh;
          notifyListeners();
        }).catchError((Object e) {
          debugPrint('Background investment refresh failed: $e');
        });
      }
    } catch (e) {
      debugPrint('Failed to load investments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addInvestment(InvestmentModel investment) async {
    await _repo.saveInvestment(investment);
    await loadInvestments();
  }

  Future<void> updateInvestment(InvestmentModel investment) async {
    await _repo.saveInvestment(investment);
    await loadInvestments();
  }

  Future<void> deleteInvestment(String id) async {
    await _repo.deleteInvestment(id);
    await loadInvestments();
  }

  void setTypeFilter(String? type) {
    final normalized = type?.trim();
    if (_selectedTypeFilter?.toLowerCase() == normalized?.toLowerCase()) {
      _selectedTypeFilter = null;
    } else {
      _selectedTypeFilter = normalized;
    }
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  @override
  void dispose() {
    DataStore.instance.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
