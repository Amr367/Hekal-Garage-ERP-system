import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/db/repositories/reports_repository.dart';
import '../../../core/services/excel_export_service.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/debts_report_data.dart';
import '../domain/inventory_report_data.dart';
import '../domain/report_date_range.dart';
import '../domain/sales_report_data.dart';

// ── State Notifiers ───────────────────────────────────────────────────

/// Notifier for the active report date range filter.
class ReportDateRangeNotifier extends Notifier<ReportDateRange> {
  @override
  ReportDateRange build() => ReportDateRange.thisMonth();

  void setPreset(DateRangePreset preset) {
    switch (preset) {
      case DateRangePreset.today:
        state = ReportDateRange.today();
        break;
      case DateRangePreset.thisWeek:
        state = ReportDateRange.thisWeek();
        break;
      case DateRangePreset.thisMonth:
        state = ReportDateRange.thisMonth();
        break;
      case DateRangePreset.lastMonth:
        state = ReportDateRange.lastMonth();
        break;
      case DateRangePreset.thisYear:
        state = ReportDateRange.thisYear();
        break;
      case DateRangePreset.custom:
        // Keep current start/end, just mark preset as custom
        state = ReportDateRange(
          start: state.start,
          end: state.end,
          preset: DateRangePreset.custom,
        );
        break;
    }
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = ReportDateRange(
      start: DateTime(start.year, start.month, start.day, 0, 0, 0),
      end: DateTime(end.year, end.month, end.day, 23, 59, 59),
      preset: DateRangePreset.custom,
    );
  }
}

final reportDateRangeProvider =
    NotifierProvider<ReportDateRangeNotifier, ReportDateRange>(
      ReportDateRangeNotifier.new,
    );

/// Active tab index in the reports dashboard:
/// 0: Sales & Revenue (المبيعات والإيرادات)
/// 1: Profit & Margins (الأرباح وهوامش الربح)
/// 2: Inventory Valuation & Stagnation (حركة المخزون والركود)
/// 3: Debts & Receivables (الديون والمستحقات)
class ReportsSelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void selectTab(int index) => state = index;
}

final reportsSelectedTabProvider =
    NotifierProvider<ReportsSelectedTabNotifier, int>(
      ReportsSelectedTabNotifier.new,
    );

// ── Data Providers ────────────────────────────────────────────────────

/// Sales & revenue report provider.
final salesReportProvider = FutureProvider.autoDispose<SalesReportData>((
  ref,
) async {
  final repo = ref.watch(reportsRepositoryProvider);
  final range = ref.watch(reportDateRangeProvider);
  return repo.getSalesReport(range.start, range.end);
});

/// Inventory valuation & stagnation report provider.
final inventoryReportProvider = FutureProvider.autoDispose<InventoryReportData>(
  (ref) async {
    final repo = ref.watch(reportsRepositoryProvider);
    return repo.getInventoryReport();
  },
);

/// Debts & receivables report provider.
final debtsReportProvider = FutureProvider.autoDispose<DebtsReportData>((
  ref,
) async {
  final repo = ref.watch(reportsRepositoryProvider);
  return repo.getDebtsReport();
});

// ── Actions Controller ─────────────────────────────────────────────────

class ReportsActionsController {
  const ReportsActionsController(this._ref);

  final Ref _ref;

  ReportsRepository get _repo => _ref.read(reportsRepositoryProvider);

  /// Exports current sales report to Excel.
  Future<void> exportSalesReport(BuildContext context) async {
    try {
      final range = _ref.read(reportDateRangeProvider);
      final salesData = await _repo.getSalesReport(range.start, range.end);
      final bytes = _repo.exportSalesReportToExcel(salesData, range);

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'تصدير تقرير المبيعات إلى Excel',
        fileName: 'sales_report_${range.start.year}_${range.start.month}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (savePath != null) {
        final file = File(
          savePath.endsWith('.xlsx') ? savePath : '$savePath.xlsx',
        );
        await file.writeAsBytes(Uint8List.fromList(bytes));
        if (context.mounted) {
          AppSnackbar.showSuccess(context, 'تم تصدير ملف الإكسيل بنجاح');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'فشل تصدير التقرير: $e');
      }
    }
  }

  /// Exports current profit report to Excel.
  Future<void> exportProfitReport(BuildContext context) async {
    try {
      final range = _ref.read(reportDateRangeProvider);
      final salesData = await _repo.getSalesReport(range.start, range.end);
      final bytes = _repo.exportProfitReportToExcel(salesData, range);

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'تصدير تقرير الأرباح إلى Excel',
        fileName: 'profit_report_${range.start.year}_${range.start.month}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (savePath != null) {
        final file = File(
          savePath.endsWith('.xlsx') ? savePath : '$savePath.xlsx',
        );
        await file.writeAsBytes(Uint8List.fromList(bytes));
        if (context.mounted) {
          AppSnackbar.showSuccess(context, 'تم تصدير ملف الأرباح بنجاح');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'فشل تصدير تقرير الأرباح: $e');
      }
    }
  }

  /// Exports current inventory report to Excel.
  Future<void> exportInventoryReport(BuildContext context) async {
    try {
      final data = await _repo.getInventoryReport();
      final bytes = _repo.exportInventoryReportToExcel(data);

      final now = DateTime.now();
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'تصدير تقرير تقييم المخزون إلى Excel',
        fileName: 'inventory_report_${now.year}_${now.month}_${now.day}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (savePath != null) {
        final file = File(
          savePath.endsWith('.xlsx') ? savePath : '$savePath.xlsx',
        );
        await file.writeAsBytes(Uint8List.fromList(bytes));
        if (context.mounted) {
          AppSnackbar.showSuccess(context, 'تم تصدير ملف تقييم المخزون بنجاح');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'فشل تصدير التقرير: $e');
      }
    }
  }

  /// Exports current debts report to Excel.
  Future<void> exportDebtsReport(BuildContext context) async {
    try {
      final data = await _repo.getDebtsReport();
      final bytes = _repo.exportDebtsReportToExcel(data);

      final now = DateTime.now();
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'تصدير تقرير المديونيات إلى Excel',
        fileName: 'debts_report_${now.year}_${now.month}_${now.day}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (savePath != null) {
        final file = File(
          savePath.endsWith('.xlsx') ? savePath : '$savePath.xlsx',
        );
        await file.writeAsBytes(Uint8List.fromList(bytes));
        if (context.mounted) {
          AppSnackbar.showSuccess(context, 'تم تصدير تقرير المديونيات بنجاح');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'فشل تصدير التقرير: $e');
      }
    }
  }

  /// Exports all financial data into a single master Excel workbook with multiple sheets:
  /// Summary, Sales Invoices, Expenses, Purchases, Customer Debts, Supplier Payables, Stock Valuation.
  Future<void> exportComprehensiveFinancialReport(BuildContext context) async {
    try {
      final range = _ref.read(reportDateRangeProvider);
      final salesData = await _repo.getSalesReport(range.start, range.end);
      final debtsData = await _repo.getDebtsReport();
      final inventoryData = await _repo.getInventoryReport();

      final expRepo = _ref.read(expensesRepositoryProvider);
      final expenses = await expRepo.getExpenses(
        startDate: range.start,
        endDate: range.end,
      );

      final purchRepo = _ref.read(purchasesRepositoryProvider);
      final allPurchases = await purchRepo.getPurchaseInvoices();
      final purchasesInRange = allPurchases.where((p) {
        return p.invoiceDate.isAfter(
              range.start.subtract(const Duration(seconds: 1)),
            ) &&
            p.invoiceDate.isBefore(range.end.add(const Duration(seconds: 1)));
      }).toList();

      // Fetch returns within the date range for the comprehensive report
      final retRepo = _ref.read(returnsRepositoryProvider);
      final allReturns = await retRepo.getAll();
      final returnsInRange = allReturns.where((r) {
        return r.createdAt.isAfter(
              range.start.subtract(const Duration(seconds: 1)),
            ) &&
            r.createdAt.isBefore(range.end.add(const Duration(seconds: 1)));
      }).toList();

      final bytes =
          ExcelExportService.exportComprehensiveFinancialReportToExcel(
            salesData: salesData,
            expenses: expenses,
            purchases: purchasesInRange.isNotEmpty
                ? purchasesInRange
                : allPurchases,
            debtsData: debtsData,
            inventoryData: inventoryData,
            range: range,
            returns: returnsInRange.isNotEmpty ? returnsInRange : null,
          );

      final defaultName =
          'comprehensive_financial_report_${range.start.year}_${range.start.month}.xlsx';

      if (!context.mounted) return;

      await ExcelExportService.saveExcelFile(
        context: context,
        bytes: bytes,
        defaultFileName: defaultName,
        dialogTitle: 'تصدير التقرير المالي الشامل إلى Excel',
        successMessage: 'تم تصدير التقرير المالي الشامل بنجاح (ملف مجمع بكافة الحسابات المالية)',
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'فشل تصدير التقرير المالي الشامل: $e');
      }
    }
  }
}

final reportsActionsProvider = Provider<ReportsActionsController>(
  (ref) => ReportsActionsController(ref),
);
