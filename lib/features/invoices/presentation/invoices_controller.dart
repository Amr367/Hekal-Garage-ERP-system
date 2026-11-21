import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/db/repositories/invoices_repository.dart';
import '../../../core/widgets/state_views.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/invoice_line_entry.dart';
import '../domain/invoice_print_builder.dart';
import '../domain/invoice_with_details.dart';
import '../domain/invoices_summary.dart';

// ── Search & Filter Notifiers ────────────────────────────────────────────────

class InvoiceSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
  void clear() => state = '';
}

final invoiceSearchQueryProvider =
    NotifierProvider<InvoiceSearchQueryNotifier, String>(
  InvoiceSearchQueryNotifier.new,
);

class InvoiceStatusFilterNotifier extends Notifier<InvoiceStatus?> {
  @override
  InvoiceStatus? build() => null;

  void setFilter(InvoiceStatus? status) => state = status;
}

final invoiceStatusFilterProvider =
    NotifierProvider<InvoiceStatusFilterNotifier, InvoiceStatus?>(
  InvoiceStatusFilterNotifier.new,
);

class SelectedInvoiceIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final selectedInvoiceIdProvider =
    NotifierProvider<SelectedInvoiceIdNotifier, int?>(
  SelectedInvoiceIdNotifier.new,
);

// ── Data Providers ───────────────────────────────────────────────────────────

final invoicesListProvider =
    FutureProvider.autoDispose<List<InvoiceWithDetails>>((ref) async {
  final repo = ref.watch(invoicesRepositoryProvider);
  final query = ref.watch(invoiceSearchQueryProvider);
  final status = ref.watch(invoiceStatusFilterProvider);

  return repo.getAll(
    query: query,
    statusFilter: status,
  );
});

final invoicesSummaryProvider =
    FutureProvider.autoDispose<InvoicesSummary>((ref) async {
  final repo = ref.watch(invoicesRepositoryProvider);
  return repo.getSummary();
});

final selectedInvoiceProvider = Provider.autoDispose<InvoiceWithDetails?>((ref) {
  final selectedId = ref.watch(selectedInvoiceIdProvider);
  if (selectedId == null) return null;

  final invoicesAsync = ref.watch(invoicesListProvider);
  return invoicesAsync.value?.where((i) => i.id == selectedId).firstOrNull;
});

// ── Actions Controller ───────────────────────────────────────────────────────

class InvoicesActionsController {
  const InvoicesActionsController(this._ref);

  final Ref _ref;

  InvoicesRepository get _repo => _ref.read(invoicesRepositoryProvider);

  Future<InvoiceWithDetails> createDirectSale({
    int? customerId,
    required List<InvoiceLineEntry> lines,
    int discountAmountPiasters = 0,
    int paidAmountPiasters = 0,
    required PaymentMethod paymentMethod,
    String? paymentNotes,
    String? notes,
  }) async {
    final invoice = await _repo.createDirectSale(
      customerId: customerId,
      lines: lines,
      discountAmountPiasters: discountAmountPiasters,
      paidAmountPiasters: paidAmountPiasters,
      paymentMethod: paymentMethod,
      paymentNotes: paymentNotes,
      notes: notes,
    );

    _ref.invalidate(invoicesListProvider);
    _ref.invalidate(invoicesSummaryProvider);
    _ref.read(selectedInvoiceIdProvider.notifier).select(invoice.id);

    return invoice;
  }

  Future<void> recordPayment({
    required int invoiceId,
    required int amountPiasters,
    required PaymentMethod method,
    String? notes,
  }) async {
    await _repo.recordPayment(
      invoiceId: invoiceId,
      amountPiasters: amountPiasters,
      method: method,
      notes: notes,
    );

    _ref.invalidate(invoicesListProvider);
    _ref.invalidate(invoicesSummaryProvider);
  }

  Future<void> cancelInvoice({
    required int invoiceId,
    required String reason,
  }) async {
    await _repo.cancelInvoice(
      invoiceId: invoiceId,
      reason: reason,
    );

    _ref.invalidate(invoicesListProvider);
    _ref.invalidate(invoicesSummaryProvider);
  }

  Future<void> printA4(BuildContext context, InvoiceWithDetails invoice) async {
    try {
      final profile = await _ref.read(garageProfileProvider.future);
      final doc = InvoicePrintBuilder.buildA4(invoice, profile);
      final pdfBytes = await doc.save();

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'فاتورة_مبيعات_${invoice.invoiceNumber}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'فشل إنشاء ملف الطباعة: $e');
      }
    }
  }

  Future<void> printThermalReceipt(BuildContext context, InvoiceWithDetails invoice) async {
    try {
      final profile = await _ref.read(garageProfileProvider.future);
      final doc = InvoicePrintBuilder.buildThermalReceipt(invoice, profile);
      final pdfBytes = await doc.save();

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'إيصال_فاتورة_${invoice.invoiceNumber}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.showError(context, 'فشل إنشاء إيصال الطباعة: $e');
      }
    }
  }
}

final invoicesActionsProvider = Provider<InvoicesActionsController>((ref) {
  return InvoicesActionsController(ref);
});
