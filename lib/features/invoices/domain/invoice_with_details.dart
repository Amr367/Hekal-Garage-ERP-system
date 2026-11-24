import '../../../core/db/database.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/formatters.dart';
import 'invoice_line_entry.dart';

/// Full aggregate model for an invoice with its customer, vehicle, lines, and payments.
class InvoiceWithDetails {
  const InvoiceWithDetails({
    required this.invoice,
    this.customer,
    this.vehicle,
    this.workOrder,
    required this.lines,
    required this.payments,
  });

  final Invoice invoice;
  final Customer? customer;
  final Vehicle? vehicle;
  final WorkOrder? workOrder;
  final List<InvoiceLineEntry> lines;
  final List<Payment> payments;

  int get id => invoice.id;
  int? get customerId => invoice.customerId;
  int get invoiceNumber => invoice.invoiceNumber;
  String get invoiceNumberFormatted => '#${invoice.invoiceNumber}';

  int get subtotalPiasters => invoice.subtotal;
  int get discountPiasters => invoice.discountAmount;
  int get totalPiasters => invoice.totalAmount;
  int get paidPiasters => invoice.paidAmount;

  int get remainingPiasters => (totalPiasters - paidPiasters).clamp(0, double.maxFinite.toInt());

  bool get isCancelled => invoice.status == InvoiceStatus.cancelled;
  bool get isPaid => !isCancelled && remainingPiasters <= 0;
  bool get isPartiallyPaid => !isCancelled && paidPiasters > 0 && remainingPiasters > 0;
  bool get isUnpaid => !isCancelled && paidPiasters == 0 && totalPiasters > 0;

  String get customerName => customer?.name ?? 'عميل نقدي مباشر';
  String get customerPhone => customer?.phone ?? '-';
  String get vehicleTitle {
    if (vehicle == null) return '-';
    final plate = Formatters.normalizePlateNumber(vehicle!.plateNumber);
    final modelInfo = '${vehicle!.make ?? ""} ${vehicle!.model ?? ""}'.trim();
    return modelInfo.isNotEmpty ? '$modelInfo ($plate)' : plate;
  }

  String get paymentMethodLabel {
    if (payments.isEmpty) return 'غير مسدد';
    final primary = payments.first.paymentMethod;
    return switch (primary) {
      PaymentMethod.cash => 'خزنة الفرع (كاش)',
      PaymentMethod.instapay => 'انستاباي (InstaPay)',
      PaymentMethod.wallet => 'فودافون كاش / محافظ',
      PaymentMethod.card => 'فيزا / كارت',
      PaymentMethod.transfer => 'تحويل بنكي',
    };
  }

  String get statusLabel {
    if (isCancelled) return 'ملغاة';
    if (isPaid) return 'مدفوعة بالكامل';
    if (isPartiallyPaid) return 'مدفوعة جزئياً';
    return 'غير مسددة (آجل)';
  }

  String get formattedSubtotal => MoneyUtils.format(subtotalPiasters, withCurrency: true);
  String get formattedDiscount => MoneyUtils.format(discountPiasters, withCurrency: true);
  String get formattedTotal => MoneyUtils.format(totalPiasters, withCurrency: true);
  String get formattedPaid => MoneyUtils.format(paidPiasters, withCurrency: true);
  String get formattedRemaining => MoneyUtils.format(remainingPiasters, withCurrency: true);
  String get formattedDate => invoice.issuedAt.toString().split(' ')[0];
}
