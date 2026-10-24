import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/providers.dart';
import 'package:garage_erp/core/db/repositories/customers_repository.dart';
import 'package:garage_erp/core/db/repositories/vehicles_repository.dart';
import 'package:garage_erp/core/errors/app_exceptions.dart';
import 'package:garage_erp/core/strings.dart';
import 'package:garage_erp/core/theme/app_theme.dart';
import 'package:garage_erp/features/customers/customers_page.dart';
import 'package:garage_erp/features/customers/presentation/widgets/customer_form_dialog.dart';
import 'package:garage_erp/features/customers/presentation/widgets/transfer_vehicle_dialog.dart';
import 'package:garage_erp/features/customers/presentation/widgets/vehicle_form_dialog.dart';

void main() {
  late AppDatabase db;
  late CustomersRepository customersRepo;
  late VehiclesRepository vehiclesRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    customersRepo = DriftCustomersRepository(db);
    vehiclesRepo = DriftVehiclesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CustomersRepository Unit Tests', () {
    test('insert and fetch customer by id', () async {
      final id = await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('أحمد محمد علي'),
          phone: drift.Value('01012345678'),
          notes: drift.Value('عميل مميز'),
        ),
      );

      final customer = await customersRepo.getById(id);
      expect(customer.id, id);
      expect(customer.name, 'أحمد محمد علي');
      expect(customer.phone, '01012345678');
      expect(customer.notes, 'عميل مميز');
      expect(customer.isActive, isTrue);
    });

    test('phone numbers are normalized to western digits on insert', () async {
      final id = await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('عمرو خالد'),
          phone: drift.Value('٠١١٢٣٤٥٦٧٨٩'),
        ),
      );

      final customer = await customersRepo.getById(id);
      expect(customer.phone, '01123456789');
    });

    test('inserting duplicate phone throws ValidationException', () async {
      await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('عميل أول'),
          phone: drift.Value('01099998888'),
        ),
      );

      expect(
        () => customersRepo.insertCustomer(
          const CustomersCompanion(
            name: drift.Value('عميل ثانٍ'),
            phone: drift.Value('01099998888'),
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('empty name throws ValidationException', () async {
      expect(
        () => customersRepo.insertCustomer(
          const CustomersCompanion(
            name: drift.Value('   '),
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('updating customer with another customer phone throws ValidationException', () async {
      final id1 = await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('عميل 1'),
          phone: drift.Value('01011111111'),
        ),
      );
      final id2 = await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('عميل 2'),
          phone: drift.Value('01022222222'),
        ),
      );

      final c2 = await customersRepo.getById(id2);
      expect(
        () => customersRepo.updateCustomer(c2.copyWith(phone: const drift.Value('01011111111'))),
        throwsA(isA<ValidationException>()),
      );

      // Updating same customer keeping same phone succeeds
      final c1 = await customersRepo.getById(id1);
      final updated = await customersRepo.updateCustomer(c1.copyWith(name: 'عميل 1 المعدل'));
      expect(updated, isTrue);
    });

    test('smart search matches by name, phone (western and arabic digits), and vehicle plate', () async {
      final cust1 = await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('محمود إبراهيم الشناوي'),
          phone: drift.Value('01012345678'),
        ),
      );
      final cust2 = await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('يوسف عبد الله'),
          phone: drift.Value('01298765432'),
        ),
      );

      // Register vehicle for cust2
      await vehiclesRepo.insertVehicle(
        VehiclesCompanion(
          customerId: drift.Value(cust2),
          plateNumber: const drift.Value('س ص ع 9876'),
          make: const drift.Value('تويوتا'),
        ),
      );

      // 1. Search by partial name
      final byName = await customersRepo.search('الشناوي');
      expect(byName.length, 1);
      expect(byName.first.id, cust1);

      // 2. Search by phone using Arabic-Indic digits
      final byPhoneArabic = await customersRepo.search('٠١٠١٢٣');
      expect(byPhoneArabic.length, 1);
      expect(byPhoneArabic.first.id, cust1);

      // 3. Search by vehicle plate number returns the owning customer
      final byPlate = await customersRepo.search('س ص ع');
      expect(byPlate.length, 1);
      expect(byPlate.first.id, cust2);
    });

    test('customer balance accounts for issued invoices and payments and excludes cancelled', () async {
      final custId = await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('ماجد كمال'),
        ),
      );

      // Issued Invoice 1: 500 EGP (50,000 piasters), paid 200 EGP (20,000 piasters)
      await db.into(db.invoices).insert(
        InvoicesCompanion(
          invoiceNumber: const drift.Value(1001),
          customerId: drift.Value(custId),
          subtotal: const drift.Value(50000),
          totalAmount: const drift.Value(50000),
          paidAmount: const drift.Value(20000),
          status: const drift.Value(InvoiceStatus.issued),
        ),
      );

      // Issued Invoice 2: 300 EGP (30,000 piasters), paid 300 EGP (30,000 piasters)
      await db.into(db.invoices).insert(
        InvoicesCompanion(
          invoiceNumber: const drift.Value(1002),
          customerId: drift.Value(custId),
          subtotal: const drift.Value(30000),
          totalAmount: const drift.Value(30000),
          paidAmount: const drift.Value(30000),
          status: const drift.Value(InvoiceStatus.issued),
        ),
      );

      // Cancelled Invoice: 1000 EGP, must be excluded from summary balance
      await db.into(db.invoices).insert(
        InvoicesCompanion(
          invoiceNumber: const drift.Value(1003),
          customerId: drift.Value(custId),
          subtotal: const drift.Value(100000),
          totalAmount: const drift.Value(100000),
          paidAmount: const drift.Value(0),
          status: const drift.Value(InvoiceStatus.cancelled),
        ),
      );

      final summary = await customersRepo.getCustomerSummary(custId);
      expect(summary.totalInvoiced, 80000); // 50000 + 30000
      expect(summary.totalPaid, 50000); // 20000 + 30000
      expect(summary.balance, 30000); // 80000 - 50000 = 300 EGP debt
      expect(summary.hasDebt, isTrue);
      expect(summary.invoicesCount, 2);
    });

    test('Rule R10: deleting customer with active work order or invoice throws BusinessRuleException', () async {
      final custId = await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('خالد حسام'),
        ),
      );

      final vehicleId = await vehiclesRepo.insertVehicle(
        VehiclesCompanion(
          customerId: drift.Value(custId),
          plateNumber: const drift.Value('ق ر ش 1122'),
        ),
      );

      // Add work order for this customer
      await db.into(db.workOrders).insert(
        WorkOrdersCompanion(
          orderNumber: const drift.Value(5001),
          customerId: drift.Value(custId),
          vehicleId: drift.Value(vehicleId),
          status: const drift.Value(WorkOrderStatus.open),
        ),
      );

      expect(
        () => customersRepo.deleteCustomer(custId),
        throwsA(isA<BusinessRuleException>()),
      );
    });
  });

  group('VehiclesRepository Unit Tests', () {
    test('Rule R13: plate number is normalized upon insertion', () async {
      final custId = await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('طارق سعيد'),
        ),
      );

      final vehicleId = await vehiclesRepo.insertVehicle(
        VehiclesCompanion(
          customerId: drift.Value(custId),
          plateNumber: const drift.Value('  أ   ب   ج   ١٢٣٤  '),
          make: const drift.Value('هيونداي'),
          model: const drift.Value('النترا'),
          year: const drift.Value(2021),
        ),
      );

      final vehicle = await vehiclesRepo.getById(vehicleId);
      expect(vehicle.plateNumber, 'أ ب ج 1234');
    });

    test('cannot insert duplicate plate number even with different spacing', () async {
      final custId = await customersRepo.insertCustomer(
        const CustomersCompanion(name: drift.Value('عميل تجربة')),
      );

      await vehiclesRepo.insertVehicle(
        VehiclesCompanion(
          customerId: drift.Value(custId),
          plateNumber: const drift.Value('د هـ و 5555'),
        ),
      );

      expect(
        () => vehiclesRepo.insertVehicle(
          VehiclesCompanion(
            customerId: drift.Value(custId),
            plateNumber: const drift.Value('د  هـ  و  5555'),
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Rule R14: transfer ownership updates customerId and records audit log', () async {
      final cust1 = await customersRepo.insertCustomer(
        const CustomersCompanion(name: drift.Value('المالك الأول - شريف')),
      );
      final cust2 = await customersRepo.insertCustomer(
        const CustomersCompanion(name: drift.Value('المالك الجديد - وائل')),
      );

      final vehicleId = await vehiclesRepo.insertVehicle(
        VehiclesCompanion(
          customerId: drift.Value(cust1),
          plateNumber: const drift.Value('ط ي ك 7890'),
          make: const drift.Value('كيا'),
          model: const drift.Value('سيراتو'),
        ),
      );

      // Perform ownership transfer
      await vehiclesRepo.transferOwnership(
        vehicleId,
        cust2,
        notes: 'تم البيع بعقد مسجل',
      );

      final updatedVehicle = await vehiclesRepo.getById(vehicleId);
      expect(updatedVehicle.customerId, cust2);

      // Audit history in appSettings
      final history = await vehiclesRepo.getOwnershipHistory(vehicleId);
      expect(history.length, 1);
      expect(history.first, contains('ط ي ك 7890'));
      expect(history.first, contains('المالك الأول - شريف'));
      expect(history.first, contains('المالك الجديد - وائل'));
      expect(history.first, contains('تم البيع بعقد مسجل'));
    });

    test('Rule R10: deleting vehicle with work orders throws BusinessRuleException', () async {
      final custId = await customersRepo.insertCustomer(
        const CustomersCompanion(name: drift.Value('حسام الدين')),
      );

      final vehicleId = await vehiclesRepo.insertVehicle(
        VehiclesCompanion(
          customerId: drift.Value(custId),
          plateNumber: const drift.Value('ف ق ك 4321'),
        ),
      );

      await db.into(db.workOrders).insert(
        WorkOrdersCompanion(
          orderNumber: const drift.Value(6001),
          customerId: drift.Value(custId),
          vehicleId: drift.Value(vehicleId),
          status: const drift.Value(WorkOrderStatus.ready),
        ),
      );

      expect(
        () => vehiclesRepo.deleteVehicle(vehicleId),
        throwsA(isA<BusinessRuleException>()),
      );
    });
  });

  group('Customers UI Widget Tests', () {
    Widget buildTestHarness({required Widget child}) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          customersRepositoryProvider.overrideWithValue(customersRepo),
          vehiclesRepositoryProvider.overrideWithValue(vehiclesRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: child,
        ),
      );
    }

    testWidgets('CustomersPage renders table and master-detail layout', (tester) async {
      // Seed a customer with a vehicle
      final custId = await customersRepo.insertCustomer(
        const CustomersCompanion(
          name: drift.Value('عمرو السعدني'),
          phone: drift.Value('01001122334'),
        ),
      );

      await vehiclesRepo.insertVehicle(
        VehiclesCompanion(
          customerId: drift.Value(custId),
          plateNumber: const drift.Value('أ ب ج 7777'),
          make: const drift.Value('تويوتا'),
          model: const drift.Value('ياريس'),
        ),
      );

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestHarness(child: const CustomersPage()));
      await tester.pumpAndSettle();

      // Check header and customer row
      expect(find.text(AppStrings.customersTitle), findsOneWidget);
      expect(find.text('عمرو السعدني'), findsAtLeastNWidgets(1));
      expect(find.text('01001122334'), findsAtLeastNWidgets(1));
      expect(find.text(AppStrings.newCustomerButton), findsOneWidget);

      // Check detail pane rendered on right
      expect(find.text('السيارات المسجلة (1)'), findsOneWidget);
      expect(find.text('أ ب ج 7777'), findsOneWidget);
      expect(find.text(AppStrings.addVehicleButton), findsOneWidget);
    });

    testWidgets('CustomerFormDialog validates required name and creates customer', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CustomerFormDialog.show(context),
              child: const Text('افتح'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.newCustomerButton), findsOneWidget);

      // Try saving without entering name
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.fieldRequired), findsOneWidget);

      // Fill in name and phone
      await tester.enterText(find.byType(TextFormField).at(0), 'كريم عادل');
      await tester.enterText(find.byType(TextFormField).at(1), '01234567890');
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      // Verify customer created in DB
      final customers = await customersRepo.getAll();
      expect(customers.any((c) => c.name == 'كريم عادل'), isTrue);
    });

    testWidgets('VehicleFormDialog normalizes plate and creates vehicle', (tester) async {
      final custId = await customersRepo.insertCustomer(
        const CustomersCompanion(name: drift.Value('سمير غانم')),
      );

      await tester.pumpWidget(
        buildTestHarness(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => VehicleFormDialog.show(context, customerId: custId),
              child: const Text('إضافة سيارة'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('إضافة سيارة'));
      await tester.pumpAndSettle();

      // Enter plate with extra spacing and verify normalization preview
      await tester.enterText(find.byType(TextFormField).at(0), '  ر   س   ت   ٩٩٩٩  ');
      await tester.pumpAndSettle();

      expect(find.text('الصيغة المقننة للوحة: '), findsOneWidget);
      expect(find.text('ر س ت 9999'), findsOneWidget);

      // Fill in make and model
      await tester.enterText(find.byType(TextFormField).at(1), 'ميتسوبيشي');
      await tester.enterText(find.byType(TextFormField).at(2), 'لانسر');

      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      final vehicles = await vehiclesRepo.getByCustomerId(custId);
      expect(vehicles.length, 1);
      expect(vehicles.first.plateNumber, 'ر س ت 9999');
      expect(vehicles.first.make, 'ميتسوبيشي');
    });

    testWidgets('TransferVehicleDialog transfers vehicle to chosen customer', (tester) async {
      final cust1 = await customersRepo.insertCustomer(
        const CustomersCompanion(name: drift.Value('علي حسن')),
      );
      final cust2 = await customersRepo.insertCustomer(
        const CustomersCompanion(name: drift.Value('إسلام صابر')),
      );

      final vehicleId = await vehiclesRepo.insertVehicle(
        VehiclesCompanion(
          customerId: drift.Value(cust1),
          plateNumber: const drift.Value('ط ع غ 1212'),
          make: const drift.Value('نيسان'),
          model: const drift.Value('صني'),
        ),
      );

      final vehicle = await vehiclesRepo.getById(vehicleId);
      final owner1 = await customersRepo.getById(cust1);

      await tester.pumpWidget(
        buildTestHarness(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => TransferVehicleDialog.show(
                context,
                vehicle: vehicle,
                currentOwner: owner1,
              ),
              child: const Text('نقل'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('نقل'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.transferTitle), findsOneWidget);
      expect(find.text('ط ع غ 1212'), findsOneWidget);

      // Select new customer
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('إسلام صابر').last);
      await tester.pumpAndSettle();

      // Submit transfer
      await tester.tap(find.text(AppStrings.transferVehicleButton));
      await tester.pumpAndSettle();

      final updated = await vehiclesRepo.getById(vehicleId);
      expect(updated.customerId, cust2);
    });
  });
}
