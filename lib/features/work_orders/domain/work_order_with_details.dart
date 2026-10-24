import 'package:flutter/material.dart';
import '../../../core/db/database.dart';
import '../../../core/money/money.dart';
import '../../../core/strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import 'work_order_line_item.dart';

/// Full aggregate model for a work order with customer, vehicle, lines, and financial sums.
class WorkOrderWithDetails {
  const WorkOrderWithDetails({
    required this.workOrder,
    required this.customer,
    required this.vehicle,
    this.lines = const <WorkOrderLineItem>[],
    this.hasInvoice = false,
    this.invoice,
    this.payments = const <Payment>[],
  });

  final WorkOrder workOrder;
  final Customer customer;
  final Vehicle vehicle;
  final List<WorkOrderLineItem> lines;
  final bool hasInvoice;
  final Invoice? invoice;
  final List<Payment> payments;

  int get id => workOrder.id;
  int get orderNumber => workOrder.orderNumber;
  String get orderNumberFormatted => '#${workOrder.orderNumber}';
  WorkOrderStatus get status => workOrder.status;

  /// Arabic representation for the work order status.
  String get statusArabic {
    switch (workOrder.status) {
      case WorkOrderStatus.open:
        return AppStrings.statusOpen;
      case WorkOrderStatus.inProgress:
        return AppStrings.statusInProgress;
      case WorkOrderStatus.ready:
        return AppStrings.statusReady;
      case WorkOrderStatus.delivered:
        return AppStrings.statusDelivered;
      case WorkOrderStatus.cancelled:
        return AppStrings.statusCancelled;
    }
  }

  /// Semantic badge color for the status.
  Color get statusColor {
    switch (workOrder.status) {
      case WorkOrderStatus.open:
        return AppColors.warning;
      case WorkOrderStatus.inProgress:
        return AppColors.primary;
      case WorkOrderStatus.ready:
        return AppColors.success;
      case WorkOrderStatus.delivered:
        return AppColors.onSurfaceVariant;
      case WorkOrderStatus.cancelled:
        return AppColors.danger;
    }
  }

  /// Total piasters for services/labor lines.
  int get servicesTotalPiasters {
    return lines
        .where((l) => l.isService)
        .fold<int>(0, (sum, l) => sum + l.totalPrice);
  }

  /// Total piasters for spare parts lines.
  int get partsTotalPiasters {
    return lines
        .where((l) => l.isPart)
        .fold<int>(0, (sum, l) => sum + l.totalPrice);
  }

  /// Grand total piasters (services + parts).
  int get totalPiasters => servicesTotalPiasters + partsTotalPiasters;

  String get formattedServicesTotal => MoneyUtils.formatPounds(servicesTotalPiasters);
  String get formattedPartsTotal => MoneyUtils.formatPounds(partsTotalPiasters);
  String get formattedTotal => MoneyUtils.formatPounds(totalPiasters);

  String get formattedCreatedAt {
    final d = workOrder.createdAt;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$year/$month/$day $hour:$min';
  }

  String get formattedClosedAt {
    if (workOrder.closedAt == null) return '-';
    final d = workOrder.closedAt!;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$year/$month/$day';
  }

  String get normalizedPlate => Formatters.normalizePlateNumber(vehicle.plateNumber);

  String get vehicleDisplayTitle {
    final modelPart = '${vehicle.make} ${vehicle.model} ${vehicle.year ?? ''}'.trim();
    return modelPart.isEmpty ? normalizedPlate : '$modelPart ($normalizedPlate)';
  }

  bool get isOpen => workOrder.status == WorkOrderStatus.open;
  bool get isInProgress => workOrder.status == WorkOrderStatus.inProgress;
  bool get isReady => workOrder.status == WorkOrderStatus.ready;
  bool get isDelivered => workOrder.status == WorkOrderStatus.delivered;
  bool get isCancelled => workOrder.status == WorkOrderStatus.cancelled;

  bool get canEdit => !isDelivered && !isCancelled && !hasInvoice;
  bool get canCancel => !isDelivered && !isCancelled && !hasInvoice;
  bool get canDelete => !hasInvoice;

  int? get invoiceNumber => invoice?.invoiceNumber;
  String? get invoiceNumberFormatted => invoice != null ? '#${invoice!.invoiceNumber}' : null;
  PaymentMethod? get primaryPaymentMethod => payments.isNotEmpty ? payments.last.paymentMethod : null;

  String? get paymentMethodArabic {
    if (primaryPaymentMethod == null) return null;
    switch (primaryPaymentMethod!) {
      case PaymentMethod.cash:
        return AppStrings.paymentMethodCash;
      case PaymentMethod.wallet:
        return AppStrings.paymentMethodWallet;
      case PaymentMethod.instapay:
        return AppStrings.paymentMethodInstapay;
      case PaymentMethod.card:
        return AppStrings.paymentMethodCard;
      case PaymentMethod.transfer:
        return AppStrings.paymentMethodTransfer;
    }
  }

  String? get paymentReference => payments.isNotEmpty ? payments.last.notes : null;
  int get paidAmountPiasters => invoice?.paidAmount ?? 0;
  String get formattedPaidAmount => MoneyUtils.formatPounds(paidAmountPiasters);
  int get remainingAmountPiasters {
    if (invoice != null) {
      return (invoice!.totalAmount - invoice!.paidAmount).clamp(0, double.maxFinite.toInt());
    }
    return totalPiasters;
  }
  String get formattedRemainingAmount => MoneyUtils.formatPounds(remainingAmountPiasters);

  WorkOrderWithDetails copyWith({
    WorkOrder? workOrder,
    Customer? customer,
    Vehicle? vehicle,
    List<WorkOrderLineItem>? lines,
    bool? hasInvoice,
    Invoice? invoice,
    List<Payment>? payments,
  }) {
    return WorkOrderWithDetails(
      workOrder: workOrder ?? this.workOrder,
      customer: customer ?? this.customer,
      vehicle: vehicle ?? this.vehicle,
      lines: lines ?? this.lines,
      hasInvoice: hasInvoice ?? this.hasInvoice,
      invoice: invoice ?? this.invoice,
      payments: payments ?? this.payments,
    );
  }
}
