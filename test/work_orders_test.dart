import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/providers.dart';
import 'package:garage_erp/core/db/repositories/customers_repository.dart';
import 'package:garage_erp/core/db/repositories/employees_repository.dart';
import 'package:garage_erp/core/db/repositories/items_repository.dart';
import 'package:garage_erp/core/db/repositories/services_repository.dart';
import 'package:garage_erp/core/db/repositories/vehicles_repository.dart';
import 'package:garage_erp/core/db/repositories/work_orders_repository.dart';
import 'package:garage_erp/core/db/services/stock_service.dart';
import 'package:garage_erp/core/errors/app_exceptions.dart';
import 'package:garage_erp/core/strings.dart';
import 'package:garage_erp/core/theme/app_theme.dart';
import 'package:garage_erp/features/work_orders/domain/work_order_line_item.dart';
import 'package:garage_erp/features/work_orders/presentation/printing/job_card_builder.dart';
import 'package:garage_erp/features/work_orders/presentation/widgets/change_status_dialog.dart';
import 'package:garage_erp/features/work_orders/presentation/widgets/deliver_work_order_dialog.dart';
import 'package:garage_erp/features/work_orders/presentation/widgets/work_order_details_pane.dart';
import 'package:garage_erp/features/work_orders/presentation/widgets/work_order_form_dialog.dart';
import 'package:garage_erp/features/work_orders/work_orders_page.dart';

void main() {
  late AppDatabase db;
  late CustomersRepository customersRepo;
  late VehiclesRepository vehiclesRepo;
  late ServicesRepository servicesRepo;
  late ItemsRepository itemsRepo;
  late WorkOrdersRepository workOrdersRepo;
  late EmployeesRepository employeesRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    customersRepo = DriftCustomersRepository(db);
    vehiclesRepo = DriftVehiclesRepository(db);
    servicesRepo = DriftServicesRepository(db);
    itemsRepo = DriftItemsRepository(db);
    workOrdersRepo = DriftWorkOrdersRepository(db);
    employeesRepo = DriftEmployeesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<(int, int)> setupCustomerAndVehicle({
    String name = 'محمد أحمد',
    String phone = '01012345678',
    String plate = 'س ص ع 1234',
    int? initialOdometer = 50000,
  }) async {
    final custId = await customersRepo.insertCustomer(
      CustomersCompanion(
        name: drift.Value(name),
        phone: drift.Value(phone),
      ),
    );

    final vehId = await vehiclesRepo.insertVehicle(
      VehiclesCompanion(
        customerId: drift.Value(custId),
        plateNumber: drift.Value(plate),
        make: const drift.Value('تويوتا'),
        model: const drift.Value('كورولا'),
        year: const drift.Value(2020),
        lastOdometer: drift.Value(initialOdometer),
      ),
    );

    return (custId, vehId);
  }

  group('WorkOrdersRepository Unit Tests', () {
    test('create work order assigns sequential number starting from 1 (Rule R6)', () async {
      final (custId, vehId) = await setupCustomerAndVehicle();

      final order1 = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'تغيير زيت وفلتر',
      );

      expect(order1.orderNumber, equals(1));
      expect(order1.status, equals(WorkOrderStatus.open));
      expect(order1.customer.name, equals('محمد أحمد'));
      expect(order1.vehicle.make, equals('تويوتا'));

      final order2 = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'صوت في الفرامل',
      );

      expect(order2.orderNumber, equals(2));
    });

    test('create work order with services and parts computes accurate line and grand totals', () async {
      final (custId, vehId) = await setupCustomerAndVehicle();

      final serviceId = await servicesRepo.insertService(
        const ServicesCompanion(
          name: drift.Value('صيانة فرامل أمامية'),
          defaultPrice: drift.Value(15000), // 150.00 EGP
        ),
      );

      final catId = await db.into(db.itemCategories).insert(
        const ItemCategoriesCompanion(name: drift.Value('فرامل')),
      );

      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          categoryId: drift.Value(catId),
          name: const drift.Value('تيل فرامل أمامي كوري'),
          unit: const drift.Value('طقم'),
          costPrice: const drift.Value(30000), // 300.00 EGP
          salePrice: const drift.Value(45000), // 450.00 EGP
        ),
      );

      final order = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'تغيير تيل الفرامل الأمامي',
        mechanicName: 'الأسطى حسن',
        lines: [
          WorkOrderLineItem(
            lineType: LineType.service,
            serviceId: serviceId,
            description: 'مصنعية تغيير تيل فرامل',
            quantity: 1.0,
            unitPrice: 15000,
            totalPrice: 15000,
          ),
          WorkOrderLineItem(
            lineType: LineType.part,
            itemId: itemId,
            description: 'تيل فرامل أمامي كوري',
            quantity: 2.0,
            unitPrice: 45000,
            totalPrice: 90000,
          ),
        ],
      );

      expect(order.lines.length, equals(2));
      expect(order.servicesTotalPiasters, equals(15000));
      expect(order.partsTotalPiasters, equals(90000));
      expect(order.totalPiasters, equals(105000)); // 1,050.00 EGP
      expect(order.formattedTotal, contains('1,050.00'));
    });

    test('odometer tracking: higher reading updates vehicle lastOdometer', () async {
      final (custId, vehId) = await setupCustomerAndVehicle(initialOdometer: 50000);

      await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        odometer: 54200,
        complaint: 'صيانة دورية 55 ألف',
      );

      final updatedVehicle = await vehiclesRepo.getById(vehId);
      expect(updatedVehicle.lastOdometer, equals(54200));

      // Lower reading does not overwrite higher historical reading
      await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        odometer: 52000,
        complaint: 'فحص إطارات',
      );

      final vehicleStillHigh = await vehiclesRepo.getById(vehId);
      expect(vehicleStillHigh.lastOdometer, equals(54200));
    });

    test('update work order modifies complaint, mechanic, notes, and replaces lines', () async {
      final (custId, vehId) = await setupCustomerAndVehicle();

      final order = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'شكوى مبدئية',
      );

      final updated = await workOrdersRepo.updateWorkOrder(
        id: order.id,
        odometer: 60000,
        complaint: 'شكوى محدثة بعد الفحص',
        mechanicName: 'المهندس كريم',
        notes: 'تم فحص الموتور والعفشة',
        lines: const [
          WorkOrderLineItem(
            lineType: LineType.service,
            description: 'فحص شامل بالكمبيوتر',
            quantity: 1.0,
            unitPrice: 20000,
            totalPrice: 20000,
          ),
        ],
      );

      expect(updated.workOrder.complaint, equals('شكوى محدثة بعد الفحص'));
      expect(updated.workOrder.mechanicName, equals('المهندس كريم'));
      expect(updated.lines.length, equals(1));
      expect(updated.totalPiasters, equals(20000));
    });

    test('create and update work order persists entryDate and expectedExitDate', () async {
      final (custId, vehId) = await setupCustomerAndVehicle();
      final entry = DateTime(2026, 10, 27, 10, 30);
      final exit = DateTime(2026, 10, 28, 18, 0);

      final order = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        entryDate: entry,
        expectedExitDate: exit,
        complaint: 'صيانة كاملة',
      );

      expect(order.entryDate, equals(entry));
      expect(order.expectedExitDate, equals(exit));
      expect(order.formattedEntryDate, contains('2026/10/27'));
      expect(order.formattedExpectedExitDate, contains('2026/10/28'));

      final newExit = DateTime(2026, 10, 29, 12, 0);
      final updated = await workOrdersRepo.updateWorkOrder(
        id: order.id,
        expectedExitDate: newExit,
      );

      expect(updated.expectedExitDate, equals(newExit));
      expect(updated.formattedExpectedExitDate, contains('2026/10/29'));
    });

    test('status transitions: open -> inProgress -> ready -> delivered sets closedAt', () async {
      final (custId, vehId) = await setupCustomerAndVehicle();

      final order = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'صيانة عامة',
      );

      expect(order.status, equals(WorkOrderStatus.open));
      expect(order.workOrder.closedAt, isNull);

      await workOrdersRepo.updateStatus(id: order.id, status: WorkOrderStatus.inProgress);
      var current = await workOrdersRepo.getWorkOrderById(order.id);
      expect(current.status, equals(WorkOrderStatus.inProgress));

      await workOrdersRepo.updateStatus(id: order.id, status: WorkOrderStatus.ready);
      current = await workOrdersRepo.getWorkOrderById(order.id);
      expect(current.status, equals(WorkOrderStatus.ready));
      expect(current.workOrder.closedAt, isNotNull);

      await workOrdersRepo.updateStatus(id: order.id, status: WorkOrderStatus.delivered);
      current = await workOrdersRepo.getWorkOrderById(order.id);
      expect(current.status, equals(WorkOrderStatus.delivered));
    });

    test('cancelling order records reason; delivered order cannot be cancelled', () async {
      final (custId, vehId) = await setupCustomerAndVehicle();

      final order = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'فحص بطارية',
      );

      await workOrdersRepo.updateStatus(
        id: order.id,
        status: WorkOrderStatus.cancelled,
        cancellationReason: 'العميل قرر عدم الصيانة',
      );

      final cancelled = await workOrdersRepo.getWorkOrderById(order.id);
      expect(cancelled.status, equals(WorkOrderStatus.cancelled));
      expect(cancelled.workOrder.cancellationReason, equals('العميل قرر عدم الصيانة'));

      // Modifying already cancelled order throws
      expect(
        () => workOrdersRepo.updateStatus(id: order.id, status: WorkOrderStatus.open),
        throwsA(isA<BusinessRuleException>()),
      );

      // Create a delivered order
      final deliveredOrder = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'تسليم سريع',
      );
      await workOrdersRepo.updateStatus(id: deliveredOrder.id, status: WorkOrderStatus.delivered);

      // Cancelling a delivered order is strictly blocked
      expect(
        () => workOrdersRepo.updateStatus(id: deliveredOrder.id, status: WorkOrderStatus.cancelled),
        throwsA(isA<BusinessRuleException>()),
      );
    });

    test('deleting work order: allowed when no invoice; blocked when invoice exists (Rule R10)', () async {
      final (custId, vehId) = await setupCustomerAndVehicle();

      final order = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'أمر تجريبي للحذف',
        lines: const [
          WorkOrderLineItem(
            lineType: LineType.service,
            description: 'خدمة فحص',
            quantity: 1,
            unitPrice: 5000,
            totalPrice: 5000,
          ),
        ],
      );

      // Deleting open order without invoice succeeds
      await workOrdersRepo.deleteWorkOrder(order.id);
      expect(() => workOrdersRepo.getWorkOrderById(order.id), throwsA(isA<NotFoundException>()));

      // Create another order linked to an invoice
      final orderWithInvoice = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'أمر مرتبط بفاتورة',
      );

      await db.into(db.invoices).insert(
        InvoicesCompanion(
          invoiceNumber: const drift.Value(1001),
          workOrderId: drift.Value(orderWithInvoice.id),
          customerId: drift.Value(custId),
          subtotal: const drift.Value(10000),
          totalAmount: const drift.Value(10000),
        ),
      );

      expect(
        () => workOrdersRepo.deleteWorkOrder(orderWithInvoice.id),
        throwsA(isA<BusinessRuleException>()),
      );
    });

    test('smart search matches customer name, phone, plate number, and order number', () async {
      final (cust1, veh1) = await setupCustomerAndVehicle(
        name: 'إبراهيم الجمل',
        phone: '01122334455',
        plate: 'ق ر ش 789',
      );

      final (cust2, veh2) = await setupCustomerAndVehicle(
        name: 'سامي رزق',
        phone: '01299887766',
        plate: 'د هـ و 456',
      );

      final order1 = await workOrdersRepo.createWorkOrder(
        customerId: cust1,
        vehicleId: veh1,
        complaint: 'صيانة إبراهيم',
      );

      await workOrdersRepo.createWorkOrder(
        customerId: cust2,
        vehicleId: veh2,
        complaint: 'صيانة سامي',
      );

      // Search by customer name
      final byName = await workOrdersRepo.getWorkOrders(query: 'الجمل');
      expect(byName.length, equals(1));
      expect(byName.first.customer.name, equals('إبراهيم الجمل'));

      // Search by phone
      final byPhone = await workOrdersRepo.getWorkOrders(query: '0129988');
      expect(byPhone.length, equals(1));
      expect(byPhone.first.customer.name, equals('سامي رزق'));

      // Search by plate number
      final byPlate = await workOrdersRepo.getWorkOrders(query: 'ق ر ش 789');
      expect(byPlate.length, equals(1));

      // Search by order number (with # prefix)
      final byOrderNum = await workOrdersRepo.getWorkOrders(query: '#${order1.orderNumber}');
      expect(byOrderNum.length, equals(1));
      expect(byOrderNum.first.id, equals(order1.id));
    });

    test('work order summary computes active counts and open estimated value', () async {
      final (custId, vehId) = await setupCustomerAndVehicle();

      await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'مفتوح',
        lines: const [
          WorkOrderLineItem(
            lineType: LineType.service,
            description: 'خدمة 1',
            quantity: 1,
            unitPrice: 10000,
            totalPrice: 10000,
          ),
        ],
      );

      final o2 = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'قيد الشغل',
        lines: const [
          WorkOrderLineItem(
            lineType: LineType.service,
            description: 'خدمة 2',
            quantity: 1,
            unitPrice: 25000,
            totalPrice: 25000,
          ),
        ],
      );
      await workOrdersRepo.updateStatus(id: o2.id, status: WorkOrderStatus.inProgress);

      final o3 = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'جاهز',
        lines: const [
          WorkOrderLineItem(
            lineType: LineType.service,
            description: 'خدمة 3',
            quantity: 1,
            unitPrice: 15000,
            totalPrice: 15000,
          ),
        ],
      );
      await workOrdersRepo.updateStatus(id: o3.id, status: WorkOrderStatus.ready);

      final summary = await workOrdersRepo.getWorkOrderSummary();
      expect(summary.openOrdersCount, equals(1));
      expect(summary.inProgressOrdersCount, equals(1));
      expect(summary.readyOrdersCount, equals(1));
      expect(summary.todayOrdersCount, equals(3));
      expect(summary.estimatedOpenValuePiasters, equals(50000)); // 10000 + 25000 + 15000 = 500.00 EGP
    });

    test('deliverWorkOrder issues sequential invoice, deducts parts from stock, and records payment with method and reference', () async {
      final (custId, vehId) = await setupCustomerAndVehicle();

      final catId = await db.into(db.itemCategories).insert(
        const ItemCategoriesCompanion(name: drift.Value('زيوت وفلاتر')),
      );

      final itemId = await itemsRepo.insertItem(
        ItemsCompanion(
          name: const drift.Value('فلتر زيت أصلي'),
          categoryId: drift.Value(catId),
          costPrice: const drift.Value(15000), // 150 EGP
          salePrice: const drift.Value(25000), // 250 EGP
        ),
      );

      await db.into(db.stockMovements).insert(
        StockMovementsCompanion(
          itemId: drift.Value(itemId),
          movementType: const drift.Value(StockMovementType.opening),
          qty: const drift.Value(10.0),
          unitCost: const drift.Value(15000),
        ),
      );

      final order = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'تغيير زيت وفلتر',
        lines: [
          const WorkOrderLineItem(
            lineType: LineType.service,
            description: 'مصنعية غيار زيت',
            quantity: 1,
            unitPrice: 10000, // 100 EGP
            totalPrice: 10000,
          ),
          WorkOrderLineItem(
            lineType: LineType.part,
            itemId: itemId,
            description: 'فلتر زيت أصلي',
            quantity: 2,
            unitPrice: 25000, // 250 EGP
            totalPrice: 50000, // 500 EGP
          ),
        ],
      );

      // Deliver with Vodafone Cash payment
      final delivered = await workOrdersRepo.deliverWorkOrder(
        id: order.id,
        paymentMethod: PaymentMethod.wallet,
        paidAmountPiasters: 60000, // 600.00 EGP
        paymentReference: '01012345678-TXN9988',
        deliveryNotes: 'تم التسليم وتجربة المحرك',
      );

      expect(delivered.status, equals(WorkOrderStatus.delivered));
      expect(delivered.workOrder.closedAt, isNotNull);
      expect(delivered.hasInvoice, isTrue);
      expect(delivered.invoice, isNotNull);
      expect(delivered.invoiceNumber, equals(1));
      expect(delivered.invoice!.totalAmount, equals(60000));
      expect(delivered.invoice!.paidAmount, equals(60000));

      // Stock was deducted from warehouse (10 - 2 = 8)
      final onHand = await db.stockOf(itemId);
      expect(onHand, equals(8.0));

      // Payment was recorded with PaymentMethod.wallet and reference
      expect(delivered.payments.length, equals(1));
      expect(delivered.primaryPaymentMethod, equals(PaymentMethod.wallet));
      expect(delivered.paymentReference, equals('01012345678-TXN9988'));
      expect(delivered.paymentMethodArabic, equals(AppStrings.paymentMethodWallet));
    });

    test('getLastWorkOrderForCustomer returns the most recent prior work order for customer', () async {
      final (custId, vehId) = await setupCustomerAndVehicle(
        name: 'عماد شلبي',
        phone: '01012345678',
        plate: 'س ر ج 555',
      );

      final initial = await workOrdersRepo.getLastWorkOrderForCustomer(custId);
      expect(initial, isNull);

      final o1 = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'صيانة أولى',
        odometer: 10000,
      );

      final afterFirst = await workOrdersRepo.getLastWorkOrderForCustomer(custId);
      expect(afterFirst, isNotNull);
      expect(afterFirst!.workOrder.id, equals(o1.id));
      expect(afterFirst.workOrder.complaint, equals('صيانة أولى'));

      final o2 = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'صيانة ثانية',
        odometer: 20000,
      );

      final afterSecond = await workOrdersRepo.getLastWorkOrderForCustomer(custId);
      expect(afterSecond!.workOrder.id, equals(o2.id));
      expect(afterSecond.workOrder.complaint, equals('صيانة ثانية'));

      final excludeO2 = await workOrdersRepo.getLastWorkOrderForCustomer(custId, excludeWorkOrderId: o2.id);
      expect(excludeO2!.workOrder.id, equals(o1.id));
    });
  });

  group('Work Orders UI Widget Tests', () {
    Widget buildTestApp({Widget? child}) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          customersRepositoryProvider.overrideWithValue(customersRepo),
          vehiclesRepositoryProvider.overrideWithValue(vehiclesRepo),
          servicesRepositoryProvider.overrideWithValue(servicesRepo),
          itemsRepositoryProvider.overrideWithValue(itemsRepo),
          workOrdersRepositoryProvider.overrideWithValue(workOrdersRepo),
          employeesRepositoryProvider.overrideWithValue(employeesRepo),
          stockServiceProvider.overrideWithValue(StockService(db)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: child ?? const WorkOrdersPage(),
            ),
          ),
        ),
      );
    }

    testWidgets('WorkOrdersPage renders KPI cards, toolbar filters, and table', (tester) async {
      final (custId, vehId) = await setupCustomerAndVehicle(
        name: 'عمرو خالد',
        phone: '01055554444',
        plate: 'ج د هـ 1111',
      );

      await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'تغيير مساعدين وفحمات',
      );

      tester.view.physicalSize = const Size(1300, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.workOrdersTitle), findsOneWidget);
      expect(find.text(AppStrings.kpiInProgressOrders), findsOneWidget);
      expect(find.text(AppStrings.kpiReadyOrders), findsOneWidget);
      expect(find.text(AppStrings.kpiTodayOrders), findsOneWidget);
      expect(find.text('عمرو خالد'), findsOneWidget);
      expect(find.text('ج د هـ 1111'), findsOneWidget);
    });

    testWidgets('WorkOrderFormDialog opens, validates required fields, and creates order', (tester) async {
      await setupCustomerAndVehicle(
        name: 'طارق حسام',
        phone: '01144443333',
        plate: 'ن م ل 9999',
      );

      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(child: const WorkOrderFormDialog()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.newWorkOrderButton), findsOneWidget);
      expect(find.text(AppStrings.complaintLabel), findsOneWidget);

      // Search for customer by name and select from search results
      await tester.enterText(
        find.widgetWithText(TextFormField, 'ابحث عن العميل (الاسم أو رقم الهاتف أو رقم اللوحة)'),
        'طارق',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('طارق حسام'), findsOneWidget);
      await tester.tap(find.text('طارق حسام'));
      await tester.pumpAndSettle();

      // Enter complaint
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.complaintLabel),
        'فحص دوري كامل وتغيير سيور',
      );
      await tester.pumpAndSettle();

      // Submit form
      await tester.tap(find.text('فتح أمر الشغل'));
      await tester.pumpAndSettle();

      final orders = await workOrdersRepo.getWorkOrders();
      expect(orders.length, equals(1));
      expect(orders.first.workOrder.complaint, equals('فحص دوري كامل وتغيير سيور'));
    });

    testWidgets('WorkOrderFormDialog allows selecting receiving employee from workshop employees', (tester) async {
      await employeesRepo.insertEmployee(
        const EmployeesCompanion(
          name: drift.Value('المهندس حازم'),
          role: drift.Value('مهندس استقبال صيانة'),
          phone: drift.Value('01011112222'),
        ),
      );

      await setupCustomerAndVehicle(
        name: 'كريم نبيل',
        phone: '01099998888',
        plate: 'س ع د 7777',
      );

      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(child: const WorkOrderFormDialog()));
      await tester.pumpAndSettle();

      // Search and select customer
      await tester.enterText(
        find.widgetWithText(TextFormField, 'ابحث عن العميل (الاسم أو رقم الهاتف أو رقم اللوحة)'),
        '01099998888',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('كريم نبيل'));
      await tester.pumpAndSettle();

      // Because there is 1 active employee, it auto-selects them
      expect(find.text('المهندس حازم (مهندس استقبال صيانة)'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.complaintLabel),
        'كشف وصيانة',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('فتح أمر الشغل'));
      await tester.pumpAndSettle();

      final orders = await workOrdersRepo.getWorkOrders();
      final latest = orders.firstWhere((o) => o.customer.name == 'كريم نبيل');
      expect(latest.workOrder.mechanicName, equals('المهندس حازم'));
    });

    testWidgets('WorkOrderFormDialog searches customer and displays previous maintenance history', (tester) async {
      final (custId, vehId) = await setupCustomerAndVehicle(
        name: 'عصام عبد الرحمن',
        phone: '01055556666',
        plate: 'ف ر س 1234',
      );

      // Create prior work order for this customer
      await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'تغيير زيت وفلاتر',
        mechanicName: 'أسامة فني',
        odometer: 60000,
      );

      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(child: const WorkOrderFormDialog()));
      await tester.pumpAndSettle();

      // Initially search field is visible and no customers listed by default
      expect(find.widgetWithText(TextFormField, 'ابحث عن العميل (الاسم أو رقم الهاتف أو رقم اللوحة)'), findsOneWidget);
      expect(find.text('عصام عبد الرحمن'), findsNothing);

      // Search by phone
      await tester.enterText(
        find.widgetWithText(TextFormField, 'ابحث عن العميل (الاسم أو رقم الهاتف أو رقم اللوحة)'),
        '01055556666',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Found in search results
      expect(find.text('عصام عبد الرحمن'), findsOneWidget);

      // Tap customer to select
      await tester.tap(find.text('عصام عبد الرحمن'));
      await tester.pumpAndSettle();

      // Customer details and last maintenance record appear
      expect(find.textContaining('آخر صيانة مسجلة للعميل'), findsOneWidget);
      expect(find.textContaining('تغيير زيت وفلاتر'), findsOneWidget);
      expect(find.textContaining('60000 كم'), findsOneWidget);
    });

    testWidgets('WorkOrderDetailsPane displays order details and advances status', (tester) async {
      final (custId, vehId) = await setupCustomerAndVehicle(
        name: 'ياسر ممدوح',
        phone: '01277778888',
        plate: 'ب ب ب 2222',
      );

      final order = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'صيانة دورية بالكامل',
      );

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(child: WorkOrderDetailsPane(order: order)));
      await tester.pumpAndSettle();

      expect(find.text(order.orderNumberFormatted), findsOneWidget);
      expect(find.text('ياسر ممدوح'), findsOneWidget);
      expect(find.text('ب ب ب 2222'), findsOneWidget);
      expect(find.text(AppStrings.startWork), findsOneWidget);

      // Tap advance status: open -> inProgress
      await tester.tap(find.text(AppStrings.startWork));
      await tester.pumpAndSettle();

      final updated = await workOrdersRepo.getWorkOrderById(order.id);
      expect(updated.status, equals(WorkOrderStatus.inProgress));
    });

    testWidgets('ChangeStatusDialog updates status and submits reason on cancellation', (tester) async {
      final (custId, vehId) = await setupCustomerAndVehicle();

      final order = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'طلب إلغاء',
      );

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(child: ChangeStatusDialog(order: order)));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.changeStatusButton), findsOneWidget);
      expect(find.text(AppStrings.statusCancelled), findsOneWidget);

      // Tap cancelled option
      await tester.tap(find.text(AppStrings.statusCancelled));
      await tester.pumpAndSettle();

      // Enter cancellation reason
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.cancellationReasonLabel),
        'سفر العميل المفاجئ',
      );
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('حفظ التغيير'));
      await tester.pumpAndSettle();

      final cancelled = await workOrdersRepo.getWorkOrderById(order.id);
      expect(cancelled.status, equals(WorkOrderStatus.cancelled));
      expect(cancelled.workOrder.cancellationReason, equals('سفر العميل المفاجئ'));
    });

    test('JobCardBuilder generates valid non-empty PDF bytes', () async {
      final (custId, vehId) = await setupCustomerAndVehicle();

      final order = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'اختبار طباعة كارت الورشة الداخلي',
        mechanicName: 'الأسطى حسني',
        lines: const [
          WorkOrderLineItem(
            lineType: LineType.service,
            description: 'فحص ميكانيكي',
            quantity: 1,
            unitPrice: 10000,
            totalPrice: 10000,
          ),
        ],
      );

      final builder = JobCardBuilder(order: order);
      final pdfBytes = await builder.buildPdf();

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    testWidgets('DeliverWorkOrderDialog renders invoice review, selects InstaPay, and delivers order', (tester) async {
      final (custId, vehId) = await setupCustomerAndVehicle(
        name: 'كريم عبد العزيز',
        phone: '01122334455',
        plate: 'ف ق ك 4321',
      );

      final order = await workOrdersRepo.createWorkOrder(
        customerId: custId,
        vehicleId: vehId,
        complaint: 'صيانة دورية 10000 كم',
        lines: const [
          WorkOrderLineItem(
            lineType: LineType.service,
            description: 'فحص كمبيوتر وصيانة شاملة',
            quantity: 1,
            unitPrice: 35000, // 350 EGP
            totalPrice: 35000,
          ),
        ],
      );

      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(child: DeliverWorkOrderDialog(order: order)));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.deliverWorkOrderTitle), findsOneWidget);
      expect(find.text('كريم عبد العزيز'), findsOneWidget);
      expect(find.text('شكوى العميل: صيانة دورية 10000 كم'), findsOneWidget);
      expect(find.text('إنستاباي (InstaPay)'), findsOneWidget);

      // Select InstaPay
      await tester.ensureVisible(find.text('إنستاباي (InstaPay)'));
      await tester.tap(find.text('إنستاباي (InstaPay)'));
      await tester.pumpAndSettle();

      // Enter transaction reference
      await tester.ensureVisible(find.widgetWithText(TextFormField, AppStrings.paymentReferenceLabel));
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.paymentReferenceLabel),
        'IPN-REF-2026-X1',
      );
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.text(AppStrings.confirmDeliveryAndPayment));
      await tester.tap(find.text(AppStrings.confirmDeliveryAndPayment));
      await tester.pumpAndSettle();

      final delivered = await workOrdersRepo.getWorkOrderById(order.id);
      expect(delivered.status, equals(WorkOrderStatus.delivered));
      expect(delivered.hasInvoice, isTrue);
      expect(delivered.primaryPaymentMethod, equals(PaymentMethod.instapay));
      expect(delivered.paymentReference, equals('IPN-REF-2026-X1'));
    });
  });
}
