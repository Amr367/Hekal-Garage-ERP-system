import 'package:drift/drift.dart';
import '../../errors/app_exceptions.dart';
import '../database.dart';

/// Aggregation of an expense entry.
class ExpenseWithDetails {
  const ExpenseWithDetails({
    required this.expense,
  });

  final Expense expense;

  int get id => expense.id;
  String get category => expense.category;
  int get amountPiasters => expense.amount;
  DateTime get expenseDate => expense.expenseDate;
  String get description => expense.description;
  String? get paidTo => expense.paidTo;
  PaymentMethod get paymentMethod => expense.paymentMethod;
  String? get receiptNumber => expense.receiptNumber;
  String? get notes => expense.notes;
}

/// Financial summary of expenses.
class ExpensesSummary {
  const ExpensesSummary({
    required this.totalPiasters,
    required this.todayPiasters,
    required this.thisMonthPiasters,
    required this.categoryBreakdown,
    required this.count,
  });

  final int totalPiasters;
  final int todayPiasters;
  final int thisMonthPiasters;
  final Map<String, int> categoryBreakdown;
  final int count;
}

/// Abstract contract for managing workshop expenses.
abstract interface class ExpensesRepository {
  Stream<List<ExpenseWithDetails>> watchExpenses({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  });
  Future<List<ExpenseWithDetails>> getExpenses({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  });
  Future<ExpenseWithDetails?> getExpenseById(int id);
  Future<int> insertExpense(ExpensesCompanion companion);
  Future<bool> updateExpense(int id, ExpensesCompanion companion);
  Future<bool> deleteExpense(int id);
  Future<ExpensesSummary> getSummary({DateTime? startDate, DateTime? endDate});
}

/// Drift implementation of [ExpensesRepository].
class DriftExpensesRepository implements ExpensesRepository {
  const DriftExpensesRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$ExpensesTable, Expense> _buildExpensesQuery({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) {
    final query = _db.select(_db.expenses);

    if (category != null && category.isNotEmpty && category != 'الكل') {
      query.where((e) => e.category.equals(category));
    }
    if (startDate != null) {
      query.where((e) => e.expenseDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((e) => e.expenseDate.isSmallerOrEqualValue(endDate));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      query.where((e) => e.description.like(term) | e.paidTo.like(term) | e.receiptNumber.like(term) | e.category.like(term));
    }

    query.orderBy([
      (e) => OrderingTerm.desc(e.expenseDate),
      (e) => OrderingTerm.desc(e.id),
    ]);

    return query;
  }

  @override
  Stream<List<ExpenseWithDetails>> watchExpenses({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) {
    final query = _buildExpensesQuery(
      category: category,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );

    return query.watch().map((list) {
      return list.map((e) => ExpenseWithDetails(expense: e)).toList();
    });
  }

  @override
  Future<List<ExpenseWithDetails>> getExpenses({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final query = _buildExpensesQuery(
      category: category,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );

    final list = await query.get();
    return list.map((e) => ExpenseWithDetails(expense: e)).toList();
  }

  @override
  Future<ExpenseWithDetails?> getExpenseById(int id) async {
    final exp = await (_db.select(_db.expenses)..where((e) => e.id.equals(id))).getSingleOrNull();
    return exp != null ? ExpenseWithDetails(expense: exp) : null;
  }

  @override
  Future<int> insertExpense(ExpensesCompanion companion) {
    if (companion.amount.value <= 0) {
      throw const ValidationException('مبلغ المصروف يجب أن يكون أكبر من الصفر.');
    }
    if (companion.description.value.trim().isEmpty) {
      throw const ValidationException('بيان وتفاصيل المصروف مطلوبة.');
    }
    return _db.into(_db.expenses).insert(companion);
  }

  @override
  Future<bool> updateExpense(int id, ExpensesCompanion companion) async {
    if (companion.amount.present && companion.amount.value <= 0) {
      throw const ValidationException('مبلغ المصروف يجب أن يكون أكبر من الصفر.');
    }
    final count = await (_db.update(_db.expenses)..where((e) => e.id.equals(id))).write(companion);
    return count > 0;
  }

  @override
  Future<bool> deleteExpense(int id) async {
    final count = await (_db.delete(_db.expenses)..where((e) => e.id.equals(id))).go();
    return count > 0;
  }

  @override
  Future<ExpensesSummary> getSummary({DateTime? startDate, DateTime? endDate}) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Filtered / Period expenses
    final periodQuery = _db.select(_db.expenses);
    if (startDate != null) {
      periodQuery.where((e) => e.expenseDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      periodQuery.where((e) => e.expenseDate.isSmallerOrEqualValue(endDate));
    }
    final periodList = await periodQuery.get();

    final totalPiasters = periodList.fold<int>(0, (sum, e) => sum + e.amount);

    final categoryBreakdown = <String, int>{};
    for (final e in periodList) {
      categoryBreakdown[e.category] = (categoryBreakdown[e.category] ?? 0) + e.amount;
    }

    // Today amount
    final todayQuery = _db.selectOnly(_db.expenses)
      ..addColumns([_db.expenses.amount.sum()])
      ..where(
        _db.expenses.expenseDate.isBiggerOrEqualValue(todayStart) &
        _db.expenses.expenseDate.isSmallerOrEqualValue(todayEnd),
      );
    final todayPiasters = (await todayQuery.map((row) => row.read(_db.expenses.amount.sum())).getSingle()) ?? 0;

    // This month amount
    final monthQuery = _db.selectOnly(_db.expenses)
      ..addColumns([_db.expenses.amount.sum()])
      ..where(
        _db.expenses.expenseDate.isBiggerOrEqualValue(monthStart) &
        _db.expenses.expenseDate.isSmallerOrEqualValue(monthEnd),
      );
    final thisMonthPiasters = (await monthQuery.map((row) => row.read(_db.expenses.amount.sum())).getSingle()) ?? 0;

    return ExpensesSummary(
      totalPiasters: totalPiasters,
      todayPiasters: todayPiasters,
      thisMonthPiasters: thisMonthPiasters,
      categoryBreakdown: categoryBreakdown,
      count: periodList.length,
    );
  }
}
