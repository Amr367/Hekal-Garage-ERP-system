import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/db/repositories/expenses_repository.dart';

/// Currently selected expense category filter ('الكل' or specific category).
class SelectedExpenseCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'الكل';

  void setCategory(String category) => state = category;
}

final selectedExpenseCategoryProvider =
    NotifierProvider<SelectedExpenseCategoryNotifier, String>(
  SelectedExpenseCategoryNotifier.new,
);

/// Search query filter for expenses.
class ExpensesSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final expensesSearchQueryProvider =
    NotifierProvider<ExpensesSearchQueryNotifier, String>(
  ExpensesSearchQueryNotifier.new,
);

/// List of expenses based on selected filters.
final expensesListProvider = FutureProvider<List<ExpenseWithDetails>>((ref) async {
  final repo = ref.watch(expensesRepositoryProvider);
  final category = ref.watch(selectedExpenseCategoryProvider);
  final query = ref.watch(expensesSearchQueryProvider);

  return repo.getExpenses(
    category: category == 'الكل' ? null : category,
    searchQuery: query,
  );
});

/// Summary metrics for expenses (today, this month, total).
final expensesSummaryProvider = FutureProvider<ExpensesSummary>((ref) async {
  final repo = ref.watch(expensesRepositoryProvider);
  return repo.getSummary();
});

/// Controller handling expense creation, edits, and deletions.
final expensesActionsControllerProvider = Provider<ExpensesActionsController>((ref) {
  return ExpensesActionsController(ref);
});

class ExpensesActionsController {
  const ExpensesActionsController(this._ref);

  final Ref _ref;
  ExpensesRepository get _repo => _ref.read(expensesRepositoryProvider);

  Future<int> addExpense(ExpensesCompanion companion) async {
    final id = await _repo.insertExpense(companion);
    _ref.invalidate(expensesListProvider);
    _ref.invalidate(expensesSummaryProvider);
    return id;
  }

  Future<bool> updateExpense(int id, ExpensesCompanion companion) async {
    final ok = await _repo.updateExpense(id, companion);
    _ref.invalidate(expensesListProvider);
    _ref.invalidate(expensesSummaryProvider);
    return ok;
  }

  Future<bool> deleteExpense(int id) async {
    final ok = await _repo.deleteExpense(id);
    _ref.invalidate(expensesListProvider);
    _ref.invalidate(expensesSummaryProvider);
    return ok;
  }
}
