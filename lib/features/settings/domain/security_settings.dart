import 'package:flutter/foundation.dart';

/// Immutable domain model representing PIN security and protected actions.
@immutable
class SecuritySettings {
  const SecuritySettings({
    this.hasPin = false,
    this.isPinEnabled = false,
    this.requirePinDiscount = true,
    this.requirePinCostPrice = true,
    this.requirePinStockAdjust = true,
    this.requirePinVoidInvoice = true,
  });

  final bool hasPin;
  final bool isPinEnabled;
  final bool requirePinDiscount;
  final bool requirePinCostPrice;
  final bool requirePinStockAdjust;
  final bool requirePinVoidInvoice;

  SecuritySettings copyWith({
    bool? hasPin,
    bool? isPinEnabled,
    bool? requirePinDiscount,
    bool? requirePinCostPrice,
    bool? requirePinStockAdjust,
    bool? requirePinVoidInvoice,
  }) {
    return SecuritySettings(
      hasPin: hasPin ?? this.hasPin,
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
      requirePinDiscount: requirePinDiscount ?? this.requirePinDiscount,
      requirePinCostPrice: requirePinCostPrice ?? this.requirePinCostPrice,
      requirePinStockAdjust: requirePinStockAdjust ?? this.requirePinStockAdjust,
      requirePinVoidInvoice: requirePinVoidInvoice ?? this.requirePinVoidInvoice,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SecuritySettings &&
        other.hasPin == hasPin &&
        other.isPinEnabled == isPinEnabled &&
        other.requirePinDiscount == requirePinDiscount &&
        other.requirePinCostPrice == requirePinCostPrice &&
        other.requirePinStockAdjust == requirePinStockAdjust &&
        other.requirePinVoidInvoice == requirePinVoidInvoice;
  }

  @override
  int get hashCode => Object.hash(
        hasPin,
        isPinEnabled,
        requirePinDiscount,
        requirePinCostPrice,
        requirePinStockAdjust,
        requirePinVoidInvoice,
      );
}
