import 'package:drift/drift.dart';
import '../../errors/app_exceptions.dart';
import '../database.dart';

/// Aggregation of an employee with their financial advance and salary metrics.
class EmployeeWithStats {
  const EmployeeWithStats({
    required this.employee,
    this.pendingAdvancesPiasters = 0,
    this.currentMonthAdvancesPiasters = 0,
    this.totalSalariesPaidPiasters = 0,
  });

  final Employee employee;
  final int pendingAdvancesPiasters;
  final int currentMonthAdvancesPiasters;
  final int totalSalariesPaidPiasters;

  int get id => employee.id;
  String get name => employee.name;
  String get role => employee.role;
  String? get phone => employee.phone;
  String? get nationalId => employee.nationalId;
  int get basicSalaryPiasters => employee.basicSalary;
  String get salaryType => employee.salaryType;
  bool get isActive => employee.isActive;
  DateTime? get hireDate => employee.hireDate;
  String? get notes => employee.notes;
}

/// Aggregation of an advance with its employee.
class EmployeeAdvanceWithDetails {
  const EmployeeAdvanceWithDetails({
    required this.advance,
    required this.employee,
  });

  final EmployeeAdvance advance;
  final Employee employee;

  int get id => advance.id;
  int get employeeId => advance.employeeId;
  int get amountPiasters => advance.amount;
  DateTime get date => advance.date;
  PaymentMethod get paymentMethod => advance.paymentMethod;
  String? get notes => advance.notes;
  bool get isDeducted => advance.isDeducted;
}

/// Aggregation of a salary payout with its employee.
class SalaryPaymentWithDetails {
  const SalaryPaymentWithDetails({
    required this.payment,
    required this.employee,
  });

  final SalaryPayment payment;
  final Employee employee;

  int get id => payment.id;
  int get employeeId => payment.employeeId;
  int get year => payment.year;
  int get month => payment.month;
  int get basicSalaryPiasters => payment.basicSalary;
  int get advancesDeductedPiasters => payment.advancesDeducted;
  int get bonusPiasters => payment.bonusAmount;
  int get penaltyPiasters => payment.penaltyAmount;
  int get netPaidPiasters => payment.netPaid;
  DateTime get paymentDate => payment.paymentDate;
  PaymentMethod get paymentMethod => payment.paymentMethod;
  String? get notes => payment.notes;
}

/// Summary metrics for employees, advances, and payroll.
class EmployeesSummary {
  const EmployeesSummary({
    required this.totalEmployees,
    required this.activeEmployees,
    required this.totalBasicSalariesPiasters,
    required this.pendingAdvancesPiasters,
    required this.currentMonthPaidSalariesPiasters,
  });

  final int totalEmployees;
  final int activeEmployees;
  final int totalBasicSalariesPiasters;
  final int pendingAdvancesPiasters;
  final int currentMonthPaidSalariesPiasters;
}

/// Abstract contract for employee, payroll, and advance operations.
abstract interface class EmployeesRepository {
  Stream<List<EmployeeWithStats>> watchEmployees({bool activeOnly = false, String? searchQuery});
  Future<List<EmployeeWithStats>> getAllEmployees({bool activeOnly = false, String? searchQuery});
  Future<EmployeeWithStats?> getEmployeeById(int id);
  Future<int> insertEmployee(EmployeesCompanion companion);
  Future<bool> updateEmployee(int id, EmployeesCompanion companion);
  Future<bool> toggleEmployeeActive(int id);

  // Advances
  Stream<List<EmployeeAdvanceWithDetails>> watchAdvances({
    int? employeeId,
    bool? isDeducted,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<List<EmployeeAdvanceWithDetails>> getAdvances({
    int? employeeId,
    bool? isDeducted,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<int> createAdvance({
    required int employeeId,
    required int amount,
    required PaymentMethod paymentMethod,
    String? notes,
    DateTime? date,
  });
  Future<bool> deleteAdvance(int id);

  // Salaries & Payroll
  Stream<List<SalaryPaymentWithDetails>> watchSalaryPayments({
    int? employeeId,
    int? year,
    int? month,
  });
  Future<List<SalaryPaymentWithDetails>> getSalaryPayments({
    int? employeeId,
    int? year,
    int? month,
  });
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
  });
  Future<bool> deleteSalaryPayment(int id);

  Future<EmployeesSummary> getSummary();
}

/// Drift implementation of [EmployeesRepository].
class DriftEmployeesRepository implements EmployeesRepository {
  const DriftEmployeesRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$EmployeesTable, Employee> _buildEmployeesQuery({
    bool activeOnly = false,
    String? searchQuery,
  }) {
    final query = _db.select(_db.employees);
    if (activeOnly) {
      query.where((e) => e.isActive.equals(true));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      query.where((e) => e.name.like(term) | e.role.like(term) | e.phone.like(term));
    }
    query.orderBy([(e) => OrderingTerm.asc(e.name)]);
    return query;
  }

  Future<List<EmployeeWithStats>> _mapEmployeesWithStats(List<Employee> employeesList) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final result = <EmployeeWithStats>[];
    for (final emp in employeesList) {
      // Pending advances (not deducted yet)
      final pendingAdvancesQuery = _db.selectOnly(_db.employeeAdvances)
        ..addColumns([_db.employeeAdvances.amount.sum()])
        ..where(_db.employeeAdvances.employeeId.equals(emp.id) & _db.employeeAdvances.isDeducted.equals(false));
      final pendingSum = (await pendingAdvancesQuery.map((row) => row.read(_db.employeeAdvances.amount.sum())).getSingle()) ?? 0;

      // Current month advances
      final monthAdvancesQuery = _db.selectOnly(_db.employeeAdvances)
        ..addColumns([_db.employeeAdvances.amount.sum()])
        ..where(
          _db.employeeAdvances.employeeId.equals(emp.id) &
          _db.employeeAdvances.date.isBiggerOrEqualValue(monthStart) &
          _db.employeeAdvances.date.isSmallerOrEqualValue(monthEnd),
        );
      final monthSum = (await monthAdvancesQuery.map((row) => row.read(_db.employeeAdvances.amount.sum())).getSingle()) ?? 0;

      // Total salaries paid
      final salariesQuery = _db.selectOnly(_db.salaryPayments)
        ..addColumns([_db.salaryPayments.netPaid.sum()])
        ..where(_db.salaryPayments.employeeId.equals(emp.id));
      final salariesSum = (await salariesQuery.map((row) => row.read(_db.salaryPayments.netPaid.sum())).getSingle()) ?? 0;

      result.add(
        EmployeeWithStats(
          employee: emp,
          pendingAdvancesPiasters: pendingSum,
          currentMonthAdvancesPiasters: monthSum,
          totalSalariesPaidPiasters: salariesSum,
        ),
      );
    }
    return result;
  }

  @override
  Stream<List<EmployeeWithStats>> watchEmployees({bool activeOnly = false, String? searchQuery}) {
    final query = _buildEmployeesQuery(activeOnly: activeOnly, searchQuery: searchQuery);
    return query.watch().asyncMap(_mapEmployeesWithStats);
  }

  @override
  Future<List<EmployeeWithStats>> getAllEmployees({bool activeOnly = false, String? searchQuery}) async {
    final query = _buildEmployeesQuery(activeOnly: activeOnly, searchQuery: searchQuery);
    final list = await query.get();
    return _mapEmployeesWithStats(list);
  }

  @override
  Future<EmployeeWithStats?> getEmployeeById(int id) async {
    final emp = await (_db.select(_db.employees)..where((e) => e.id.equals(id))).getSingleOrNull();
    if (emp == null) return null;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final pendingAdvancesQuery = _db.selectOnly(_db.employeeAdvances)
      ..addColumns([_db.employeeAdvances.amount.sum()])
      ..where(_db.employeeAdvances.employeeId.equals(emp.id) & _db.employeeAdvances.isDeducted.equals(false));
    final pendingSum = (await pendingAdvancesQuery.map((row) => row.read(_db.employeeAdvances.amount.sum())).getSingle()) ?? 0;

    final monthAdvancesQuery = _db.selectOnly(_db.employeeAdvances)
      ..addColumns([_db.employeeAdvances.amount.sum()])
      ..where(
        _db.employeeAdvances.employeeId.equals(emp.id) &
        _db.employeeAdvances.date.isBiggerOrEqualValue(monthStart) &
        _db.employeeAdvances.date.isSmallerOrEqualValue(monthEnd),
      );
    final monthSum = (await monthAdvancesQuery.map((row) => row.read(_db.employeeAdvances.amount.sum())).getSingle()) ?? 0;

    final salariesQuery = _db.selectOnly(_db.salaryPayments)
      ..addColumns([_db.salaryPayments.netPaid.sum()])
      ..where(_db.salaryPayments.employeeId.equals(emp.id));
    final salariesSum = (await salariesQuery.map((row) => row.read(_db.salaryPayments.netPaid.sum())).getSingle()) ?? 0;

    return EmployeeWithStats(
      employee: emp,
      pendingAdvancesPiasters: pendingSum,
      currentMonthAdvancesPiasters: monthSum,
      totalSalariesPaidPiasters: salariesSum,
    );
  }

  @override
  Future<int> insertEmployee(EmployeesCompanion companion) {
    if (companion.name.value.trim().isEmpty) {
      throw const ValidationException('اسم الموظف مطلوب ولا يمكن تركه فارغاً.');
    }
    if (companion.role.value.trim().isEmpty) {
      throw const ValidationException('المسمى الوظيفي مطلوب.');
    }
    return _db.into(_db.employees).insert(companion);
  }

  @override
  Future<bool> updateEmployee(int id, EmployeesCompanion companion) async {
    final updated = await (_db.update(_db.employees)..where((e) => e.id.equals(id))).write(companion);
    return updated > 0;
  }

  @override
  Future<bool> toggleEmployeeActive(int id) async {
    final emp = await (_db.select(_db.employees)..where((e) => e.id.equals(id))).getSingleOrNull();
    if (emp == null) return false;
    final updated = await (_db.update(_db.employees)..where((e) => e.id.equals(id))).write(
      EmployeesCompanion(isActive: Value(!emp.isActive)),
    );
    return updated > 0;
  }

  // ── Advances ───────────────────────────────────────────────────────────────

  JoinedSelectStatement _buildAdvancesQuery({
    int? employeeId,
    bool? isDeducted,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final query = _db.select(_db.employeeAdvances).join([
      innerJoin(_db.employees, _db.employees.id.equalsExp(_db.employeeAdvances.employeeId)),
    ]);

    if (employeeId != null) {
      query.where(_db.employeeAdvances.employeeId.equals(employeeId));
    }
    if (isDeducted != null) {
      query.where(_db.employeeAdvances.isDeducted.equals(isDeducted));
    }
    if (startDate != null) {
      query.where(_db.employeeAdvances.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(_db.employeeAdvances.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([OrderingTerm.desc(_db.employeeAdvances.date)]);
    return query;
  }

  @override
  Stream<List<EmployeeAdvanceWithDetails>> watchAdvances({
    int? employeeId,
    bool? isDeducted,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _buildAdvancesQuery(
      employeeId: employeeId,
      isDeducted: isDeducted,
      startDate: startDate,
      endDate: endDate,
    ).watch().map((rows) {
      return rows.map((row) {
        return EmployeeAdvanceWithDetails(
          advance: row.readTable(_db.employeeAdvances),
          employee: row.readTable(_db.employees),
        );
      }).toList();
    });
  }

  @override
  Future<List<EmployeeAdvanceWithDetails>> getAdvances({
    int? employeeId,
    bool? isDeducted,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final rows = await _buildAdvancesQuery(
      employeeId: employeeId,
      isDeducted: isDeducted,
      startDate: startDate,
      endDate: endDate,
    ).get();
    return rows.map((row) {
      return EmployeeAdvanceWithDetails(
        advance: row.readTable(_db.employeeAdvances),
        employee: row.readTable(_db.employees),
      );
    }).toList();
  }

  @override
  Future<int> createAdvance({
    required int employeeId,
    required int amount,
    required PaymentMethod paymentMethod,
    String? notes,
    DateTime? date,
  }) {
    if (amount <= 0) {
      throw const ValidationException('مبلغ السلفة يجب أن يكون أكبر من الصفر.');
    }
    return _db.into(_db.employeeAdvances).insert(
      EmployeeAdvancesCompanion(
        employeeId: Value(employeeId),
        amount: Value(amount),
        paymentMethod: Value(paymentMethod),
        notes: Value(notes?.trim()),
        date: Value(date ?? DateTime.now()),
      ),
    );
  }

  @override
  Future<bool> deleteAdvance(int id) async {
    final adv = await (_db.select(_db.employeeAdvances)..where((a) => a.id.equals(id))).getSingleOrNull();
    if (adv == null) return false;
    if (adv.isDeducted) {
      throw const BusinessRuleException('لا يمكن حذف سلفة تم خصمها بالفعل في مسير راتب معتمد.');
    }
    final count = await (_db.delete(_db.employeeAdvances)..where((a) => a.id.equals(id))).go();
    return count > 0;
  }

  // ── Salaries & Payroll ─────────────────────────────────────────────────────

  JoinedSelectStatement _buildSalaryPaymentsQuery({
    int? employeeId,
    int? year,
    int? month,
  }) {
    final query = _db.select(_db.salaryPayments).join([
      innerJoin(_db.employees, _db.employees.id.equalsExp(_db.salaryPayments.employeeId)),
    ]);

    if (employeeId != null) {
      query.where(_db.salaryPayments.employeeId.equals(employeeId));
    }
    if (year != null) {
      query.where(_db.salaryPayments.year.equals(year));
    }
    if (month != null) {
      query.where(_db.salaryPayments.month.equals(month));
    }

    query.orderBy([
      OrderingTerm.desc(_db.salaryPayments.paymentDate),
      OrderingTerm.desc(_db.salaryPayments.id),
    ]);
    return query;
  }

  @override
  Stream<List<SalaryPaymentWithDetails>> watchSalaryPayments({
    int? employeeId,
    int? year,
    int? month,
  }) {
    return _buildSalaryPaymentsQuery(
      employeeId: employeeId,
      year: year,
      month: month,
    ).watch().map((rows) {
      return rows.map((row) {
        return SalaryPaymentWithDetails(
          payment: row.readTable(_db.salaryPayments),
          employee: row.readTable(_db.employees),
        );
      }).toList();
    });
  }

  @override
  Future<List<SalaryPaymentWithDetails>> getSalaryPayments({
    int? employeeId,
    int? year,
    int? month,
  }) async {
    final rows = await _buildSalaryPaymentsQuery(
      employeeId: employeeId,
      year: year,
      month: month,
    ).get();
    return rows.map((row) {
      return SalaryPaymentWithDetails(
        payment: row.readTable(_db.salaryPayments),
        employee: row.readTable(_db.employees),
      );
    }).toList();
  }

  @override
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
  }) {
    if (basicSalary < 0 || netPaid < 0) {
      throw const ValidationException('قيمة الراتب لا يمكن أن تكون سالبة.');
    }

    return _db.transaction(() async {
      // 1. Insert salary payment record
      final paymentId = await _db.into(_db.salaryPayments).insert(
        SalaryPaymentsCompanion(
          employeeId: Value(employeeId),
          year: Value(year),
          month: Value(month),
          basicSalary: Value(basicSalary),
          advancesDeducted: Value(advancesDeducted),
          bonusAmount: Value(bonusAmount),
          penaltyAmount: Value(penaltyAmount),
          netPaid: Value(netPaid),
          paymentMethod: Value(paymentMethod),
          notes: Value(notes?.trim()),
          paymentDate: Value(paymentDate ?? DateTime.now()),
        ),
      );

      // 2. Mark deducted advances
      if (advanceIdsToDeduct != null && advanceIdsToDeduct.isNotEmpty) {
        await (_db.update(_db.employeeAdvances)
          ..where((a) => a.id.isIn(advanceIdsToDeduct)))
          .write(
            EmployeeAdvancesCompanion(
              isDeducted: const Value(true),
              salaryPaymentId: Value(paymentId),
            ),
          );
      }

      return paymentId;
    });
  }

  @override
  Future<bool> deleteSalaryPayment(int id) {
    return _db.transaction(() async {
      // Un-mark any deducted advances
      await (_db.update(_db.employeeAdvances)..where((a) => a.salaryPaymentId.equals(id))).write(
        const EmployeeAdvancesCompanion(
          isDeducted: Value(false),
          salaryPaymentId: Value(null),
        ),
      );

      final count = await (_db.delete(_db.salaryPayments)..where((p) => p.id.equals(id))).go();
      return count > 0;
    });
  }

  @override
  Future<EmployeesSummary> getSummary() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final allEmps = await _db.select(_db.employees).get();
    final totalEmployees = allEmps.length;
    final activeEmployees = allEmps.where((e) => e.isActive).length;
    final totalBasicSalaries = allEmps.where((e) => e.isActive).fold<int>(0, (sum, e) => sum + e.basicSalary);

    // Pending advances
    final pendingAdvancesQuery = _db.selectOnly(_db.employeeAdvances)
      ..addColumns([_db.employeeAdvances.amount.sum()])
      ..where(_db.employeeAdvances.isDeducted.equals(false));
    final pendingAdvances = (await pendingAdvancesQuery.map((row) => row.read(_db.employeeAdvances.amount.sum())).getSingle()) ?? 0;

    // This month paid salaries
    final thisMonthPaidQuery = _db.selectOnly(_db.salaryPayments)
      ..addColumns([_db.salaryPayments.netPaid.sum()])
      ..where(
        _db.salaryPayments.paymentDate.isBiggerOrEqualValue(monthStart) &
        _db.salaryPayments.paymentDate.isSmallerOrEqualValue(monthEnd),
      );
    final paidThisMonth = (await thisMonthPaidQuery.map((row) => row.read(_db.salaryPayments.netPaid.sum())).getSingle()) ?? 0;

    return EmployeesSummary(
      totalEmployees: totalEmployees,
      activeEmployees: activeEmployees,
      totalBasicSalariesPiasters: totalBasicSalaries,
      pendingAdvancesPiasters: pendingAdvances,
      currentMonthPaidSalariesPiasters: paidThisMonth,
    );
  }
}
