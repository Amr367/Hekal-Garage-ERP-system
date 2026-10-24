import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../../../core/db/repositories/settings_repository.dart';
import '../../../core/money/money.dart';
import '../../../core/strings.dart';
import '../../../core/widgets/pin_dialog.dart';
import '../../../core/widgets/state_views.dart';

/// Service implementing Domain Rule R12:
/// Salted PIN hashing (never store PIN in plain text) for sensitive operations.
class PinAuthService {
  PinAuthService(this._settingsRepo);

  final SettingsRepository _settingsRepo;

  static const String keyPinHash = 'security_pin_hash';
  static const String keyPinSalt = 'security_pin_salt';
  static const String keyPinEnabled = 'security_pin_enabled';
  static const String keyRequireDiscount = 'security_req_discount';
  static const String keyRequireCostPrice = 'security_req_cost_price';
  static const String keyRequireStockAdjust = 'security_req_stock_adjust';
  static const String keyRequireVoidInvoice = 'security_req_void_invoice';

  /// Generates a cryptographically secure random hex salt.
  static String generateSalt([int length = 16]) {
    final Random random = Random.secure();
    final List<int> values = List<int>.generate(length, (_) => random.nextInt(256));
    return values.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hashes [pin] using SHA-256 with [salt].
  static String hashPin(String pin, String salt) {
    final normalized = MoneyUtils.normalizeDigits(pin.trim());
    final bytes = utf8.encode('$salt:$normalized');
    return sha256.convert(bytes).toString();
  }

  /// Returns true if a PIN has been set in the database.
  Future<bool> hasPin() async {
    final hash = await _settingsRepo.get(keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Returns true if PIN protection is enabled.
  Future<bool> isPinEnabled() async {
    final has = await hasPin();
    if (!has) return false;
    return _settingsRepo.getBool(keyPinEnabled, true);
  }

  /// Sets or updates the 4-digit PIN with a new random salt.
  Future<void> setPin(String newPin) async {
    final normalized = MoneyUtils.normalizeDigits(newPin.trim());
    if (normalized.length != 4 || int.tryParse(normalized) == null) {
      throw ArgumentError(AppStrings.pinMustBe4Digits);
    }

    final salt = generateSalt();
    final hash = hashPin(normalized, salt);

    await _settingsRepo.set(keyPinSalt, salt);
    await _settingsRepo.set(keyPinHash, hash);
    await _settingsRepo.setBool(keyPinEnabled, true);
  }

  /// Disables PIN enforcement (does not delete hash/salt so it can be re-enabled).
  Future<void> disablePin() async {
    await _settingsRepo.setBool(keyPinEnabled, false);
  }

  /// Re-enables PIN enforcement.
  Future<void> enablePin() async {
    await _settingsRepo.setBool(keyPinEnabled, true);
  }

  /// Verifies if [rawPin] matches the stored salted hash.
  Future<bool> verifyPin(String rawPin) async {
    final storedHash = await _settingsRepo.get(keyPinHash);
    final salt = await _settingsRepo.get(keyPinSalt);

    if (storedHash == null || salt == null) {
      return false;
    }

    final computedHash = hashPin(rawPin, salt);
    return computedHash == storedHash;
  }

  /// Checks if a sensitive operation is allowed.
  /// If PIN protection is enabled, presents [PinDialog].
  /// Returns `true` if authorized, `false` otherwise.
  Future<bool> checkPermission(
    BuildContext context, {
    String? prompt,
  }) async {
    final enabled = await isPinEnabled();
    if (!enabled) {
      return true;
    }

    if (!context.mounted) return false;

    final enteredPin = await PinDialog.show(
      context: context,
      prompt: prompt ?? AppStrings.enterPinPrompt,
    );

    if (enteredPin == null) {
      return false; // User cancelled
    }

    final valid = await verifyPin(enteredPin);
    if (!valid) {
      if (context.mounted) {
        AppSnackbar.showError(context, AppStrings.pinInvalid);
      }
      return false;
    }

    return true;
  }
}
