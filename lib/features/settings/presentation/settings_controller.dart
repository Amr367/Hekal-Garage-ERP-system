import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../../core/db/connection/connection.dart';
import '../../../core/db/providers.dart';
import '../../../core/db/services/backup_service.dart';
import '../../../core/strings.dart';
import '../data/pin_auth_service.dart';
import '../domain/garage_profile.dart';
import '../domain/printer_settings.dart';
import '../domain/security_settings.dart';

// ── Provider for PinAuthService ──────────────────────────────────────────────
final pinAuthServiceProvider = Provider<PinAuthService>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return PinAuthService(repo);
});

// ── Garage Profile State ─────────────────────────────────────────────────────
class GarageProfileNotifier extends AsyncNotifier<GarageProfile> {
  static const String keyName = 'garage_name';
  static const String keySubtitle = 'garage_subtitle';
  static const String keyPhone = 'garage_phone';
  static const String keyPhone2 = 'garage_phone2';
  static const String keyAddress = 'garage_address';
  static const String keyTaxNumber = 'garage_tax_number';
  static const String keyCommercialReg = 'garage_commercial_reg';
  static const String keyFooter = 'garage_invoice_footer';
  static const String keyJobCardDisclaimer = 'garage_job_card_disclaimer';
  static const String keyLogoPath = 'garage_logo_path';

  @override
  FutureOr<GarageProfile> build() async {
    final repo = ref.watch(settingsRepositoryProvider);

    var name = await repo.getWithDefault(keyName, AppStrings.garageNameDefault);
    var subtitle = await repo.getWithDefault(keySubtitle, AppStrings.garageSubtitleDefault);
    if (name == 'مركز الصيانة التخصصي للسيارات') {
      name = AppStrings.garageNameDefault;
      await repo.set(keyName, name);
    }
    if (subtitle == 'إدارة الصيانة والمخازن وقطع الغيار') {
      subtitle = AppStrings.garageSubtitleDefault;
      await repo.set(keySubtitle, subtitle);
    }
    final phone = await repo.getWithDefault(keyPhone, '');
    final phone2 = await repo.getWithDefault(keyPhone2, '');
    final address = await repo.getWithDefault(keyAddress, '');
    final taxNumber = await repo.getWithDefault(keyTaxNumber, '');
    final commercialReg = await repo.getWithDefault(keyCommercialReg, '');
    final footer = await repo.getWithDefault(keyFooter, AppStrings.invoiceFooterNoteDefault);
    final disclaimer = await repo.getWithDefault(keyJobCardDisclaimer, '');
    final logoPath = await repo.get(keyLogoPath);

    return GarageProfile(
      name: name,
      subtitle: subtitle,
      phone: phone,
      phone2: phone2,
      address: address,
      taxNumber: taxNumber,
      commercialReg: commercialReg,
      invoiceFooterNote: footer,
      customDisclaimer: disclaimer,
      logoPath: (logoPath != null && File(logoPath).existsSync()) ? logoPath : null,
    );
  }

  Future<void> saveProfile(GarageProfile profile) async {
    state = AsyncValue.data(profile);
    final repo = ref.read(settingsRepositoryProvider);

    await repo.set(keyName, profile.name);
    await repo.set(keySubtitle, profile.subtitle);
    await repo.set(keyPhone, profile.phone);
    await repo.set(keyPhone2, profile.phone2);
    await repo.set(keyAddress, profile.address);
    await repo.set(keyTaxNumber, profile.taxNumber);
    await repo.set(keyCommercialReg, profile.commercialReg);
    await repo.set(keyFooter, profile.invoiceFooterNote);
    await repo.set(keyJobCardDisclaimer, profile.customDisclaimer ?? '');
    if (profile.logoPath != null) {
      await repo.set(keyLogoPath, profile.logoPath!);
    } else {
      await repo.set(keyLogoPath, '');
    }
  }

  Future<String?> pickAndSaveLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );

    if (result == null || result.files.single.path == null) {
      return null;
    }

    final sourcePath = result.files.single.path!;
    final appSupportDir = await getApplicationSupportDirectory();
    final ext = p.extension(sourcePath);
    final targetPath = p.join(appSupportDir.path, 'garage_logo$ext');

    // Copy to app support directory for offline durability
    await File(sourcePath).copy(targetPath);

    final current = state.value ?? const GarageProfile();
    final updated = current.copyWith(logoPath: targetPath);
    await saveProfile(updated);
    return targetPath;
  }

  Future<void> removeLogo() async {
    final current = state.value ?? const GarageProfile();
    if (current.logoPath != null) {
      try {
        final file = File(current.logoPath!);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
    final updated = current.copyWith(clearLogo: true);
    await saveProfile(updated);
  }
}

final garageProfileProvider =
    AsyncNotifierProvider<GarageProfileNotifier, GarageProfile>(() {
  return GarageProfileNotifier();
});

// ── Printer Settings State ───────────────────────────────────────────────────
class PrinterSettingsNotifier extends AsyncNotifier<PrinterSettings> {
  static const String keyInvoicePrinter = 'printer_default_invoice';
  static const String keyReceiptPrinter = 'printer_default_receipt';
  static const String keyPaperSize = 'printer_default_paper_size';
  static const String keyAutoPrint = 'printer_auto_print';

  @override
  FutureOr<PrinterSettings> build() async {
    final repo = ref.watch(settingsRepositoryProvider);

    final invoicePrinter = await repo.get(keyInvoicePrinter);
    final receiptPrinter = await repo.get(keyReceiptPrinter);
    final paperSize = await repo.getWithDefault(keyPaperSize, 'A4');
    final autoPrint = await repo.getBool(keyAutoPrint, false);

    return PrinterSettings(
      invoicePrinter: invoicePrinter?.isNotEmpty == true ? invoicePrinter : null,
      receiptPrinter: receiptPrinter?.isNotEmpty == true ? receiptPrinter : null,
      defaultPaperSize: paperSize,
      autoPrintOnSave: autoPrint,
    );
  }

  Future<void> saveSettings(PrinterSettings settings) async {
    state = AsyncValue.data(settings);
    final repo = ref.read(settingsRepositoryProvider);

    await repo.set(keyInvoicePrinter, settings.invoicePrinter ?? '');
    await repo.set(keyReceiptPrinter, settings.receiptPrinter ?? '');
    await repo.set(keyPaperSize, settings.defaultPaperSize);
    await repo.setBool(keyAutoPrint, settings.autoPrintOnSave);
  }
}

final printerSettingsProvider =
    AsyncNotifierProvider<PrinterSettingsNotifier, PrinterSettings>(() {
  return PrinterSettingsNotifier();
});

// ── Security Settings State ──────────────────────────────────────────────────
class SecuritySettingsNotifier extends AsyncNotifier<SecuritySettings> {
  @override
  FutureOr<SecuritySettings> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    final authService = ref.watch(pinAuthServiceProvider);

    final hasPin = await authService.hasPin();
    final isEnabled = await authService.isPinEnabled();
    final reqDiscount = await repo.getBool(PinAuthService.keyRequireDiscount, true);
    final reqCostPrice = await repo.getBool(PinAuthService.keyRequireCostPrice, true);
    final reqStockAdjust = await repo.getBool(PinAuthService.keyRequireStockAdjust, true);
    final reqVoidInvoice = await repo.getBool(PinAuthService.keyRequireVoidInvoice, true);

    return SecuritySettings(
      hasPin: hasPin,
      isPinEnabled: isEnabled,
      requirePinDiscount: reqDiscount,
      requirePinCostPrice: reqCostPrice,
      requirePinStockAdjust: reqStockAdjust,
      requirePinVoidInvoice: reqVoidInvoice,
    );
  }

  Future<void> setPin(String newPin) async {
    final authService = ref.read(pinAuthServiceProvider);
    await authService.setPin(newPin);
    ref.invalidateSelf();
  }

  Future<void> togglePinEnabled(bool enabled) async {
    final authService = ref.read(pinAuthServiceProvider);
    if (enabled) {
      await authService.enablePin();
    } else {
      await authService.disablePin();
    }
    ref.invalidateSelf();
  }

  Future<void> saveFlags({
    required bool requireDiscount,
    required bool requireCostPrice,
    required bool requireStockAdjust,
    required bool requireVoidInvoice,
  }) async {
    final repo = ref.read(settingsRepositoryProvider);

    await repo.setBool(PinAuthService.keyRequireDiscount, requireDiscount);
    await repo.setBool(PinAuthService.keyRequireCostPrice, requireCostPrice);
    await repo.setBool(PinAuthService.keyRequireStockAdjust, requireStockAdjust);
    await repo.setBool(PinAuthService.keyRequireVoidInvoice, requireVoidInvoice);

    final current = state.value ?? const SecuritySettings();
    state = AsyncValue.data(
      current.copyWith(
        requirePinDiscount: requireDiscount,
        requirePinCostPrice: requireCostPrice,
        requirePinStockAdjust: requireStockAdjust,
        requirePinVoidInvoice: requireVoidInvoice,
      ),
    );
  }
}

final securitySettingsProvider =
    AsyncNotifierProvider<SecuritySettingsNotifier, SecuritySettings>(() {
  return SecuritySettingsNotifier();
});

// ── Installed Printers Provider ──────────────────────────────────────────────
final installedPrintersProvider = FutureProvider<List<Printer>>((ref) async {
  try {
    return await Printing.listPrinters();
  } catch (_) {
    return const <Printer>[];
  }
});

// ── Database Info Provider ───────────────────────────────────────────────────
class DatabaseInfo {
  const DatabaseInfo({
    required this.path,
    required this.sizeFormatted,
  });

  final String path;
  final String sizeFormatted;
}

final databaseInfoProvider = FutureProvider<DatabaseInfo>((ref) async {
  final dbPath = DbConnection.databasePath ?? 'غير محدد';
  String sizeFormatted = '0 KB';

  if (dbPath != 'غير محدد') {
    final file = File(dbPath);
    if (file.existsSync()) {
      final bytes = file.lengthSync();
      if (bytes < 1024 * 1024) {
        sizeFormatted = '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else {
        sizeFormatted = '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
      }
    }
  }

  return DatabaseInfo(path: dbPath, sizeFormatted: sizeFormatted);
});

final recentBackupsProvider = FutureProvider<List<File>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return BackupService(db).listAutoBackups();
});
