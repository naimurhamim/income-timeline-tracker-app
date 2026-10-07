import 'package:flutter/foundation.dart';
import '../data/data_repository.dart';
import '../models/category.dart';

class CategoryProvider extends ChangeNotifier {
  CategoryProvider() {
    DataStore.instance.addListener(_onRepositoryChanged);
  }

  DataRepository get _repo => DataStore.instance.repo;

  List<CategoryModel> _categories = [];
  bool _isLoading = false;

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;

  void _onRepositoryChanged() => loadCategories(preferServer: true);

  Future<void> loadCategories({bool preferServer = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _categories = await _repo.getCategories();

      if (_repo.isCloud && preferServer) {
        _repo.getCategories(preferServer: true).then((fresh) {
          if (!identical(_repo, DataStore.instance.repo)) return;
          _categories = fresh;
          notifyListeners();
        }).catchError((Object e) {
          debugPrint('Background category refresh failed: $e');
        });
      }
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(CategoryModel category) async {
    await _repo.saveCategory(category);
    await loadCategories();
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _repo.saveCategory(category);
    await loadCategories();
  }

  Future<void> deleteCategory(String id) async {
    await _repo.deleteCategory(id);
    await loadCategories();
  }

  String getCategoryName(String? categoryId) {
    if (categoryId == null) return 'Uncategorized';
    final category = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => CategoryModel(name: 'Unknown', icon: 'help', color: '#9E9E9E'),
    );
    return category.name;
  }

  CategoryModel? getCategoryById(String? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    DataStore.instance.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
