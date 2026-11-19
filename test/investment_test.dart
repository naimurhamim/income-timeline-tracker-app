import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/data/data_repository.dart';
import 'package:money_tracker/models/category.dart';
import 'package:money_tracker/models/entry.dart';
import 'package:money_tracker/models/investment.dart';
import 'package:money_tracker/widgets/calculator_keyboard.dart';

void main() {
  group('CalculatorEvaluator', () {
    test('evaluates basic arithmetic operations', () {
      expect(CalculatorEvaluator.evaluate('50000+15000'), 65000.0);
      expect(CalculatorEvaluator.evaluate('50000-12000'), 38000.0);
      expect(CalculatorEvaluator.evaluate('2500×4'), 10000.0);
      expect(CalculatorEvaluator.evaluate('10000÷4'), 2500.0);
    });

    test('respects operator precedence', () {
      expect(CalculatorEvaluator.evaluate('50000+2×5000'), 60000.0);
      expect(CalculatorEvaluator.evaluate('100-20÷4'), 95.0);
    });

    test('handles decimals and floating-point rounding cleanly', () {
      expect(CalculatorEvaluator.evaluate('0.1+0.2'), 0.3);
      expect(CalculatorEvaluator.evaluate('1000.5+250.25'), 1250.75);
    });

    test('strips trailing operators for live preview', () {
      expect(CalculatorEvaluator.evaluate('50000+'), 50000.0);
      expect(CalculatorEvaluator.evaluate('50000×'), 50000.0);
      expect(CalculatorEvaluator.evaluate('50000+.'), 50000.0);
    });

    test('returns null on division by zero or invalid input', () {
      expect(CalculatorEvaluator.evaluate('100÷0'), isNull);
      expect(CalculatorEvaluator.evaluate(''), isNull);
      expect(CalculatorEvaluator.evaluate('+'), isNull);
    });

    test('returns negative value when subtraction goes below zero', () {
      expect(CalculatorEvaluator.evaluate('100-250'), -150.0);
    });

    test('formats numbers cleanly without trailing decimal zeros', () {
      expect(CalculatorEvaluator.formatNumber(50000.0), '50000');
      expect(CalculatorEvaluator.formatNumber(12500.5), '12500.5');
      expect(CalculatorEvaluator.formatNumber(12500.25), '12500.25');
    });
  });

  group('InvestmentModel', () {
    test('toMap and fromMap round-trip preserves all fields', () {
      final date = DateTime(2026, 6, 15);
      final created = DateTime(2026, 6, 15, 10, 30);
      final updated = DateTime(2026, 6, 16, 11, 0);

      final original = InvestmentModel(
        id: 'inv-1',
        title: 'Sonali Bank FD',
        amount: 250000.5,
        type: 'FD',
        icon: 'account_balance',
        color: '#1B3A4B',
        investedDate: date,
        notes: '3-year term',
        createdAt: created,
        updatedAt: updated,
      );

      final restored = InvestmentModel.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.amount, original.amount);
      expect(restored.type, original.type);
      expect(restored.icon, original.icon);
      expect(restored.color, original.color);
      expect(restored.investedDate, original.investedDate);
      expect(restored.notes, original.notes);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('copyWith clears nullable notes when null is passed', () {
      final original = InvestmentModel(
        id: 'inv-2',
        title: '2 Vori Gold',
        amount: 300000,
        type: 'Gold',
        notes: '22K',
      );

      final cleared = original.copyWith(notes: null);
      expect(cleared.notes, isNull);
      expect(cleared.title, '2 Vori Gold');
    });
  });

  group('mergeIncoming with investments', () {
    final date = DateTime(2026, 5, 10);

    test('skips duplicate investment with different ID and same content', () {
      final existing = InvestmentModel(
        id: 'cloud-1',
        title: 'Emergency Savings',
        amount: 100000,
        type: 'Savings',
        investedDate: date,
      );
      final duplicate = InvestmentModel(
        id: 'local-1',
        title: 'emergency savings ',
        amount: 100000,
        type: 'savings',
        investedDate: date,
      );

      final result = mergeIncoming(
        existing: CategoryModel.defaultCategories,
        incomingCategories: const [],
        incomingEntries: const [],
        existingInvestments: [existing],
        incomingInvestments: [duplicate],
      );

      expect(result.investments, isEmpty);
      expect(result.skippedDuplicates, 1);
    });

    test('keeps same-ID overwrite without incrementing skippedDuplicates', () {
      final existing = InvestmentModel(
        id: 'shared-1',
        title: 'NPS Pension',
        amount: 50000,
        type: 'Pension',
        investedDate: date,
      );
      final updated = existing.copyWith(amount: 60000);

      final result = mergeIncoming(
        existing: CategoryModel.defaultCategories,
        incomingCategories: const [],
        incomingEntries: const [],
        existingInvestments: [existing],
        incomingInvestments: [updated],
      );

      expect(result.investments.length, 1);
      expect(result.investments.first.amount, 60000);
      expect(result.skippedDuplicates, 0);
    });

    test('keeps distinct investment alongside entries and categories', () {
      final customCat = CategoryModel(
        id: 'cat-1',
        name: 'Freelance',
        icon: 'business',
        color: '#2D5F4F',
      );
      final entry = EntryModel(
        id: 'entry-1',
        title: 'Project Payout',
        amount: 25000,
        expectedDate: date,
        type: 'Freelance',
        categoryId: 'cat-1',
      );
      final investment = InvestmentModel(
        id: 'inv-10',
        title: 'Gold Bar',
        amount: 150000,
        type: 'Gold',
        investedDate: date,
      );

      final result = mergeIncoming(
        existing: CategoryModel.defaultCategories,
        incomingCategories: [customCat],
        incomingEntries: [entry],
        existingInvestments: const [],
        incomingInvestments: [investment, investment.copyWith(id: 'inv-11')],
      );

      expect(result.categories.length, 1);
      expect(result.entries.length, 1);
      expect(result.investments.length, 1);
      expect(result.investments.first.id, 'inv-10');
      expect(result.skippedDuplicates, 1);
    });
  });
}
