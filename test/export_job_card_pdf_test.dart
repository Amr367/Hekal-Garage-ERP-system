import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_erp/core/printing/font_loader.dart';
import 'package:garage_erp/core/db/database.dart';
import 'package:garage_erp/core/db/repositories/customers_repository.dart';
import 'package:garage_erp/core/db/repositories/vehicles_repository.dart';
import 'package:garage_erp/core/db/repositories/work_orders_repository.dart';
import 'package:garage_erp/features/settings/domain/garage_profile.dart';
import 'package:garage_erp/features/work_orders/domain/work_order_line_item.dart';
import 'package:garage_erp/features/work_orders/presentation/printing/job_card_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate and export sample job card PDF for user preview', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final customersRepo = DriftCustomersRepository(db);
    final vehiclesRepo = DriftVehiclesRepository(db);
    final workOrdersRepo = DriftWorkOrdersRepository(db);

    final custId = await customersRepo.insertCustomer(
      const CustomersCompanion(
        name: drift.Value('خالد مصطفى عبد الرحمن'),
        phone: drift.Value('01012345678'),
      ),
    );

    final vehId = await vehiclesRepo.insertVehicle(
      const VehiclesCompanion(
        customerId: drift.Value(1),
        plateNumber: drift.Value('ب ي د 123 (ف ج 212)'),
        make: drift.Value('شيفروليه'),
        model: drift.Value('أوبترا'),
        year: drift.Value(2021),
        chassisNumber: drift.Value('1G1JC5444R7252841'),
        lastOdometer: drift.Value(85000),
      ),
    );

    final order = await workOrdersRepo.createWorkOrder(
      customerId: custId,
      vehicleId: vehId,
      odometer: 85000,
      complaint: 'صيانة دورية وتغيير تيل وفلاتر ومياه تبريد',
      mechanicName: 'م. أحمد حسام (01099887766)',
      notes: 'شركة التأمين مصر للتأمين - خاص / نقدي',
      lines: const [
        WorkOrderLineItem(
          lineType: LineType.service,
          description: 'تنظيف دورة التبريد وتغيير مياه رادياتير',
          quantity: 1,
          unitPrice: 15000,
          totalPrice: 15000,
        ),
        WorkOrderLineItem(
          lineType: LineType.part,
          description: 'تيل فرامل أمامي كوري أصلي',
          quantity: 1,
          unitPrice: 25000,
          totalPrice: 25000,
        ),
        WorkOrderLineItem(
          lineType: LineType.part,
          description: 'فلتر زيت وفلتر هواء أصلي',
          quantity: 2,
          unitPrice: 12000,
          totalPrice: 24000,
        ),
      ],
    );

    await PdfFontLoader.init();
    expect(PdfFontLoader.logoMg, isNotNull);
    expect(PdfFontLoader.logoOpel, isNotNull);
    expect(PdfFontLoader.logoChevrolet, isNotNull);

    const profile = GarageProfile(
      name: 'مركز هيكل',
      subtitle: 'لاصلاح السيارات',
      phone: '01004497144 - 01067704194',
      address: 'القاهرة - مصر',
    );

    final builder = JobCardBuilder(order: order, garageProfile: profile);
    final pdfBytes = await builder.buildPdf();

    expect(pdfBytes.length, greaterThan(1000));
    expect(
      JobCardBuilder.printableWorkshopNote('شركة التأمين مصر للتأمين - خاص / نقدي'),
      isNull,
    );
    expect(
      JobCardBuilder.printableWorkshopNote('خدش على الباب الأيمن'),
      'خدش على الباب الأيمن',
    );

    final file = File('d:\\Hekal\\job_card_preview.pdf');
    await file.writeAsBytes(pdfBytes);

    expect(file.existsSync(), isTrue);

    await db.close();
  });
}
