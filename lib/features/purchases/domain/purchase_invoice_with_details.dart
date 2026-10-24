import 'package:flutter/foundation.dart';
import '../../../core/db/database.dart';
import '../../../core/money/money.dart';
import 'purchase_line_item.dart';

enum PurchasePaymentStatus {
  paid, // مدفوعة بالكامل
  partial, // مسددة جزئياً
  unpaid, // آجل بالكامل
}

/// Complete Purchase Invoice aggregate with supplier and lines.
@immutable
class PurchaseInvoiceWithDetails {
  const PurchaseInvoiceWithDetails({
    required this.invoice,
    required this.supplier,
    required this.lines,
  });

  final PurchaseInvoice invoice;
  final Supplier supplier;
  final List<PurchaseLineItem> lines;

  int get id => invoice.id;
  int get supplierId => invoice.supplierId;
  String? get supplierInvoiceNumber => invoice.supplierInvoiceNumber;
  DateTime get invoiceDate => invoice.invoiceDate;
  int get totalAmountPiasters => invoice.totalAmount;
  int get paidAmountPiasters => invoice.paidAmount;
  String? get notes => invoice.notes;
  DateTime get createdAt => invoice.createdAt;

  int get remainingAmountPiasters => totalAmountPiasters - paidAmountPiasters;

  PurchasePaymentStatus get paymentStatus {
    if (paidAmountPiasters >= totalAmountPiasters) {
      return PurchasePaymentStatus.paid;
    } else if (paidAmountPiasters > 0) {
      return PurchasePaymentStatus.partial;
    } else {
      return PurchasePaymentStatus.unpaid;
    }
  }

  String get paymentStatusArabic {
    switch (paymentStatus) {
      case PurchasePaymentStatus.paid:
        return 'مدفوعة بالكامل';
      case PurchasePaymentStatus.partial:
        return 'مسددة جزئياً';
      case PurchasePaymentStatus.unpaid:
        return 'آجل بالكامل';
    }
  }

  String get formattedTotal => MoneyUtils.formatPiasters(totalAmountPiasters);
  String get formattedPaid => MoneyUtils.formatPiasters(paidAmountPiasters);
  String get formattedRemaining => MoneyUtils.formatPiasters(remainingAmountPiasters);

  String get formattedDate {
    return '${invoiceDate.year}/${invoiceDate.month.toString().padLeft(2, '0')}/${invoiceDate.day.toString().padLeft(2, '0')}';
  }

  PurchaseInvoiceWithDetails copyWith({
    PurchaseInvoice? invoice,
    Supplier? supplier,
    List<PurchaseLineItem>? lines,
  }) {
    return PurchaseInvoiceWithDetails(
      invoice: invoice ?? this.invoice,
      supplier: supplier ?? this.supplier,
      lines: lines ?? this.lines,
    );
  }
}
