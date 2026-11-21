import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/db/repositories/services_repository.dart';

// ── Search & Filter Notifiers ────────────────────────────────────────────────

class ServicesSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
  void clear() => state = '';
}

final servicesSearchQueryProvider =
    NotifierProvider<ServicesSearchQueryNotifier, String>(
  ServicesSearchQueryNotifier.new,
);

// ── Data Providers ───────────────────────────────────────────────────────────

final servicesListProvider =
    FutureProvider.autoDispose<List<Service>>((ref) async {
  final repo = ref.watch(servicesRepositoryProvider);
  final query = ref.watch(servicesSearchQueryProvider).trim().toLowerCase();

  final all = await repo.getAll();
  if (query.isEmpty) {
    return all;
  }
  return all.where((s) => s.name.toLowerCase().contains(query)).toList();
});

// ── Actions Controller ───────────────────────────────────────────────────────

class ServicesActionsController {
  const ServicesActionsController(this._ref);

  final Ref _ref;

  ServicesRepository get _repo => _ref.read(servicesRepositoryProvider);

  Future<int> addService({
    required String name,
    required int defaultPricePiasters,
  }) async {
    final id = await _repo.insertService(
      ServicesCompanion(
        name: Value(name.trim()),
        defaultPrice: Value(defaultPricePiasters),
        isActive: const Value(true),
      ),
    );
    _ref.invalidate(servicesListProvider);
    return id;
  }

  Future<void> updatePrice({
    required int id,
    required int newPricePiasters,
  }) async {
    await _repo.updatePrice(id, newPricePiasters);
    _ref.invalidate(servicesListProvider);
  }

  Future<void> updateService({
    required int id,
    required String name,
    required int defaultPricePiasters,
    bool isActive = true,
  }) async {
    final existing = await _repo.getById(id);
    final updated = existing.copyWith(
      name: name.trim(),
      defaultPrice: defaultPricePiasters,
      isActive: isActive,
    );
    await _repo.updateService(updated);
    _ref.invalidate(servicesListProvider);
  }

  Future<void> toggleActive({
    required int id,
    required bool isActive,
  }) async {
    final existing = await _repo.getById(id);
    final updated = existing.copyWith(isActive: isActive);
    await _repo.updateService(updated);
    _ref.invalidate(servicesListProvider);
  }

  Future<void> deactivate(int id) async {
    await _repo.deactivate(id);
    _ref.invalidate(servicesListProvider);
  }
}

final servicesActionsProvider = Provider<ServicesActionsController>((ref) {
  return ServicesActionsController(ref);
});
