import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/category.dart';

class CategoryProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<CategoryModel> _categories = [];
  bool _isLoading = false;

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    try {
      _categories = await _dbHelper.getAllCategories();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCategory(CategoryModel category) async {
    await _dbHelper.insertCategory(category);
    await loadCategories();
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _dbHelper.updateCategory(category);
    await loadCategories();
  }

  Future<void> deleteCategory(int id) async {
    await _dbHelper.deleteCategory(id);
    await loadCategories();
  }

  String getCategoryName(int? categoryId) {
    if (categoryId == null) return 'Uncategorized';
    final category = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => CategoryModel(name: 'Unknown', icon: 'help', color: '#9E9E9E'),
    );
    return category.name;
  }

  CategoryModel? getCategoryById(int? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
