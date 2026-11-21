import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/providers.dart';
import 'package:garage_erp/core/db/repositories/expenses_repository.dart';
import 'package:garage_erp/core/db/repositories/reports_repository.dart';
import 'package:garage_erp/core/db/services/stock_service.dart';
import 'package:garage_erp/core/strings.dart';
import 'package:garage_erp/core/theme/app_theme.dart';
import 'package:garage_erp/features/expenses/expenses_page.dart';
import 'package:garage_erp/features/expenses/presentation/widgets/expense_form_dialog.dart';
import 'package:garage_erp/features/reports/domain/report_date_range.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ExpensesRepository expensesRepo;
  late ReportsRepository reportsRepo;
  late StockService stockService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    expensesRepo = DriftExpensesRepository(db);
    stockService = StockService(db);
    reportsRepo = DriftReportsRepository(db, stockService);
  });

  tearDown(() async {
    await db.close();
  });

  group('ExpensesRepository Tests', () {
    test('insertExpense and getExpenses retrieves recorded expenses', () async {
      final now = DateTime.now();
      final id = await expensesRepo.insertExpense(
        ExpensesCompanion(
          description: const drift.Value('فاتورة كهرباء الورشة'),
          category: const drift.Value('كهرباء ومياه'),
          amount: const drift.Value(150000), // 1500.00 EGP
          paymentMethod: const drift.Value(PaymentMethod.cash),
          expenseDate: drift.Value(now),
          notes: const drift.Value('شامل رسوم النظافة'),
        ),
      );

      expect(id, isPositive);

      final list = await expensesRepo.getExpenses();
      expect(list.length, equals(1));
      expect(list.first.description, equals('فاتورة كهرباء الورشة'));
      expect(list.first.amountPiasters, equals(150000));
      expect(list.first.category, equals('كهرباء ومياه'));
      expect(list.first.paymentMethod, equals(PaymentMethod.cash));
    });

    test('updateExpense modifies existing record', () async {
      final now = DateTime.now();
      final id = await expensesRepo.insertExpense(
        ExpensesCompanion(
          description: const drift.Value('شاي وسكر'),
          category: const drift.Value('بوفيه وضيافة'),
          amount: const drift.Value(20000), // 200.00 EGP
          paymentMethod: const drift.Value(PaymentMethod.cash),
          expenseDate: drift.Value(now),
        ),
      );

      final success = await expensesRepo.updateExpense(
        id,
        const ExpensesCompanion(
          description: drift.Value('شاي وسكر وبن'),
          amount: drift.Value(25000),
        ),
      );
      expect(success, isTrue);

      final updated = await expensesRepo.getExpenseById(id);
      expect(updated!.description, equals('شاي وسكر وبن'));
      expect(updated.amountPiasters, equals(25000));
    });

    test('deleteExpense removes expense', () async {
      final now = DateTime.now();
      final id = await expensesRepo.insertExpense(
        ExpensesCompanion(
          description: const drift.Value('أدوات نظافة'),
          category: const drift.Value('نظافة ومستلزمات'),
          amount: const drift.Value(10000),
          paymentMethod: const drift.Value(PaymentMethod.cash),
          expenseDate: drift.Value(now),
        ),
      );

      var list = await expensesRepo.getExpenses();
      expect(list.length, equals(1));

      final deleted = await expensesRepo.deleteExpense(id);
      expect(deleted, isTrue);

      list = await expensesRepo.getExpenses();
      expect(list.isEmpty, isTrue);
    });

    test('getSummary calculates today, this month, and total amounts', () async {
      final now = DateTime.now();
      // Expense today
      await expensesRepo.insertExpense(
        ExpensesCompanion(
          description: const drift.Value('بوفيه اليوم'),
          category: const drift.Value('بوفيه وضيافة'),
          amount: const drift.Value(5000), // 50.00 EGP
          paymentMethod: const drift.Value(PaymentMethod.cash),
          expenseDate: drift.Value(now),
        ),
      );

      // Expense earlier this month (day 1)
      final firstDayThisMonth = DateTime(now.year, now.month, 1, 10, 0);
      await expensesRepo.insertExpense(
        ExpensesCompanion(
          description: const drift.Value('إيجار المحل'),
          category: const drift.Value('إيجار'),
          amount: const drift.Value(500000), // 5000.00 EGP
          paymentMethod: const drift.Value(PaymentMethod.transfer),
          expenseDate: drift.Value(firstDayThisMonth),
        ),
      );

      final summary = await expensesRepo.getSummary();
      expect(summary.count, equals(2));
      expect(summary.totalPiasters, equals(505000));
      expect(summary.thisMonthPiasters, equals(505000));
      expect(summary.todayPiasters, equals(5000));
      expect(summary.categoryBreakdown['إيجار'], equals(500000));
      expect(summary.categoryBreakdown['بوفيه وضيافة'], equals(5000));
    });

    test('Expenses feed into SalesReportData operating expenses', () async {
      final now = DateTime.now();
      await expensesRepo.insertExpense(
        ExpensesCompanion(
          description: const drift.Value('صيانة كمبروسر'),
          category: const drift.Value('عدد وأدوات ورشة'),
          amount: const drift.Value(75000), // 750.00 EGP
          paymentMethod: const drift.Value(PaymentMethod.cash),
          expenseDate: drift.Value(now),
        ),
      );

      final range = ReportDateRange.today();
      final report = await reportsRepo.getSalesReport(range.start, range.end);
      expect(report.operatingExpensesPiasters, equals(75000));
      expect(report.totalExpensesAndSalariesPiasters, equals(75000));
    });
  });

  group('ExpensesPage Widget Tests', () {
    Widget buildExpensesApp() {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          expensesRepositoryProvider.overrideWithValue(expensesRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: ExpensesPage(),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders header, KPI cards, filter chips, and empty state', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildExpensesApp());
      await tester.pumpAndSettle();

      // Title & CTA
      expect(find.text(AppStrings.expensesTitle), findsOneWidget);
      expect(find.text(AppStrings.addExpense), findsOneWidget);

      // KPI summary cards
      expect(find.text('مصروفات اليوم'), findsOneWidget);
      expect(find.text('مصروفات هذا الشهر'), findsOneWidget);
      expect(find.text('إجمالي المصروفات'), findsOneWidget);

      // Category filter dropdown
      expect(find.text('الكل'), findsOneWidget);

      // Empty state
      expect(find.text('لا توجد مصروفات مسجلة مطابقة للبحث أو الفلتر.'), findsOneWidget);
    });

    testWidgets('Opens Add Expense Dialog and saves record', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildExpensesApp());
      await tester.pumpAndSettle();

      // Tap Add Expense button
      await tester.tap(find.text(AppStrings.addExpense));
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.byType(ExpenseFormDialog), findsOneWidget);

      // Enter description
      final descField = find.widgetWithText(TextFormField, 'بيان وتفاصيل المصروف *');
      await tester.enterText(descField, 'فاتورة إنترنت');

      // Enter amount (MoneyField)
      final amountField = find.widgetWithText(TextFormField, 'مبلغ المصروف (ج.م) *');
      await tester.enterText(amountField, '350');

      // Save
      await tester.tap(find.text('حفظ المصروف'));
      await tester.pumpAndSettle();

      // Verify record appears in data table
      expect(find.text('فاتورة إنترنت'), findsOneWidget);
      expect(find.textContaining('350'), findsAtLeastNWidgets(1));
    });
  });
}
