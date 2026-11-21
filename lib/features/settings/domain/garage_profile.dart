import 'package:flutter/foundation.dart';
import '../../../core/strings.dart';

/// Immutable domain model representing the service center / garage profile.
@immutable
class GarageProfile {
  const GarageProfile({
    this.name = AppStrings.garageNameDefault,
    this.subtitle = AppStrings.garageSubtitleDefault,
    this.phone = '',
    this.phone2 = '',
    this.address = '',
    this.taxNumber = '',
    this.commercialReg = '',
    this.invoiceFooterNote = AppStrings.invoiceFooterNoteDefault,
    this.customSummaryBarLeft = '',
    this.customSummaryBarRight = '',
    this.customDisclaimer = '',
    this.logoPath,
  });

  final String name;
  final String subtitle;
  final String phone;
  final String phone2;
  final String address;
  final String taxNumber;
  final String commercialReg;
  final String invoiceFooterNote;
  final String? customSummaryBarLeft;
  final String? customSummaryBarRight;
  final String? customDisclaimer;
  final String? logoPath;

  bool get hasLogo => logoPath != null && logoPath!.trim().isNotEmpty;

  GarageProfile copyWith({
    String? name,
    String? subtitle,
    String? phone,
    String? phone2,
    String? address,
    String? taxNumber,
    String? commercialReg,
    String? invoiceFooterNote,
    String? customSummaryBarLeft,
    String? customSummaryBarRight,
    String? customDisclaimer,
    String? logoPath,
    bool clearLogo = false,
  }) {
    return GarageProfile(
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      phone: phone ?? this.phone,
      phone2: phone2 ?? this.phone2,
      address: address ?? this.address,
      taxNumber: taxNumber ?? this.taxNumber,
      commercialReg: commercialReg ?? this.commercialReg,
      invoiceFooterNote: invoiceFooterNote ?? this.invoiceFooterNote,
      customSummaryBarLeft: customSummaryBarLeft ?? this.customSummaryBarLeft,
      customSummaryBarRight: customSummaryBarRight ?? this.customSummaryBarRight,
      customDisclaimer: customDisclaimer ?? this.customDisclaimer,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GarageProfile &&
        other.name == name &&
        other.subtitle == subtitle &&
        other.phone == phone &&
        other.phone2 == phone2 &&
        other.address == address &&
        other.taxNumber == taxNumber &&
        other.commercialReg == commercialReg &&
        other.invoiceFooterNote == invoiceFooterNote &&
        other.logoPath == logoPath;
  }

  @override
  int get hashCode => Object.hash(
        name,
        subtitle,
        phone,
        phone2,
        address,
        taxNumber,
        commercialReg,
        invoiceFooterNote,
        logoPath,
      );
}
