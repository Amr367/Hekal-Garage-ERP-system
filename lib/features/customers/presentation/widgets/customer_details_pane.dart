import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../customers_controller.dart';
import '../../domain/customer_details.dart';
import 'customer_form_dialog.dart';
import 'customer_statement_dialog.dart';
import 'transfer_vehicle_dialog.dart';
import 'vehicle_form_dialog.dart';

/// Detailed view card of the selected customer and their vehicles.
class CustomerDetailsPane extends ConsumerWidget {
  const CustomerDetailsPane({
    super.key,
    required this.details,
  });

  final CustomerDetails details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = details.customer;
    final summary = details.summary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header / Profile Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    customer.name.trim().isNotEmpty
                        ? customer.name.trim().characters.first
                        : 'ع',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              customer.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(customer.isActive),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            customer.phone?.isNotEmpty == true
                                ? customer.phone!
                                : 'بدون رقم هاتف',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Customer edit & delete menu
                PopupMenuButton<String>(
                  tooltip: AppStrings.tableActions,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await CustomerFormDialog.show(context, customer: customer);
                    } else if (action == 'delete') {
                      final confirmed = await ConfirmDialog.show(
                        context: context,
                        title: AppStrings.deleteCustomerButton,
                        message: 'هل أنت متأكد من حذف العميل (${customer.name})؟',
                        confirmLabel: AppStrings.delete,
                        isDestructive: true,
                      );
                      if (confirmed == true) {
                        try {
                          await ref.read(customersListProvider.notifier).deleteCustomer(customer.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(AppStrings.customerDeletedSuccess),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceFirst('Exception: ', '')),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text(AppStrings.editCustomerButton),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text(
                            AppStrings.deleteCustomerButton,
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                // Balance & Quick Statement Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: summary.hasDebt
                        ? AppColors.error.withValues(alpha: 0.06)
                        : (summary.isSettled
                            ? AppColors.success.withValues(alpha: 0.06)
                            : AppColors.info.withValues(alpha: 0.06)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: summary.hasDebt
                          ? AppColors.error.withValues(alpha: 0.3)
                          : (summary.isSettled
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.info.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        summary.hasDebt
                            ? Icons.error_outline
                            : (summary.isSettled
                                ? Icons.check_circle_outline
                                : Icons.account_balance_wallet_outlined),
                        color: summary.hasDebt
                            ? AppColors.error
                            : (summary.isSettled ? AppColors.success : AppColors.info),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              summary.hasDebt
                                  ? AppStrings.balanceDue
                                  : (summary.isSettled
                                      ? AppStrings.balanceSettled
                                      : AppStrings.balanceCredit),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary.formattedBalance,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: summary.hasDebt
                                    ? AppColors.error
                                    : (summary.isSettled ? AppColors.success : AppColors.info),
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          CustomerStatementDialog.show(context, details: details);
                        },
                        icon: const Icon(Icons.receipt_long, size: 16),
                        label: const Text(AppStrings.customerStatementTitle),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Notes if present
                if (customer.notes != null && customer.notes!.trim().isNotEmpty) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            customer.notes!,
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Vehicles Header
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.directions_car, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${AppStrings.customerVehiclesTitle} (${details.vehicles.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () async {
                        await VehicleFormDialog.show(context, customerId: customer.id);
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(AppStrings.addVehicleButton),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Vehicles List
                if (details.vehicles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: <Widget>[
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 40,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          AppStrings.noVehiclesForCustomer,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await VehicleFormDialog.show(context, customerId: customer.id);
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(AppStrings.addVehicleButton),
                        ),
                      ],
                    ),
                  )
                else
                  ...details.vehicles.map((v) => _buildVehicleCard(context, ref, v, customer)),

                const SizedBox(height: 24),

                // Work Orders History Header
                Row(
                  children: <Widget>[
                    const Icon(Icons.build_circle_outlined, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${AppStrings.historyTitle} (${details.workOrders.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (details.workOrders.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      AppStrings.noHistoryAvailable,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  )
                else
                  ...details.workOrders.map((wo) => _buildWorkOrderTile(wo)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success.withValues(alpha: 0.12) : AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isActive ? AppStrings.customerStatusActive : AppStrings.customerStatusInactive,
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.error,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVehicleCard(
    BuildContext context,
    WidgetRef ref,
    Vehicle v,
    Customer currentOwner,
  ) {
    final title = '${v.make ?? ''} ${v.model ?? ''} ${v.year ?? ''}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            offset: Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Egyptian style plate badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  v.plateNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.isNotEmpty ? title : 'سيارة بدون تفاصيل',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (v.color != null && v.color!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    v.color!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Specs row
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: <Widget>[
              if (v.lastOdometer != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.speed, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${v.lastOdometer} ${AppStrings.vehicleOdometerUnit}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              if (v.chassisNumber != null && v.chassisNumber!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.fingerprint, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'VIN: ${v.chassisNumber}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
            ],
          ),
          const Divider(height: 16),

          // Actions
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              // Ownership history check
              IconButton(
                tooltip: AppStrings.ownershipTransferLog,
                icon: const Icon(Icons.history_outlined, size: 18),
                onPressed: () async {
                  final logs = await ref.read(vehiclesControllerProvider).getOwnershipHistory(v.id);
                  if (context.mounted) {
                    showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('${AppStrings.ownershipTransferLog} — ${v.plateNumber}'),
                        content: logs.isEmpty
                            ? const Text('لم يتم نقل ملكية هذه السيارة من قبل.')
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: logs
                                    .map((l) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Text('• $l', style: const TextStyle(fontSize: 13)),
                                        ))
                                    .toList(),
                              ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(AppStrings.close),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
              TextButton.icon(
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: () async {
                  await VehicleFormDialog.show(
                    context,
                    customerId: currentOwner.id,
                    vehicle: v,
                  );
                },
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text(AppStrings.editVehicleButton),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.info,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () async {
                  await TransferVehicleDialog.show(
                    context,
                    vehicle: v,
                    currentOwner: currentOwner,
                  );
                },
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text(AppStrings.transferVehicleButton),
              ),
              IconButton(
                tooltip: AppStrings.deleteVehicleButton,
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                onPressed: () async {
                  final confirmed = await ConfirmDialog.show(
                    context: context,
                    title: AppStrings.deleteVehicleButton,
                    message: 'هل أنت متأكد من حذف السيارة (${v.plateNumber})؟',
                    confirmLabel: AppStrings.delete,
                    isDestructive: true,
                  );
                  if (confirmed == true) {
                    try {
                      await ref.read(vehiclesControllerProvider).deleteVehicle(v.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(AppStrings.vehicleDeletedSuccess),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceFirst('Exception: ', '')),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkOrderTile(WorkOrder wo) {
    final d = wo.createdAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '#${wo.orderNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  wo.complaint?.isNotEmpty == true ? wo.complaint! : 'صيانة عامة',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${d.year}/${d.month}/${d.day}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _workOrderStatusLabel(wo.status),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _workOrderStatusLabel(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.open:
        return 'مفتوح';
      case WorkOrderStatus.inProgress:
        return 'تحت الشغل';
      case WorkOrderStatus.ready:
        return 'جاهز';
      case WorkOrderStatus.delivered:
        return 'تم التسليم';
      case WorkOrderStatus.cancelled:
        return 'ملغي';
    }
  }
}
