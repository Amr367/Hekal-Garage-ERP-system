import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/providers.dart';
import 'package:garage_erp/core/db/repositories/employees_repository.dart';
import 'package:garage_erp/core/db/repositories/reports_repository.dart';
import 'package:garage_erp/core/db/services/stock_service.dart';
import 'package:garage_erp/core/strings.dart';
import 'package:garage_erp/core/theme/app_theme.dart';
import 'package:garage_erp/features/employees/employees_page.dart';
import 'package:garage_erp/features/employees/presentation/widgets/employee_form_dialog.dart';
import 'package:garage_erp/features/reports/domain/report_date_range.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late EmployeesRepository employeesRepo;
  late ReportsRepository reportsRepo;
  late StockService stockService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    employeesRepo = DriftEmployeesRepository(db);
    stockService = StockService(db);
    reportsRepo = DriftReportsRepository(db, stockService);
  });

  tearDown(() async {
    await db.close();
  });

  group('EmployeesRepository Tests', () {
    test('insertEmployee and getAllEmployees retrieves employee records', () async {
      final now = DateTime.now();
      final id = await employeesRepo.insertEmployee(
        EmployeesCompanion(
          name: const drift.Value('محمود حسن'),
          role: const drift.Value('فني ميكانيكا أول'),
          phone: const drift.Value('01099887766'),
          nationalId: const drift.Value('29501011234567'),
          basicSalary: const drift.Value(600000), // 6000.00 EGP
          salaryType: const drift.Value('شهري'),
          hireDate: drift.Value(now),
        ),
      );

      expect(id, isPositive);

      final list = await employeesRepo.getAllEmployees();
      expect(list.length, equals(1));
      expect(list.first.name, equals('محمود حسن'));
      expect(list.first.role, equals('فني ميكانيكا أول'));
      expect(list.first.basicSalaryPiasters, equals(600000));
      expect(list.first.isActive, isTrue);
    });

    test('toggleEmployeeActive updates isActive', () async {
      final now = DateTime.now();
      final id = await employeesRepo.insertEmployee(
        EmployeesCompanion(
          name: const drift.Value('طارق السيد'),
          role: const drift.Value('مساعد كهربائي'),
          basicSalary: const drift.Value(350000),
          hireDate: drift.Value(now),
        ),
      );

      await employeesRepo.toggleEmployeeActive(id);
      var emp = await employeesRepo.getEmployeeById(id);
      expect(emp!.isActive, isFalse);

      await employeesRepo.toggleEmployeeActive(id);
      emp = await employeesRepo.getEmployeeById(id);
      expect(emp!.isActive, isTrue);
    });

    test('createAdvance and watchAdvances tracks employee cash withdrawals', () async {
      final now = DateTime.now();
      final empId = await employeesRepo.insertEmployee(
        EmployeesCompanion(
          name: const drift.Value('سامي كمال'),
          role: const drift.Value('فني سمكرة'),
          basicSalary: const drift.Value(500000),
          hireDate: drift.Value(now),
        ),
      );

      final advId = await employeesRepo.createAdvance(
        employeeId: empId,
        amount: 100000, // 1000.00 EGP
        paymentMethod: PaymentMethod.cash,
        notes: 'سلفة مصاريف علاجية',
        date: now,
      );

      expect(advId, isPositive);

      final advances = await employeesRepo.watchAdvances().first;
      expect(advances.length, equals(1));
      expect(advances.first.amountPiasters, equals(100000));
      expect(advances.first.isDeducted, isFalse);
      expect(advances.first.employee.name, equals('سامي كمال'));

      final summary = await employeesRepo.getSummary();
      expect(summary.pendingAdvancesPiasters, equals(100000));
    });

    test('paySalary creates payout and auto-deducts pending advances in a transaction', () async {
      final now = DateTime.now();
      final empId = await employeesRepo.insertEmployee(
        EmployeesCompanion(
          name: const drift.Value('كريم نبيل'),
          role: const drift.Value('مهندس استقبال'),
          basicSalary: const drift.Value(700000), // 7000.00 EGP
          hireDate: drift.Value(now),
        ),
      );

      // Record 2 advances: 500 EGP and 300 EGP
      final adv1 = await employeesRepo.createAdvance(
        employeeId: empId,
        amount: 50000, // 500 EGP
        paymentMethod: PaymentMethod.cash,
        date: now,
      );
      final adv2 = await employeesRepo.createAdvance(
        employeeId: empId,
        amount: 30000, // 300 EGP
        paymentMethod: PaymentMethod.cash,
        date: now,
      );

      // Verify pending advances is 800 EGP in summary
      var summary = await employeesRepo.getSummary();
      expect(summary.pendingAdvancesPiasters, equals(80000));

      // Pay salary for this month:
      // Basic: 7000 EGP
      // Advances deducted: 800 EGP
      // Bonus: 500 EGP
      // Penalty: 100 EGP
      // Net paid: 7000 - 800 + 500 - 100 = 6600 EGP (660,000 piasters)
      final payId = await employeesRepo.paySalary(
        employeeId: empId,
        year: now.year,
        month: now.month,
        basicSalary: 700000,
        advancesDeducted: 80000,
        bonusAmount: 50000,
        penaltyAmount: 10000,
        netPaid: 660000,
        paymentMethod: PaymentMethod.transfer,
        paymentDate: now,
        notes: 'صرف راتب الشهر مع مكافأة إنجاز',
        advanceIdsToDeduct: [adv1, adv2],
      );

      expect(payId, isPositive);

      // Check salary record
      final salaries = await employeesRepo.watchSalaryPayments().first;
      expect(salaries.length, equals(1));
      expect(salaries.first.netPaidPiasters, equals(660000));
      expect(salaries.first.advancesDeductedPiasters, equals(80000));
      expect(salaries.first.bonusPiasters, equals(50000));
      expect(salaries.first.penaltyPiasters, equals(10000));

      // Verify advances are now marked isDeducted = true
      final advances = await employeesRepo.watchAdvances(employeeId: empId).first;
      expect(advances.every((a) => a.isDeducted), isTrue);

      // Verify pending advances in summary is now 0
      summary = await employeesRepo.getSummary();
      expect(summary.pendingAdvancesPiasters, equals(0));
      expect(summary.currentMonthPaidSalariesPiasters, equals(660000));

      // Check Employee stats
      final empWithStats = (await employeesRepo.getAllEmployees()).first;
      expect(empWithStats.totalSalariesPaidPiasters, equals(660000));
      expect(empWithStats.pendingAdvancesPiasters, equals(0));
    });

    test('deleteSalaryPayment reverses advance deduction status and removes payment', () async {
      final now = DateTime.now();
      final empId = await employeesRepo.insertEmployee(
        EmployeesCompanion(
          name: const drift.Value('علي مصطفى'),
          role: const drift.Value('فني كهرباء'),
          basicSalary: const drift.Value(450000),
          hireDate: drift.Value(now),
        ),
      );

      final advId = await employeesRepo.createAdvance(
        employeeId: empId,
        amount: 50000,
        paymentMethod: PaymentMethod.cash,
        date: now,
      );

      final payId = await employeesRepo.paySalary(
        employeeId: empId,
        year: now.year,
        month: now.month,
        basicSalary: 450000,
        advancesDeducted: 50000,
        bonusAmount: 0,
        penaltyAmount: 0,
        netPaid: 400000,
        paymentMethod: PaymentMethod.cash,
        paymentDate: now,
        advanceIdsToDeduct: [advId],
      );

      expect((await employeesRepo.watchSalaryPayments().first).length, equals(1));
      expect((await employeesRepo.watchAdvances().first).first.isDeducted, isTrue);

      // Delete the salary payout
      await employeesRepo.deleteSalaryPayment(payId);

      // Salary payment removed
      expect((await employeesRepo.watchSalaryPayments().first).isEmpty, isTrue);

      // Advance restored to isDeducted = false
      expect((await employeesRepo.watchAdvances().first).first.isDeducted, isFalse);
      final summary = await employeesRepo.getSummary();
      expect(summary.pendingAdvancesPiasters, equals(50000));
    });

    test('Salary payments feed into SalesReportData operating salaries', () async {
      final now = DateTime.now();
      final empId = await employeesRepo.insertEmployee(
        EmployeesCompanion(
          name: const drift.Value('جمال عبد الله'),
          role: const drift.Value('مدير صيانة'),
          basicSalary: const drift.Value(900000),
          hireDate: drift.Value(now),
        ),
      );

      await employeesRepo.paySalary(
        employeeId: empId,
        year: now.year,
        month: now.month,
        basicSalary: 900000,
        advancesDeducted: 0,
        bonusAmount: 0,
        penaltyAmount: 0,
        netPaid: 900000,
        paymentMethod: PaymentMethod.transfer,
        paymentDate: now,
      );

      final range = ReportDateRange.today();
      final report = await reportsRepo.getSalesReport(range.start, range.end);
      expect(report.salariesPaidPiasters, equals(900000));
      expect(report.totalExpensesAndSalariesPiasters, equals(900000));
      expect(report.netOperatingProfitPiasters, equals(-900000));
    });
  });

  group('EmployeesPage Widget Tests', () {
    Widget buildEmployeesApp() {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          employeesRepositoryProvider.overrideWithValue(employeesRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: EmployeesPage(),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders all 3 tabs, KPI summary cards, and switches tabs cleanly', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildEmployeesApp());
      await tester.pumpAndSettle();

      // Title & CTA
      expect(find.text(AppStrings.employeesTitle), findsOneWidget);
      expect(find.text(AppStrings.addEmployee), findsOneWidget);

      // KPI summary cards
      expect(find.text('طاقم العمل النشط'), findsOneWidget);
      expect(find.text('إجمالي الرواتب الأساسية'), findsOneWidget);
      expect(find.text('سلفيات معلقة للخصم'), findsOneWidget);
      expect(find.text('رواتب مصروفة هذا الشهر'), findsOneWidget);

      // Tabs
      expect(find.text(AppStrings.tabEmployeesList), findsOneWidget);
      expect(find.text(AppStrings.tabAdvances), findsOneWidget);
      expect(find.text(AppStrings.tabSalaries), findsOneWidget);

      // Tab 1 empty state
      expect(find.text('لا يوجد موظفون مسجلون مطابقون للبحث.'), findsOneWidget);

      // Switch to Tab 2: Advances
      await tester.tap(find.text(AppStrings.tabAdvances));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.recordAdvance), findsOneWidget);
      expect(find.text('لا توجد سلفيات أو مسحوبات مسجلة.'), findsOneWidget);

      // Switch to Tab 3: Salaries
      await tester.tap(find.text(AppStrings.tabSalaries));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.paySalary), findsOneWidget);
      expect(find.text('لا توجد رواتب مسجلة حتى الآن.'), findsOneWidget);
    });

    testWidgets('Opens Add Employee Dialog and creates new employee', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildEmployeesApp());
      await tester.pumpAndSettle();

      // Tap Add Employee button
      await tester.tap(find.text(AppStrings.addEmployee));
      await tester.pumpAndSettle();

      // Verify dialog
      expect(find.byType(EmployeeFormDialog), findsOneWidget);

      // Enter name
      final nameField = find.widgetWithText(TextFormField, 'اسم الموظف *');
      await tester.enterText(nameField, 'إبراهيم حسن');

      // Enter basic salary
      final salaryField = find.widgetWithText(TextFormField, 'الراتب الأساسي (ج.م) *');
      await tester.enterText(salaryField, '5500');

      // Save
      await tester.tap(find.text('حفظ بيانات الموظف'));
      await tester.pumpAndSettle();

      // Verify employee shows up in table
      expect(find.text('إبراهيم حسن'), findsOneWidget);
      expect(find.textContaining('5,500'), findsAtLeastNWidgets(1));
    });

    testWidgets('Renders properly without overflow on 1100x700 viewport', (tester) async {
      tester.view.physicalSize = const Size(1100, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildEmployeesApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
