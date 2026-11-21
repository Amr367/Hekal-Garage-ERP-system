import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../../core/services/excel_export_service.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../inventory_controller.dart';

/// Dialog for importing warehouse items from an Excel (.xlsx) file into the database.
class ImportInventoryDialog extends ConsumerStatefulWidget {
  const ImportInventoryDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ImportInventoryDialog(),
    );
  }

  @override
  ConsumerState<ImportInventoryDialog> createState() =>
      _ImportInventoryDialogState();
}

class _ImportInventoryDialogState extends ConsumerState<ImportInventoryDialog> {
  List<ParsedInventoryExcelRow>? _parsedItems;
  String? _selectedFileName;
  bool _isImporting = false;
  String? _statusMessage;

  Future<void> _downloadTemplate() async {
    final bytes = ExcelExportService.exportInventoryTemplateToExcel();
    await ExcelExportService.saveExcelFile(
      context: context,
      bytes: bytes,
      defaultFileName: 'نموذج_أصناف_المخزن.xlsx',
      dialogTitle: 'حفظ نموذج إكسيل لإدخال الأصناف',
      successMessage: 'تم تنزيل نموذج الإكسيل بنجاح',
    );
  }

  Future<void> _pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر ملف إكسيل يحتوي على الأصناف',
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      if (path == null) return;

      final file = File(path);
      final bytes = await file.readAsBytes();

      final parsed = ExcelExportService.parseInventoryItemsFromExcel(bytes);

      setState(() {
        _selectedFileName = result.files.first.name;
        _parsedItems = parsed;
        if (parsed.isEmpty) {
          _statusMessage =
              'لم يتم العثور على أي أصناف داخل الملف. يرجى التأكد من ملء البيانات.';
        } else {
          _statusMessage = 'تم قراءة ${parsed.length} صنف بنجاح من الملف.';
        }
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'فشل قراءة ملف الإكسيل: $e');
      }
    }
  }

  Future<void> _executeImport() async {
    if (_parsedItems == null || _parsedItems!.isEmpty) return;

    setState(() {
      _isImporting = true;
    });

    try {
      final actions = ref.read(inventoryActionsControllerProvider);
      final categoriesAsync = ref.read(categoriesListProvider);
      final existingCategories = categoriesAsync.value ?? [];

      final categoryCache = <String, int>{};
      for (final cat in existingCategories) {
        categoryCache[cat.name.trim()] = cat.id;
      }

      int defaultCategoryId = existingCategories.isNotEmpty
          ? existingCategories.first.id
          : await actions.createCategory('عام');

      int importedCount = 0;

      for (final row in _parsedItems!) {
        if (!row.isValid) continue;

        // Resolve or create category
        int catId = defaultCategoryId;
        if (row.categoryName != null && row.categoryName!.trim().isNotEmpty) {
          final catTrimmed = row.categoryName!.trim();
          if (categoryCache.containsKey(catTrimmed)) {
            catId = categoryCache[catTrimmed]!;
          } else {
            catId = await actions.createCategory(catTrimmed);
            categoryCache[catTrimmed] = catId;
          }
        }

        await actions.createItem(
          name: row.name.trim(),
          categoryId: catId,
          sku: row.sku?.trim(),
          barcode: row.barcode?.trim(),
          unit: row.unit,
          costPrice: row.costPrice,
          salePrice: row.salePrice,
          openingStock: row.openingStock,
          minQuantity: row.minQuantity,
        );

        importedCount++;
      }

      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.showSuccess(
          context,
          'تم استيراد $importedCount صنف بنجاح إلى المخزن!',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        AppSnackbar.showError(context, 'حدث خطأ أثناء الاستيراد: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(Icons.upload_file_outlined,
                          color: AppColors.primary, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'استيراد وتنزيل أصناف المخزن من ملف Excel',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Action Toolbar: Download Template & Pick File
              Row(
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _isImporting ? null : _downloadTemplate,
                    icon: const Icon(Icons.download_for_offline_outlined,
                        size: 18),
                    label: const Text('تحميل نموذج Excel فارغ'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isImporting ? null : _pickExcelFile,
                    icon: const Icon(Icons.file_open_outlined, size: 18),
                    label: const Text('اختيار ملف إكسيل (.xlsx)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_selectedFileName != null)
                    Expanded(
                      child: Text(
                        'الملف المحدد: $_selectedFileName',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Preview Table
              Expanded(
                child: _parsedItems == null
                    ? Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.table_chart_outlined,
                                size: 48, color: AppColors.textSecondary),
                            SizedBox(height: 12),
                            Text(
                              'اضغط على "تحميل نموذج Excel" لملء الأصناف أو اختر ملف جاهز لعرضه واستيراده.',
                              style:
                                  TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListView.separated(
                          itemCount: _parsedItems!.length + 1,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Container(
                                color: AppColors.primaryContainer,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: const Row(
                                  children: <Widget>[
                                    SizedBox(
                                        width: 40,
                                        child: Text('م',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    Expanded(
                                        flex: 3,
                                        child: Text('اسم الصنف',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    Expanded(
                                        flex: 2,
                                        child: Text('القسم',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    Expanded(
                                        flex: 2,
                                        child: Text('كود SKU',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    Expanded(
                                        flex: 2,
                                        child: Text('سعر الشراء',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    Expanded(
                                        flex: 2,
                                        child: Text('سعر البيع',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    Expanded(
                                        flex: 2,
                                        child: Text('الرصيد',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              );
                            }

                            final item = _parsedItems![index - 1];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                children: <Widget>[
                                  SizedBox(
                                      width: 40,
                                      child: Text('${item.rowIndex}')),
                                  Expanded(
                                      flex: 3,
                                      child: Text(item.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600))),
                                  Expanded(
                                      flex: 2,
                                      child: Text(
                                          item.categoryName ?? 'افتراضي')),
                                  Expanded(
                                      flex: 2,
                                      child: Text(item.sku ?? '-')),
                                  Expanded(
                                      flex: 2,
                                      child: Text(MoneyUtils.formatPounds(
                                          item.costPrice))),
                                  Expanded(
                                      flex: 2,
                                      child: Text(MoneyUtils.formatPounds(
                                          item.salePrice))),
                                  Expanded(
                                      flex: 2,
                                      child: Text(
                                          '${item.openingStock} ${item.unit}')),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: _isImporting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(AppStrings.cancel),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: (_isImporting ||
                            _parsedItems == null ||
                            _parsedItems!.isEmpty)
                        ? null
                        : _executeImport,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(_isImporting
                        ? 'جاري الاستيراد...'
                        : 'تأكيد إضافة الأصناف إلى المخزن'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
