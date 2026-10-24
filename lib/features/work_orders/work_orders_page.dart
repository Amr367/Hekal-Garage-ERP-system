import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/state_views.dart';
import 'domain/work_order_with_details.dart';
import 'presentation/widgets/change_status_dialog.dart';
import 'presentation/widgets/work_order_details_pane.dart';
import 'presentation/widgets/work_order_form_dialog.dart';
import 'presentation/widgets/work_orders_kpi_cards.dart';
import 'presentation/work_orders_controller.dart';

/// Desktop Work Orders management page with live KPI cards, smart filtering, and master-detail layout.
class WorkOrdersPage extends ConsumerWidget {
  const WorkOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(workOrdersListProvider);
    final selectedDetailsAsync = ref.watch(selectedWorkOrderDetailsProvider);
    final statusFilter = ref.watch(workOrderStatusFilterProvider);

    return AppScaffold(
      title: AppStrings.workOrdersTitle,
      subtitle: AppStrings.workOrdersSubtitle,
      actions: <Widget>[
        ElevatedButton.icon(
          onPressed: () => WorkOrderFormDialog.show(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text(AppStrings.newWorkOrderButton),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Top KPI Metric Cards ───────────────────────────────────────
          const WorkOrdersKpiCards(),
          const SizedBox(height: 14),

          // ── Toolbar: Search Field & Status Filter Chips ────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: <Widget>[
                // Search Input
                Expanded(
                  flex: 3,
                  child: SearchField(
                    hintText: AppStrings.searchWorkOrdersHint,
                    onChanged: (val) {
                      ref.read(workOrderSearchQueryProvider.notifier).set(val);
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Status Filter Chips
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        _FilterChip(
                          label: AppStrings.allStatuses,
                          isSelected: statusFilter == null,
                          onSelected: () {
                            ref.read(workOrderStatusFilterProvider.notifier).set(null);
                          },
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: AppStrings.statusOpen,
                          isSelected: statusFilter == WorkOrderStatus.open,
                          onSelected: () {
                            ref.read(workOrderStatusFilterProvider.notifier).set(WorkOrderStatus.open);
                          },
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: AppStrings.statusInProgress,
                          isSelected: statusFilter == WorkOrderStatus.inProgress,
                          onSelected: () {
                            ref.read(workOrderStatusFilterProvider.notifier).set(WorkOrderStatus.inProgress);
                          },
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: AppStrings.statusReady,
                          isSelected: statusFilter == WorkOrderStatus.ready,
                          onSelected: () {
                            ref.read(workOrderStatusFilterProvider.notifier).set(WorkOrderStatus.ready);
                          },
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: AppStrings.statusDelivered,
                          isSelected: statusFilter == WorkOrderStatus.delivered,
                          onSelected: () {
                            ref.read(workOrderStatusFilterProvider.notifier).set(WorkOrderStatus.delivered);
                          },
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: AppStrings.statusCancelled,
                          isSelected: statusFilter == WorkOrderStatus.cancelled,
                          onSelected: () {
                            ref.read(workOrderStatusFilterProvider.notifier).set(WorkOrderStatus.cancelled);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Main Content: Table + Master-Detail Split Layout ───────────
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => ErrorState(
                title: 'خطأ في تحميل أوامر الشغل',
                message: err.toString(),
                onRetry: () => ref.refresh(workOrdersListProvider),
              ),
              data: (orders) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final selectedOrder = selectedDetailsAsync.value;
                    final hasSelection = selectedOrder != null;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // Left: Orders Data Table
                        Expanded(
                          flex: 6,
                          child: _buildOrdersTable(context, ref, orders),
                        ),

                        // Right: Master-Detail Side Pane
                        if (hasSelection) ...[
                          const SizedBox(width: 14),
                          SizedBox(
                            width: constraints.maxWidth > 1200 ? 440 : 380,
                            child: WorkOrderDetailsPane(order: selectedOrder),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTable(
    BuildContext context,
    WidgetRef ref,
    List<WorkOrderWithDetails> orders,
  ) {
    if (orders.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: EmptyState(
            title: 'لا توجد أوامر شغل مسجلة تطابق البحث',
            subtitle: 'يمكنك فتح أمر شغل جديد بالضغط على الزر بالأعلى',
            icon: Icons.assignment_outlined,
          ),
        ),
      );
    }

    return AppDataTable<WorkOrderWithDetails>(
      items: orders,
      rowHeight: 54,
      onRowTap: (order) {
        ref.read(selectedWorkOrderIdProvider.notifier).set(order.id);
      },
      columns: <AppTableColumn<WorkOrderWithDetails>>[
        // Order Number
        AppTableColumn<WorkOrderWithDetails>(
          title: 'رقم الأمر',
          width: 95,
          cellBuilder: (context, it, index) => Text(
            it.orderNumberFormatted,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'monospace',
              color: AppColors.primary,
            ),
          ),
        ),

        // Customer Info
        AppTableColumn<WorkOrderWithDetails>(
          title: 'العميل',
          flex: 2,
          cellBuilder: (context, it, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                it.customer.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
              if (it.customer.phone != null)
                Text(
                  it.customer.phone!,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),

        // Vehicle Info
        AppTableColumn<WorkOrderWithDetails>(
          title: 'السيارة واللوحة',
          flex: 2,
          cellBuilder: (context, it, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                it.normalizedPlate,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${it.vehicle.make} ${it.vehicle.model}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Complaint & Mechanic
        AppTableColumn<WorkOrderWithDetails>(
          title: 'الشكوى / الفني',
          flex: 2,
          cellBuilder: (context, it, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                it.workOrder.complaint ?? 'صيانة دورية',
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (it.workOrder.mechanicName != null)
                Text(
                  'الفني: ${it.workOrder.mechanicName}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),

        // Status Badge
        AppTableColumn<WorkOrderWithDetails>(
          title: 'الحالة',
          width: 125,
          cellBuilder: (context, it, index) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: it.statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              it.statusArabic,
              style: TextStyle(
                color: it.statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),

        // Total Amount
        AppTableColumn<WorkOrderWithDetails>(
          title: 'الإجمالي التقديري',
          width: 120,
          cellBuilder: (context, it, index) => Text(
            it.formattedTotal,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.success,
            ),
          ),
        ),

        // Created At
        AppTableColumn<WorkOrderWithDetails>(
          title: 'تاريخ الاستلام',
          width: 125,
          cellBuilder: (context, it, index) => Text(
            it.formattedCreatedAt,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),

        // Actions Column
        AppTableColumn<WorkOrderWithDetails>(
          title: AppStrings.tableActions,
          width: 125,
          cellBuilder: (context, it, index) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  tooltip: AppStrings.editWorkOrderButton,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: it.canEdit ? () => WorkOrderFormDialog.show(context, order: it) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.sync_alt_rounded, size: 16),
                  tooltip: AppStrings.changeStatusButton,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => ChangeStatusDialog.show(context, order: it),
                ),
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  tooltip: 'عرض التفاصيل',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    ref.read(selectedWorkOrderIdProvider.notifier).set(it.id);
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
