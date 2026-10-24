import 'package:flutter/foundation.dart';

/// Immutable domain model representing printer and hardware settings.
@immutable
class PrinterSettings {
  const PrinterSettings({
    this.invoicePrinter,
    this.receiptPrinter,
    this.defaultPaperSize = 'A4',
    this.autoPrintOnSave = false,
  });

  final String? invoicePrinter;
  final String? receiptPrinter;
  final String defaultPaperSize;
  final bool autoPrintOnSave;

  bool get isA4Default => defaultPaperSize == 'A4';

  PrinterSettings copyWith({
    String? invoicePrinter,
    String? receiptPrinter,
    String? defaultPaperSize,
    bool? autoPrintOnSave,
    bool clearInvoicePrinter = false,
    bool clearReceiptPrinter = false,
  }) {
    return PrinterSettings(
      invoicePrinter:
          clearInvoicePrinter ? null : (invoicePrinter ?? this.invoicePrinter),
      receiptPrinter:
          clearReceiptPrinter ? null : (receiptPrinter ?? this.receiptPrinter),
      defaultPaperSize: defaultPaperSize ?? this.defaultPaperSize,
      autoPrintOnSave: autoPrintOnSave ?? this.autoPrintOnSave,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrinterSettings &&
        other.invoicePrinter == invoicePrinter &&
        other.receiptPrinter == receiptPrinter &&
        other.defaultPaperSize == defaultPaperSize &&
        other.autoPrintOnSave == autoPrintOnSave;
  }

  @override
  int get hashCode => Object.hash(
        invoicePrinter,
        receiptPrinter,
        defaultPaperSize,
        autoPrintOnSave,
      );
}
