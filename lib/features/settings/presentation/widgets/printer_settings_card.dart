import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../../core/printing/a4_invoice_builder.dart';
import '../../../../core/printing/receipt_builder.dart';
import '../../../../core/strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/state_views.dart';
import '../settings_controller.dart';

/// Settings card for configuring default printers, paper sizes, and test printing.
class PrinterSettingsCard extends ConsumerWidget {
  const PrinterSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(printerSettingsProvider);
    final printersAsync = ref.watch(installedPrintersProvider);

    return settingsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.refresh(printerSettingsProvider)),
      data: (settings) {
        final List<Printer> printers = printersAsync.value ?? <Printer>[];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ── Header ─────────────────────────────────────────────────
                Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.print, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            AppStrings.printersTitle,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 2),
                          Text(
                            AppStrings.printersSubtitle,
                            style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: AppStrings.refresh,
                      onPressed: () => ref.invalidate(installedPrintersProvider),
                    ),
                  ],
                ),
                const Divider(height: 36),

                // ── Default Printers Dropdowns ─────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // A4 Invoice Printer
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: settings.invoicePrinter,
                        decoration: const InputDecoration(
                          labelText: AppStrings.invoicePrinterLabel,
                          prefixIcon: Icon(Icons.picture_as_pdf_outlined),
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(AppStrings.noPrinterSelected),
                          ),
                          ...printers.map(
                            (p) => DropdownMenuItem<String?>(
                              value: p.name,
                              child: Text(p.name),
                            ),
                          ),
                        ],
                        onChanged: (val) async {
                          final updated = settings.copyWith(
                            invoicePrinter: val,
                            clearInvoicePrinter: val == null,
                          );
                          await ref
                              .read(printerSettingsProvider.notifier)
                              .saveSettings(updated);
                          if (context.mounted) {
                            AppSnackbar.showSuccess(context, AppStrings.printersSavedSuccess);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Receipt 80mm Printer
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: settings.receiptPrinter,
                        decoration: const InputDecoration(
                          labelText: AppStrings.receiptPrinterLabel,
                          prefixIcon: Icon(Icons.receipt_long_outlined),
                        ),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(AppStrings.noPrinterSelected),
                          ),
                          ...printers.map(
                            (p) => DropdownMenuItem<String?>(
                              value: p.name,
                              child: Text(p.name),
                            ),
                          ),
                        ],
                        onChanged: (val) async {
                          final updated = settings.copyWith(
                            receiptPrinter: val,
                            clearReceiptPrinter: val == null,
                          );
                          await ref
                              .read(printerSettingsProvider.notifier)
                              .saveSettings(updated);
                          if (context.mounted) {
                            AppSnackbar.showSuccess(context, AppStrings.printersSavedSuccess);
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Default Paper Size ─────────────────────────────────────
                const Text(
                  AppStrings.defaultPaperSizeLabel,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text(AppStrings.paperSizeA4),
                      selected: settings.isA4Default,
                      onSelected: (selected) async {
                        if (selected) {
                          final updated = settings.copyWith(defaultPaperSize: 'A4');
                          await ref
                              .read(printerSettingsProvider.notifier)
                              .saveSettings(updated);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text(AppStrings.paperSizeReceipt),
                      selected: !settings.isA4Default,
                      onSelected: (selected) async {
                        if (selected) {
                          final updated = settings.copyWith(defaultPaperSize: 'Receipt80mm');
                          await ref
                              .read(printerSettingsProvider.notifier)
                              .saveSettings(updated);
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Auto-print Switch ──────────────────────────────────────
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    AppStrings.autoPrintLabel,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  value: settings.autoPrintOnSave,
                  onChanged: (val) async {
                    final updated = settings.copyWith(autoPrintOnSave: val);
                    await ref
                        .read(printerSettingsProvider.notifier)
                        .saveSettings(updated);
                  },
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                // ── Test Print Actions ─────────────────────────────────────
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: <Widget>[
                    ElevatedButton.icon(
                      onPressed: () async {
                        final doc = A4InvoiceBuilder().build();
                        await Printing.layoutPdf(
                          onLayout: (PdfPageFormat format) async => doc.save(),
                          name: 'فاتورة_تجريبية_A4.pdf',
                        );
                      },
                      icon: const Icon(Icons.print),
                      label: const Text(AppStrings.testPrintA4),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final doc = ReceiptBuilder().build();
                        await Printing.layoutPdf(
                          onLayout: (PdfPageFormat format) async => doc.save(),
                          name: 'إيصال_حراري_تجريبي.pdf',
                        );
                      },
                      icon: const Icon(Icons.receipt),
                      label: const Text(AppStrings.testPrintReceipt),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
