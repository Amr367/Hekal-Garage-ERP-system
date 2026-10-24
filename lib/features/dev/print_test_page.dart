import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/printing/a4_invoice_builder.dart';
import '../../core/printing/receipt_builder.dart';
import '../../core/strings.dart';

/// A debug-only screen for testing Arabic PDF printing.
///
/// Accessible at the route `/dev/print-test` and guarded by [kDebugMode].
/// Provides buttons to preview, print, and save both an A4 invoice
/// and an 80 mm receipt, plus a printer listing.
class PrintTestPage extends StatefulWidget {
  const PrintTestPage({super.key});

  @override
  State<PrintTestPage> createState() => _PrintTestPageState();
}

class _PrintTestPageState extends State<PrintTestPage> {
  List<Printer>? _printers;
  String _status = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    try {
      final List<Printer> printers = await Printing.listPrinters();
      if (mounted) {
        setState(() {
          _printers = printers;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'خطأ في تحميل الطابعات: $e';
        });
      }
    }
  }

  void _setStatus(String msg) {
    if (mounted) {
      setState(() {
        _status = msg;
      });
    }
  }

  void _setLoading(bool v) {
    if (mounted) {
      setState(() {
        _loading = v;
      });
    }
  }

  // ── PDF generation ───────────────────────────────────────────────

  pw.Document _buildA4() => A4InvoiceBuilder().build();

  pw.Document _buildReceipt() => ReceiptBuilder().build();

  // ── Actions ──────────────────────────────────────────────────────

  Future<void> _previewA4() async {
    _setLoading(true);
    try {
      final pw.Document doc = _buildA4();
      final bytes = await doc.save();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _PreviewPage(
            title: AppStrings.printTestPreviewA4,
            pdfBytes: bytes,
          ),
        ),
      );
      _setStatus('تم عرض المعاينة A4');
    } catch (e) {
      _setStatus('خطأ: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _previewReceipt() async {
    _setLoading(true);
    try {
      final pw.Document doc = _buildReceipt();
      final bytes = await doc.save();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _PreviewPage(
            title: AppStrings.printTestPreviewReceipt,
            pdfBytes: bytes,
          ),
        ),
      );
      _setStatus('تم عرض معاينة الإيصال');
    } catch (e) {
      _setStatus('خطأ: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _printWithDialog(pw.Document doc, String label) async {
    _setLoading(true);
    try {
      final bytes = await doc.save();
      final bool ok = await Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: label,
      );
      _setStatus(ok ? 'تم الإرسال للطباعة: $label' : 'تم الإلغاء');
    } catch (e) {
      _setStatus('خطأ في الطباعة: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _printDirect(
    pw.Document doc,
    String label,
    Printer printer,
  ) async {
    _setLoading(true);
    try {
      final bytes = await doc.save();
      final bool ok = await Printing.directPrintPdf(
        printer: printer,
        onLayout: (_) => bytes,
        name: label,
      );
      _setStatus(
        ok
            ? 'تم الطباعة المباشرة على ${printer.name}'
            : 'فشلت الطباعة المباشرة',
      );
    } catch (e) {
      _setStatus('خطأ: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _savePdf(pw.Document doc, String fileName) async {
    _setLoading(true);
    try {
      final bytes = await doc.save();
      // Save to user's Documents folder.
      final String docsDir = Platform.environment['USERPROFILE'] ?? '.';
      final String path = '$docsDir\\Documents\\$fileName';
      final File file = File(path);
      await file.writeAsBytes(bytes);
      _setStatus('تم الحفظ: $path');
    } catch (e) {
      _setStatus('خطأ في الحفظ: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.printTestTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_loading) const LinearProgressIndicator(),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  color: _status.contains('خطأ')
                      ? Theme.of(context)
                          .colorScheme
                          .errorContainer
                      : Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _status,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),

            // ── A4 Invoice ──────────────────────────────────────
            _SectionCard(
              title: 'فاتورة A4',
              children: <Widget>[
                _ActionButton(
                  icon: Icons.preview,
                  label: AppStrings.printTestPreviewA4,
                  onPressed: _loading ? null : _previewA4,
                ),
                _ActionButton(
                  icon: Icons.print,
                  label: 'طباعة A4 (مع اختيار الطابعة)',
                  onPressed: _loading
                      ? null
                      : () => _printWithDialog(
                            _buildA4(),
                            'فاتورة-تجربة-A4',
                          ),
                ),
                _ActionButton(
                  icon: Icons.save,
                  label: 'حفظ كـ PDF',
                  onPressed: _loading
                      ? null
                      : () => _savePdf(
                            _buildA4(),
                            'test-invoice-a4.pdf',
                          ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 80mm Receipt ────────────────────────────────────
            _SectionCard(
              title: 'إيصال 80mm',
              children: <Widget>[
                _ActionButton(
                  icon: Icons.preview,
                  label: AppStrings.printTestPreviewReceipt,
                  onPressed: _loading ? null : _previewReceipt,
                ),
                _ActionButton(
                  icon: Icons.print,
                  label: 'طباعة إيصال (مع اختيار الطابعة)',
                  onPressed: _loading
                      ? null
                      : () => _printWithDialog(
                            _buildReceipt(),
                            'إيصال-تجربة',
                          ),
                ),
                _ActionButton(
                  icon: Icons.save,
                  label: 'حفظ كـ PDF',
                  onPressed: _loading
                      ? null
                      : () => _savePdf(
                            _buildReceipt(),
                            'test-receipt-80mm.pdf',
                          ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Printers ────────────────────────────────────────
            _SectionCard(
              title: 'الطابعات المتاحة',
              children: <Widget>[
                if (_printers == null)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_printers!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('لم يتم العثور على طابعات'),
                  )
                else
                  ..._printers!.map(
                    (Printer p) => ListTile(
                      leading: Icon(
                        p.isDefault ? Icons.check_circle : Icons.print_outlined,
                        color: p.isDefault
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                        'URL: ${p.url.isEmpty ? "غير متوفر" : p.url}'
                        '${p.isDefault ? " (الافتراضية)" : ""}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => _printDirect(
                                      _buildA4(),
                                      'A4-direct-${p.name}',
                                      p,
                                    ),
                            child: const Text('A4'),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => _printDirect(
                                      _buildReceipt(),
                                      'receipt-direct-${p.name}',
                                      p,
                                    ),
                            child: const Text('إيصال'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _ActionButton(
                  icon: Icons.refresh,
                  label: 'تحديث قائمة الطابعات',
                  onPressed: _loading ? null : _loadPrinters,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preview page (uses printing package PdfPreview) ──────────────────

class _PreviewPage extends StatelessWidget {
  const _PreviewPage({
    required this.title,
    required this.pdfBytes,
  });

  final String title;
  final List<int> pdfBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PdfPreview(
        build: (PdfPageFormat format) async => Uint8List.fromList(pdfBytes),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: '$title.pdf',
      ),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            alignment: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}
