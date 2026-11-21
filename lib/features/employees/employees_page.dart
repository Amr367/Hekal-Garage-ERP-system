import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/employees_repository.dart';
import '../../core/money/money.dart';
import '../../core/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_scaffold.dart';
import 'presentation/employees_controller.dart';
import 'presentation/widgets/employee_form_dialog.dart';
import 'presentation/widgets/employees_kpi_cards.dart';
import 'presentation/widgets/pay_salary_dialog.dart';
import 'presentation/widgets/record_advance_dialog.dart';

/// Main Employees, Advances, and Payroll management page.
class EmployeesPage extends ConsumerStatefulWidget {
  const EmployeesPage({super.key});

  @override
  ConsumerState<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends ConsumerState<EmployeesPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int? _advancesFilterEmployeeId;
  int? _salariesFilterEmployeeId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(employeesSummaryProvider);

    return AppScaffold(
      title: AppStrings.employeesTitle,
      subtitle: AppStrings.employeesSubtitle,
      actions: [
        OutlinedButton.icon(
          onPressed: () => RecordAdvanceDialog.show(context),
          icon: const Icon(Icons.price_change_outlined, size: 18),
          label: const Text(AppStrings.recordAdvance),
        ),
        FilledButton.tonalIcon(
          onPressed: () => PaySalaryDialog.show(context),
          icon: const Icon(Icons.payments_outlined, size: 18),
          label: const Text(AppStrings.paySalary),
        ),
        FilledButton.icon(
          onPressed: () => EmployeeFormDialog.show(context),
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text(AppStrings.addEmployee),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── KPI Summary Cards ─────────────────────────────────────────────
          summaryAsync.when(
            data: (summary) => EmployeesKpiCards(summary: summary),
            loading: () => const SizedBox(height: 70, child: Center(child: CircularProgressIndicator())),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // ── Navigation Tabs ───────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.badge_outlined), text: AppStrings.tabEmployeesList),
                Tab(icon: Icon(Icons.price_change_outlined), text: AppStrings.tabAdvances),
                Tab(icon: Icon(Icons.payments_outlined), text: AppStrings.tabSalaries),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Tab Views ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEmployeesTab(),
                _buildAdvancesTab(),
                _buildSalariesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Employees Directory Tab ─────────────────────────────────────────────
  Widget _buildEmployeesTab() {
    final employeesAsync = ref.watch(employeesListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'بحث في الموظفين بالاسم، المسمى الوظيفي، أو رقم الهاتف...',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
            onChanged: (val) => ref.read(employeesSearchQueryProvider.notifier).setQuery(val),
          ),
        ),
        const SizedBox(height: 12),

        // Table
        Expanded(
          child: employeesAsync.when(
            data: (employees) {
              if (employees.isEmpty) {
                return const Center(child: Text('لا يوجد موظفون مسجلون مطابقون للبحث.'));
              }

              return AppDataTable<EmployeeWithStats>(
                columns: <AppTableColumn<EmployeeWithStats>>[
                  AppTableColumn<EmployeeWithStats>(
                    title: '#',
                    width: 50,
                    alignment: Alignment.center,
                    cellBuilder: (context, emp, index) => Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                  AppTableColumn<EmployeeWithStats>(
                    title: 'اسم الموظف',
                    flex: 2,
                    cellBuilder: (context, emp, index) => Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            emp.name.isNotEmpty ? emp.name[0] : 'م',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            emp.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppTableColumn<EmployeeWithStats>(
                    title: 'المسمى الوظيفي',
                    width: 140,
                    cellBuilder: (context, emp, index) => Text(emp.role, style: const TextStyle(fontSize: 13)),
                  ),
                  AppTableColumn<EmployeeWithStats>(
                    title: 'رقم الهاتف',
                    width: 120,
                    cellBuilder: (context, emp, index) => Text(emp.phone ?? '—', style: const TextStyle(fontSize: 13)),
                  ),
                  AppTableColumn<EmployeeWithStats>(
                    title: 'الراتب الأساسي',
                    width: 120,
                    cellBuilder: (context, emp, index) => Text(
                      MoneyUtils.format(emp.basicSalaryPiasters, withCurrency: true),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  AppTableColumn<EmployeeWithStats>(
                    title: 'سلف معلقة',
                    width: 110,
                    cellBuilder: (context, emp, index) => Text(
                      MoneyUtils.format(emp.pendingAdvancesPiasters, withCurrency: true),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: emp.pendingAdvancesPiasters > 0 ? AppColors.warning : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  AppTableColumn<EmployeeWithStats>(
                    title: 'رواتب مصروفة',
                    width: 120,
                    cellBuilder: (context, emp, index) => Text(
                      MoneyUtils.format(emp.totalSalariesPaidPiasters, withCurrency: true),
                      style: const TextStyle(fontSize: 13, color: AppColors.success),
                    ),
                  ),
                  AppTableColumn<EmployeeWithStats>(
                    title: 'الحالة',
                    width: 80,
                    alignment: Alignment.center,
                    cellBuilder: (context, emp, index) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: emp.isActive ? AppColors.success.withAlpha(25) : AppColors.danger.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: emp.isActive ? AppColors.success : AppColors.danger),
                      ),
                      child: Text(
                        emp.isActive ? 'نشط' : 'موقوف',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: emp.isActive ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ),
                  ),
                  AppTableColumn<EmployeeWithStats>(
                    title: 'إجراءات',
                    width: 170,
                    alignment: Alignment.center,
                    cellBuilder: (context, emp, index) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.price_change_outlined, size: 16, color: AppColors.warning),
                          tooltip: 'تسجيل سلفة',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () => RecordAdvanceDialog.show(context, preselectedEmployee: emp),
                        ),
                        IconButton(
                          icon: const Icon(Icons.payments_outlined, size: 16, color: AppColors.primary),
                          tooltip: 'صرف راتب',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () => PaySalaryDialog.show(context, preselectedEmployee: emp),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          tooltip: 'تعديل',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () => EmployeeFormDialog.show(context, existingEmployee: emp),
                        ),
                        IconButton(
                          icon: Icon(
                            emp.isActive ? Icons.block_outlined : Icons.check_circle_outline,
                            size: 16,
                            color: emp.isActive ? AppColors.danger : AppColors.success,
                          ),
                          tooltip: emp.isActive ? 'إيقاف الموظف' : 'تفعيل الموظف',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () => ref.read(employeesActionsControllerProvider).toggleEmployeeActive(emp.id),
                        ),
                      ],
                    ),
                  ),
                ],
                items: employees,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
          ),
        ),
      ],
    );
  }

  // ── 2. Advances & Withdrawals Tab ──────────────────────────────────────────
  Widget _buildAdvancesTab() {
    final advancesAsync = ref.watch(employeeAdvancesProvider(_advancesFilterEmployeeId));
    final employeesAsync = ref.watch(employeesListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: employeesAsync.when(
                  data: (employees) {
                    return DropdownButtonFormField<int?>(
                      initialValue: _advancesFilterEmployeeId,
                      decoration: const InputDecoration(
                        labelText: 'تصفية حسب الموظف',
                        isDense: true,
                        prefixIcon: Icon(Icons.filter_alt_outlined, size: 18),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('جميع الموظفين')),
                        ...employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))),
                      ],
                      onChanged: (val) => setState(() => _advancesFilterEmployeeId = val),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.tonalIcon(
                onPressed: () => RecordAdvanceDialog.show(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('تسجيل سلفة جديدة'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Advances Table
        Expanded(
          child: advancesAsync.when(
            data: (advances) {
              if (advances.isEmpty) {
                return const Center(child: Text('لا توجد سلفيات أو مسحوبات مسجلة.'));
              }

              return AppDataTable<EmployeeAdvanceWithDetails>(
                columns: <AppTableColumn<EmployeeAdvanceWithDetails>>[
                  AppTableColumn<EmployeeAdvanceWithDetails>(
                    title: '#',
                    width: 50,
                    alignment: Alignment.center,
                    cellBuilder: (context, item, index) => Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                  AppTableColumn<EmployeeAdvanceWithDetails>(
                    title: 'تاريخ السحب',
                    width: 100,
                    cellBuilder: (context, item, index) => Text(
                      '${item.date.year}/${item.date.month.toString().padLeft(2, '0')}/${item.date.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  AppTableColumn<EmployeeAdvanceWithDetails>(
                    title: 'اسم الموظف',
                    flex: 2,
                    cellBuilder: (context, item, index) => Text(item.employee.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  AppTableColumn<EmployeeAdvanceWithDetails>(
                    title: 'مبلغ السلفة (ج.م)',
                    width: 120,
                    cellBuilder: (context, item, index) => Text(
                      MoneyUtils.format(item.amountPiasters, withCurrency: true),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.danger),
                    ),
                  ),
                  AppTableColumn<EmployeeAdvanceWithDetails>(
                    title: 'طريقة الصرف',
                    width: 100,
                    cellBuilder: (context, item, index) {
                      final methodLabel = switch (item.paymentMethod) {
                        PaymentMethod.cash => 'خزنة كاش',
                        PaymentMethod.instapay => 'انستاباي',
                        PaymentMethod.wallet => 'محفظة',
                        PaymentMethod.card => 'فيزا',
                        PaymentMethod.transfer => 'تحويل',
                      };
                      return Text(methodLabel, style: const TextStyle(fontSize: 12));
                    },
                  ),
                  AppTableColumn<EmployeeAdvanceWithDetails>(
                    title: 'السبب / ملاحظات',
                    flex: 2,
                    cellBuilder: (context, item, index) => Text(item.notes ?? '—', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                  AppTableColumn<EmployeeAdvanceWithDetails>(
                    title: 'حالة الخصم',
                    width: 120,
                    alignment: Alignment.center,
                    cellBuilder: (context, item, index) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.isDeducted ? AppColors.success.withAlpha(25) : AppColors.warning.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: item.isDeducted ? AppColors.success : AppColors.warning),
                      ),
                      child: Text(
                        item.isDeducted ? 'تم الخصم بالراتب' : 'معلقة للخصم',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item.isDeducted ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ),
                  ),
                  AppTableColumn<EmployeeAdvanceWithDetails>(
                    title: 'إجراءات',
                    width: 70,
                    alignment: Alignment.center,
                    cellBuilder: (context, item, index) => item.isDeducted
                        ? const Text('—')
                        : IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                            tooltip: 'حذف السلفة',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('تأكيد حذف السلفة'),
                                  content: Text('هل أنت متأكد من حذف هذه السلفة بمبلغ "${MoneyUtils.format(item.amountPiasters, withCurrency: true)}" للموظف ${item.employee.name}؟'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('حذف'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(employeesActionsControllerProvider).deleteAdvance(item.id);
                              }
                            },
                          ),
                  ),
                ],
                items: advances,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
          ),
        ),
      ],
    );
  }

  // ── 3. Salaries History Tab ───────────────────────────────────────────────
  Widget _buildSalariesTab() {
    final salariesAsync = ref.watch(salaryPaymentsProvider(_salariesFilterEmployeeId));
    final employeesAsync = ref.watch(employeesListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: employeesAsync.when(
                  data: (employees) {
                    return DropdownButtonFormField<int?>(
                      initialValue: _salariesFilterEmployeeId,
                      decoration: const InputDecoration(
                        labelText: 'تصفية حسب الموظف',
                        isDense: true,
                        prefixIcon: Icon(Icons.filter_alt_outlined, size: 18),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('جميع الموظفين')),
                        ...employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))),
                      ],
                      onChanged: (val) => setState(() => _salariesFilterEmployeeId = val),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.tonalIcon(
                onPressed: () => PaySalaryDialog.show(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('صرف راتب جديد'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Salaries Table
        Expanded(
          child: salariesAsync.when(
            data: (salaries) {
              if (salaries.isEmpty) {
                return const Center(child: Text('لا توجد رواتب مسجلة حتى الآن.'));
              }

              return AppDataTable<SalaryPaymentWithDetails>(
                columns: <AppTableColumn<SalaryPaymentWithDetails>>[
                  AppTableColumn<SalaryPaymentWithDetails>(
                    title: '#',
                    width: 50,
                    alignment: Alignment.center,
                    cellBuilder: (context, item, index) => Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                  AppTableColumn<SalaryPaymentWithDetails>(
                    title: 'تاريخ الصرف',
                    width: 100,
                    cellBuilder: (context, item, index) => Text(
                      '${item.paymentDate.year}/${item.paymentDate.month.toString().padLeft(2, '0')}/${item.paymentDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  AppTableColumn<SalaryPaymentWithDetails>(
                    title: 'الفترة',
                    width: 80,
                    cellBuilder: (context, item, index) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withAlpha(50),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${item.month}/${item.year}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ),
                  AppTableColumn<SalaryPaymentWithDetails>(
                    title: 'الموظف',
                    flex: 2,
                    cellBuilder: (context, item, index) => Text(item.employee.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  AppTableColumn<SalaryPaymentWithDetails>(
                    title: 'الأساسي',
                    width: 100,
                    cellBuilder: (context, item, index) => Text(MoneyUtils.format(item.basicSalaryPiasters, withCurrency: true), style: const TextStyle(fontSize: 13)),
                  ),
                  AppTableColumn<SalaryPaymentWithDetails>(
                    title: 'سلف مخصومة',
                    width: 100,
                    cellBuilder: (context, item, index) => Text('- ${MoneyUtils.format(item.advancesDeductedPiasters, withCurrency: true)}', style: const TextStyle(fontSize: 13, color: AppColors.warning)),
                  ),
                  AppTableColumn<SalaryPaymentWithDetails>(
                    title: 'مكافآت',
                    width: 90,
                    cellBuilder: (context, item, index) => Text('+ ${MoneyUtils.format(item.bonusPiasters, withCurrency: true)}', style: const TextStyle(fontSize: 13, color: AppColors.success)),
                  ),
                  AppTableColumn<SalaryPaymentWithDetails>(
                    title: 'خصومات',
                    width: 90,
                    cellBuilder: (context, item, index) => Text('- ${MoneyUtils.format(item.penaltyPiasters, withCurrency: true)}', style: const TextStyle(fontSize: 13, color: AppColors.danger)),
                  ),
                  AppTableColumn<SalaryPaymentWithDetails>(
                    title: 'الصافي المدفوع',
                    width: 120,
                    cellBuilder: (context, item, index) => Text(MoneyUtils.format(item.netPaidPiasters, withCurrency: true), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary)),
                  ),
                  AppTableColumn<SalaryPaymentWithDetails>(
                    title: 'طريقة الدفع',
                    width: 90,
                    cellBuilder: (context, item, index) {
                      final methodLabel = switch (item.paymentMethod) {
                        PaymentMethod.cash => 'خزنة كاش',
                        PaymentMethod.instapay => 'انستاباي',
                        PaymentMethod.wallet => 'محفظة',
                        PaymentMethod.card => 'فيزا',
                        PaymentMethod.transfer => 'تحويل',
                      };
                      return Text(methodLabel, style: const TextStyle(fontSize: 12));
                    },
                  ),
                  AppTableColumn<SalaryPaymentWithDetails>(
                    title: 'إجراءات',
                    width: 70,
                    alignment: Alignment.center,
                    cellBuilder: (context, item, index) => IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                      tooltip: 'حذف عملية الصرف واسترجاع السلف',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('تأكيد حذف عملية صرف الراتب'),
                            content: Text('هل أنت متأكد من حذف صرف راتب شهر ${item.month}/${item.year} للموظف ${item.employee.name}؟ سيتم إلغاء خصم أي سلف مرتبطة بهذا المسير تلقائياً.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('حذف الراتب'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(employeesActionsControllerProvider).deleteSalaryPayment(item.id);
                        }
                      },
                    ),
                  ),
                ],
                items: salaries,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
          ),
        ),
      ],
    );
  }
}
