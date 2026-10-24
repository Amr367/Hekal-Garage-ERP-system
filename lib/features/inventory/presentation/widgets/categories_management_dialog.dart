import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_form_dialog.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/state_views.dart';
import '../inventory_controller.dart';

/// Comprehensive management dialog for inventory categories:
/// Add, Rename, Merge, and Delete.
class CategoriesManagementDialog extends ConsumerStatefulWidget {
  const CategoriesManagementDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CategoriesManagementDialog(),
    );
  }

  @override
  ConsumerState<CategoriesManagementDialog> createState() =>
      _CategoriesManagementDialogState();
}

class _CategoriesManagementDialogState
    extends ConsumerState<CategoriesManagementDialog> {
  final _newCategoryController = TextEditingController();
  bool _isAdding = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isAdding = true;
      _errorMessage = null;
    });

    try {
      final actions = ref.read(inventoryActionsControllerProvider);
      await actions.createCategory(name);
      _newCategoryController.clear();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  Future<void> _renameCategory(ItemCategory cat) async {
    final controller = TextEditingController(text: cat.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.renameCategoryButton),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: AppStrings.categoryNameLabel),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.of(ctx).pop(text);
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != cat.name && mounted) {
      try {
        final actions = ref.read(inventoryActionsControllerProvider);
        await actions.renameCategory(cat.id, newName);
        if (mounted) {
          AppSnackbar.showSuccess(context, AppStrings.categorySavedSuccess);
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, e.toString().replaceFirst('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _deleteCategory(ItemCategory cat) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: AppStrings.deleteCategoryButton,
      message: 'هل أنت متأكد من حذف قسم "${cat.name}"؟',
      confirmLabel: AppStrings.delete,
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      try {
        final actions = ref.read(inventoryActionsControllerProvider);
        await actions.deleteCategory(cat.id);
        if (mounted) {
          AppSnackbar.showSuccess(context, 'تم حذف القسم بنجاح');
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, e.toString().replaceFirst('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _mergeCategory(ItemCategory sourceCat, List<ItemCategory> allCats) async {
    final targetCandidates = allCats.where((c) => c.id != sourceCat.id).toList();
    if (targetCandidates.isEmpty) {
      AppSnackbar.showError(context, 'لا توجد أقسام أخرى لدمج هذا القسم إليها.');
      return;
    }

    int? selectedTargetId = targetCandidates.first.id;

    final shouldMerge = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('دمج ونقل أصناف القسم'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'سيتم نقل جميع الأصناف التابعة لقسم "${sourceCat.name}" إلى القسم المختار، ثم حذف القسم المصدر.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedTargetId,
                decoration: const InputDecoration(
                  labelText: AppStrings.targetCategoryLabel,
                  prefixIcon: Icon(Icons.arrow_forward),
                ),
                items: targetCandidates.map((c) {
                  return DropdownMenuItem<int>(
                    value: c.id,
                    child: Text(c.name),
                  );
                }).toList(),
                onChanged: (val) {
                  setDialogState(() {
                    selectedTargetId = val;
                  });
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(AppStrings.mergeCategoryButton),
            ),
          ],
        ),
      ),
    );

    if (shouldMerge == true && selectedTargetId != null && mounted) {
      try {
        final actions = ref.read(inventoryActionsControllerProvider);
        await actions.mergeCategories(sourceCat.id, selectedTargetId!);
        if (mounted) {
          AppSnackbar.showSuccess(context, AppStrings.categoryMergedSuccess);
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, e.toString().replaceFirst('Exception: ', ''));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    final itemsAsync = ref.watch(inventoryListProvider);

    // Map each categoryId to count of items in that category
    final itemCounts = <int, int>{};
    itemsAsync.whenData((items) {
      for (final itemWithStock in items) {
        final cId = itemWithStock.item.categoryId;
        itemCounts[cId] = (itemCounts[cId] ?? 0) + 1;
      }
    });

    return AppFormDialog(
      title: AppStrings.manageCategoriesButton,
      maxWidth: 580,
      showSaveButton: false,
      cancelLabel: AppStrings.close,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // New Category Input
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _newCategoryController,
                  decoration: const InputDecoration(
                    labelText: 'اسم القسم الجديد',
                    hintText: 'مثال: فلاتر، فرامل، سيور وبلي...',
                    prefixIcon: Icon(Icons.add_circle_outline),
                  ),
                  onSubmitted: (_) => _addCategory(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _isAdding ? null : _addCategory,
                icon: _isAdding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add),
                label: const Text(AppStrings.newCategoryButton),
              ),
            ],
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],

          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 8),

          // Categories List
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('لا توجد أقسام مسجلة حتى الآن')),
                );
              }

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final count = itemCounts[cat.id] ?? 0;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryContainer,
                        child: Icon(Icons.folder_outlined, size: 18, color: AppColors.primary),
                      ),
                      title: Text(
                        cat.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        '$count صنف مرتبط بهذا القسم',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: AppStrings.renameCategoryButton,
                            onPressed: () => _renameCategory(cat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.call_merge_outlined, size: 18),
                            tooltip: AppStrings.mergeCategoryButton,
                            onPressed: () => _mergeCategory(cat, categories),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                            tooltip: AppStrings.deleteCategoryButton,
                            onPressed: () => _deleteCategory(cat),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Text('حدث خطأ: $err', style: const TextStyle(color: AppColors.danger)),
            ),
          ),
        ],
      ),
    );
  }
}
