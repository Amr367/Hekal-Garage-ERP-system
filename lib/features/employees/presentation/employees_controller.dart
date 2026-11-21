import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/db/repositories/employees_repository.dart';

/// Search query filter for employees.
class EmployeesSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final employeesSearchQueryProvider =
    NotifierProvider<EmployeesSearchQueryNotifier, String>(
  EmployeesSearchQueryNotifier.new,
);

/// List of all employees with their metrics.
final employeesListProvider = FutureProvider<List<EmployeeWithStats>>((ref) async {
  final repo = ref.watch(employeesRepositoryProvider);
  final query = ref.watch(employeesSearchQueryProvider);
  return repo.getAllEmployees(searchQuery: query);
});

/// Summary metrics for employees, pending advances, and monthly payroll.
final employeesSummaryProvider = FutureProvider<EmployeesSummary>((ref) async {
  final repo = ref.watch(employeesRepositoryProvider);
  return repo.getSummary();
});

/// List of employee advances (filtered optionally by employee).
final employeeAdvancesProvider = FutureProvider.family<List<EmployeeAdvanceWithDetails>, int?>((ref, employeeId) async {
  final repo = ref.watch(employeesRepositoryProvider);
  return repo.getAdvances(employeeId: employeeId);
});

/// List of salary payout history.
final salaryPaymentsProvider = FutureProvider.family<List<SalaryPaymentWithDetails>, int?>((ref, employeeId) async {
  final repo = ref.watch(employeesRepositoryProvider);
  return repo.getSalaryPayments(employeeId: employeeId);
});

/// Controller for employee actions, advances, and payroll.
final employeesActionsControllerProvider = Provider<EmployeesActionsController>((ref) {
  return EmployeesActionsController(ref);
});

class EmployeesActionsController {
  const EmployeesActionsController(this._ref);

  final Ref _ref;
  EmployeesRepository get _repo => _ref.read(employeesRepositoryProvider);

  void _invalidateAll() {
    _ref.invalidate(employeesListProvider);
    _ref.invalidate(employeesSummaryProvider);
    _ref.invalidate(employeeAdvancesProvider);
    _ref.invalidate(salaryPaymentsProvider);
  }

  Future<int> addEmployee(EmployeesCompanion companion) async {
    final id = await _repo.insertEmployee(companion);
    _invalidateAll();
    return id;
  }

  Future<bool> updateEmployee(int id, EmployeesCompanion companion) async {
    final ok = await _repo.updateEmployee(id, companion);
    _invalidateAll();
    return ok;
  }

  Future<bool> toggleEmployeeActive(int id) async {
    final ok = await _repo.toggleEmployeeActive(id);
    _invalidateAll();
    return ok;
  }

  Future<int> recordAdvance({
    required int employeeId,
    required int amount,
    required PaymentMethod paymentMethod,
    String? notes,
    DateTime? date,
  }) async {
    final id = await _repo.createAdvance(
      employeeId: employeeId,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
      date: date,
    );
    _invalidateAll();
    return id;
  }

  Future<bool> deleteAdvance(int id) async {
    final ok = await _repo.deleteAdvance(id);
    _invalidateAll();
    return ok;
  }

  Future<int> paySalary({
    required int employeeId,
    required int year,
    required int month,
    required int basicSalary,
    required int advancesDeducted,
    required int bonusAmount,
    required int penaltyAmount,
    required int netPaid,
    required PaymentMethod paymentMethod,
    String? notes,
    DateTime? paymentDate,
    List<int>? advanceIdsToDeduct,
  }) async {
    final id = await _repo.paySalary(
      employeeId: employeeId,
      year: year,
      month: month,
      basicSalary: basicSalary,
      advancesDeducted: advancesDeducted,
      bonusAmount: bonusAmount,
      penaltyAmount: penaltyAmount,
      netPaid: netPaid,
      paymentMethod: paymentMethod,
      notes: notes,
      paymentDate: paymentDate,
      advanceIdsToDeduct: advanceIdsToDeduct,
    );
    _invalidateAll();
    return id;
  }

  Future<bool> deleteSalaryPayment(int id) async {
    final ok = await _repo.deleteSalaryPayment(id);
    _invalidateAll();
    return ok;
  }
}
