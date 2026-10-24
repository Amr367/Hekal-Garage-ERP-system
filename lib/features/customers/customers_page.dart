import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/providers.dart';
import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/state_views.dart';
import 'domain/customer_summary.dart';
import 'presentation/customers_controller.dart';
import 'presentation/widgets/customer_details_pane.dart';
import 'presentation/widgets/customer_form_dialog.dart';
import 'presentation/widgets/customer_statement_dialog.dart';

/// Customers and vehicles management page.
class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(customersListProvider);
    final selectedId = ref.watch(selectedCustomerIdProvider);
    final selectedDetailsAsync = ref.watch(selectedCustomerDetailsProvider);
    final onlyActive = ref.watch(customersFilterActiveOnlyProvider);

    return AppScaffold(
      title: AppStrings.customersTitle,
      subtitle: AppStrings.customersSubtitle,
      actions: <Widget>[
        // Smart Search Field (searches customer name, phone, or vehicle plate)
        SearchField(
          hintText: AppStrings.customerSearchHint,
          maxWidth: 320,
          onChanged: (val) {
            ref.read(customersSearchQueryProvider.notifier).set(val);
          },
        ),
        const SizedBox(width: 8),

        // Active filter toggle
        FilterChip(
          selected: onlyActive,
          showCheckmark: false,
          avatar: Icon(
            onlyActive ? Icons.check_circle : Icons.filter_alt_outlined,
            size: 16,
            color: onlyActive ? AppColors.primary : AppColors.textSecondary,
          ),
          label: Text(
            onlyActive ? AppStrings.filterActiveOnly : AppStrings.filterAllCustomers,
            style: TextStyle(
              fontSize: 13,
              fontWeight: onlyActive ? FontWeight.bold : FontWeight.normal,
              color: onlyActive ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          onSelected: (val) {
            ref.read(customersFilterActiveOnlyProvider.notifier).set(val);
          },
        ),
        const SizedBox(width: 8),

        // Add Customer button
        ElevatedButton.icon(
          onPressed: () async {
            await CustomerFormDialog.show(context);
          },
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text(AppStrings.newCustomerButton),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;

          return listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: ErrorState(
                title: AppStrings.genericError,
                message: err.toString(),
                onRetry: () => ref.read(customersListProvider.notifier).refreshList(),
              ),
            ),
            data: (customers) {
              final tableWidget = _buildCustomersTable(
                context,
                ref,
                customers,
                selectedId,
              );

              if (!isWide) {
                // Single column on narrow screens
                return tableWidget;
              }

              // Two-column master-detail layout on wide desktop screens
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Master Table (Customers list)
                  Expanded(
                    flex: 6,
                    child: tableWidget,
                  ),
                  const SizedBox(width: 16),

                  // Detail Pane (Customer & Vehicles profile)
                  Expanded(
                    flex: 5,
                    child: selectedDetailsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Text(
                          e.toString(),
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                      data: (details) {
                        if (details == null) {
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.touch_app_outlined,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  AppStrings.selectCustomerToView,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return CustomerDetailsPane(details: details);
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCustomersTable(
    BuildContext context,
    WidgetRef ref,
    List<CustomerSummary> customers,
    int? selectedId,
  ) {
    if (customers.isEmpty) {
      return Center(
        child: EmptyState(
          title: 'لا يوجد عملاء مطابقين للبحث',
          subtitle: 'يمكنك تغيير شروط البحث أو تسجيل عميل جديد.',
          action: ElevatedButton.icon(
            onPressed: () async {
              await CustomerFormDialog.show(context);
            },
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text(AppStrings.newCustomerButton),
          ),
        ),
      );
    }

    return AppDataTable<CustomerSummary>(
      columns: <AppTableColumn<CustomerSummary>>[
        AppTableColumn<CustomerSummary>(
          title: AppStrings.customerNameLabel,
          flex: 3,
          cellBuilder: (_, summary, index) {
            final isSelected = summary.customer.id == selectedId;
            return Row(
              children: <Widget>[
                if (isSelected)
                  Container(
                    width: 4,
                    height: 24,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Expanded(
                  child: Text(
                    summary.customer.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        AppTableColumn<CustomerSummary>(
          title: AppStrings.customerPhoneLabel,
          width: 130,
          cellBuilder: (_, summary, index) => Text(
            summary.customer.phone?.isNotEmpty == true ? summary.customer.phone! : '—',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        AppTableColumn<CustomerSummary>(
          title: 'السيارات',
          width: 90,
          alignment: Alignment.center,
          cellBuilder: (_, summary, index) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: summary.vehiclesCount > 0
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.directions_car,
                  size: 13,
                  color: summary.vehiclesCount > 0
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  summary.vehiclesCount.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: summary.vehiclesCount > 0
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AppTableColumn<CustomerSummary>(
          title: AppStrings.customerBalanceLabel,
          width: 140,
          cellBuilder: (_, summary, index) {
            final hasDebt = summary.hasDebt;
            final isSettled = summary.isSettled;

            return Text(
              summary.formattedBalance,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: hasDebt
                    ? AppColors.error
                    : (isSettled ? AppColors.success : AppColors.info),
              ),
            );
          },
        ),
        AppTableColumn<CustomerSummary>(
          title: AppStrings.customerStatusLabel,
          width: 90,
          alignment: Alignment.center,
          cellBuilder: (_, summary, index) {
            final active = summary.customer.isActive;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                active ? AppStrings.customerStatusActive : AppStrings.customerStatusInactive,
                style: TextStyle(
                  color: active ? AppColors.success : AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
        AppTableColumn<CustomerSummary>(
          title: AppStrings.tableActions,
          width: 100,
          alignment: Alignment.center,
          cellBuilder: (_, summary, index) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: AppStrings.editCustomerButton,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () async {
                    await CustomerFormDialog.show(context, customer: summary.customer);
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: AppStrings.customerStatementTitle,
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  onPressed: () async {
                    final details = await ref
                        .read(customersRepositoryProvider)
                        .getCustomerDetails(summary.customer.id);
                    if (context.mounted) {
                      CustomerStatementDialog.show(context, details: details);
                    }
                  },
                ),
              ],
            );
          },
        ),
      ],
      items: customers,
      onRowTap: (summary) {
        ref.read(selectedCustomerIdProvider.notifier).set(summary.customer.id);
      },
    );
  }
}
