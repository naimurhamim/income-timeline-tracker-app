import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:money_tracker/data/data_repository.dart';
import 'package:money_tracker/main.dart';
import 'package:money_tracker/models/category.dart';
import 'package:money_tracker/models/entry.dart';
import 'package:money_tracker/models/investment.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemoryTestRepository implements DataRepository {
  @override
  bool get isCloud => false;

  @override
  Future<List<EntryModel>> getEntries({bool preferServer = false}) async =>
      const [];

  @override
  Future<void> saveEntry(EntryModel entry) async {}

  @override
  Future<void> deleteEntry(String id) async {}

  @override
  Future<List<CategoryModel>> getCategories({
    bool preferServer = false,
  }) async =>
      const [];

  @override
  Future<void> saveCategory(CategoryModel category) async {}

  @override
  Future<void> deleteCategory(String id) async {}

  @override
  Future<List<InvestmentModel>> getInvestments({
    bool preferServer = false,
  }) async =>
      const [];

  @override
  Future<void> saveInvestment(InvestmentModel investment) async {}

  @override
  Future<void> deleteInvestment(String id) async {}

  @override
  Future<void> saveAll({
    List<CategoryModel> categories = const [],
    List<EntryModel> entries = const [],
    List<InvestmentModel> investments = const [],
    bool waitForServer = false,
    void Function(int done, int total)? onProgress,
  }) async {}

  @override
  Future<void> clearAll({bool waitForServer = false}) async {}
}

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    DataStore.init(_InMemoryTestRepository());

    await tester.pumpWidget(const MoneyTrackerApp());
    expect(find.text('Money Tracker'), findsOneWidget);
  });
}
