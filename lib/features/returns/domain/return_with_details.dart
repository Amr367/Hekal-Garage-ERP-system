import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/printing/money_format.dart';

/// Full aggregate model for a return record with lines, party, and reference invoice.
class ReturnWithDetails {
  const ReturnWithDetails({
    required this.entry,
    required this.lines,
    this.customer,
    this.supplier,
    this.invoice,
    this.purchaseInvoice,
  });

  final Return entry;
  final List<ReturnLine> lines;
  final Customer? customer;
  final Supplier? supplier;
  final Invoice? invoice;
  final PurchaseInvoice? purchaseInvoice;

  int get id => entry.id;
  int get returnNumber => entry.returnNumber;
  String get returnNumberFormatted => '#${entry.returnNumber.toString().padLeft(4, '0')}';
  ReturnType get returnType => entry.returnType;
  bool get isSaleReturn => entry.returnType == ReturnType.saleReturn;
  bool get isPurchaseReturn => entry.returnType == ReturnType.purchaseReturn;

  String get typeLabel => isSaleReturn ? 'مرتجع مبيعات (عميل)' : 'مرتجع مشتريات (مورد)';

  String get partyName {
    if (isSaleReturn) {
      return customer?.name ?? entry.customerName ?? 'عميل غير مسجل';
    } else {
      return supplier?.name ?? entry.supplierName ?? 'مورد غير محدد';
    }
  }

  int get totalAmount => entry.totalAmount;
  String get formattedTotalAmount => MoneyFormat.formatWithCurrency(totalAmount);
  String get formattedDate => DateFormat('dd/MM/yyyy hh:mm a').format(entry.createdAt);

  String get refundMethodLabel {
    switch (entry.refundMethod) {
      case PaymentMethod.cash:
        return 'نقداً (كاش)';
      case PaymentMethod.wallet:
        return 'محفظة إلكترونية';
      case PaymentMethod.instapay:
        return 'انستاباي (InstaPay)';
      case PaymentMethod.card:
        return 'بطاقة / فيزا';
      case PaymentMethod.transfer:
        return 'تحويل بنكي';
    }
  }

  String? get referenceLabel {
    if (isSaleReturn && invoice != null) {
      return 'فاتورة #${invoice!.invoiceNumber}';
    } else if (isPurchaseReturn && purchaseInvoice != null) {
      final supNum = purchaseInvoice!.supplierInvoiceNumber;
      return supNum != null && supNum.isNotEmpty
          ? 'فاتورة شراء #$supNum'
          : 'فاتورة شراء #${purchaseInvoice!.id}';
    }
    return null;
  }
}
