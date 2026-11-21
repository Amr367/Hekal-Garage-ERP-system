import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/db/repositories/purchases_repository.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/purchase_invoice_with_details.dart';
import '../domain/purchases_summary.dart';
import '../domain/supplier_with_balance.dart';

/// Purchases search query notifier.
class PurchasesSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final purchasesSearchQueryProvider =
    NotifierProvider<PurchasesSearchQueryNotifier, String>(
  PurchasesSearchQueryNotifier.new,
);

/// Supplier filter notifier (null means all suppliers).
class SupplierFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void selectSupplier(int? supplierId) => state = supplierId;
}

final supplierFilterProvider =
    NotifierProvider<SupplierFilterNotifier, int?>(
  SupplierFilterNotifier.new,
);

/// Selected purchase invoice ID notifier for master-detail pane.
class SelectedPurchaseIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final selectedPurchaseIdProvider =
    NotifierProvider<SelectedPurchaseIdNotifier, int?>(
  SelectedPurchaseIdNotifier.new,
);

/// Purchases summary metrics provider.
final purchasesSummaryProvider = FutureProvider<PurchasesSummary>((ref) async {
  final repo = ref.watch(purchasesRepositoryProvider);
  return repo.getPurchasesSummary();
});

/// Purchases list provider with search and supplier filter.
final purchasesListProvider =
    FutureProvider<List<PurchaseInvoiceWithDetails>>((ref) async {
  final repo = ref.watch(purchasesRepositoryProvider);
  final query = ref.watch(purchasesSearchQueryProvider);
  final supplierId = ref.watch(supplierFilterProvider);

  return repo.getPurchaseInvoices(
    searchQuery: query,
    supplierId: supplierId,
  );
});

/// Selected purchase invoice details provider.
final selectedPurchaseProvider =
    FutureProvider<PurchaseInvoiceWithDetails?>((ref) async {
  final selectedId = ref.watch(selectedPurchaseIdProvider);
  if (selectedId == null) return null;

  final repo = ref.watch(purchasesRepositoryProvider);
  try {
    return await repo.getPurchaseInvoiceById(selectedId);
  } catch (_) {
    return null;
  }
});

/// Suppliers with balances provider.
final suppliersListProvider =
    FutureProvider<List<SupplierWithBalance>>((ref) async {
  final repo = ref.watch(suppliersRepositoryProvider);
  return repo.getSuppliersWithBalances();
});

/// Action controller for Purchases & Suppliers operations.
class PurchasesActionsController {
  const PurchasesActionsController(this._ref);

  final Ref _ref;

  Future<PurchaseInvoiceWithDetails> createPurchaseInvoice({
    required int supplierId,
    String? supplierInvoiceNumber,
    required DateTime invoiceDate,
    required int paidAmountPiasters,
    String? notes,
    required List<PurchaseLineInput> lines,
  }) async {
    final repo = _ref.read(purchasesRepositoryProvider);
    final result = await repo.createPurchaseInvoice(
      supplierId: supplierId,
      supplierInvoiceNumber: supplierInvoiceNumber,
      invoiceDate: invoiceDate,
      paidAmountPiasters: paidAmountPiasters,
      notes: notes,
      lines: lines,
    );

    // Invalidate purchases and inventory providers
    _ref.invalidate(purchasesListProvider);
    _ref.invalidate(purchasesSummaryProvider);
    _ref.invalidate(suppliersListProvider);
    _ref.invalidate(inventorySummaryProvider);
    _ref.invalidate(inventoryListProvider);

    _ref.read(selectedPurchaseIdProvider.notifier).select(result.id);
    return result;
  }

  Future<int> createSupplier({
    required String name,
    String? phone,
    String? notes,
  }) async {
    final repo = _ref.read(suppliersRepositoryProvider);
    final id = await repo.insertSupplier(
      SuppliersCompanion(
        name: drift.Value(name.trim()),
        phone: drift.Value(phone?.trim()),
        notes: drift.Value(notes?.trim()),
      ),
    );

    _ref.invalidate(suppliersListProvider);
    _ref.invalidate(purchasesSummaryProvider);
    return id;
  }

  Future<bool> updateSupplier(Supplier supplier) async {
    final repo = _ref.read(suppliersRepositoryProvider);
    final ok = await repo.updateSupplier(supplier);
    _ref.invalidate(suppliersListProvider);
    return ok;
  }

  Future<void> deactivateSupplier(int id) async {
    final repo = _ref.read(suppliersRepositoryProvider);
    await repo.deactivate(id);
    _ref.invalidate(suppliersListProvider);
    _ref.invalidate(purchasesSummaryProvider);
  }

  Future<void> reactivateSupplier(int id) async {
    final repo = _ref.read(suppliersRepositoryProvider);
    await repo.reactivate(id);
    _ref.invalidate(suppliersListProvider);
    _ref.invalidate(purchasesSummaryProvider);
  }

  Future<void> recordSupplierPayment({
    required int supplierId,
    required int amountPiasters,
    String? notes,
  }) async {
    final repo = _ref.read(suppliersRepositoryProvider);
    await repo.recordPayment(
      supplierId: supplierId,
      amountPiasters: amountPiasters,
      notes: notes,
    );

    _ref.invalidate(suppliersListProvider);
    _ref.invalidate(purchasesListProvider);
    _ref.invalidate(purchasesSummaryProvider);
  }
}

final purchasesActionsControllerProvider =
    Provider<PurchasesActionsController>((ref) {
  return PurchasesActionsController(ref);
});
