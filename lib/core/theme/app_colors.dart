import 'package:flutter/material.dart';

/// App color palette defining calm, high-contrast colors.
abstract final class AppColors {
  // ── Primary ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1F4E5F); // Deep Slate Teal
  static const Color onPrimary = Colors.white;
  static const Color primaryContainer = Color(0xFFE2EDF0);
  static const Color onPrimaryContainer = Color(0xFF0E2730);

  // ── Secondary ────────────────────────────────────────────────────────
  static const Color secondary = Color(0xFF455A64); // Slate Grey
  static const Color onSecondary = Colors.white;
  static const Color secondaryContainer = Color(0xFFECEFF1);
  static const Color onSecondaryContainer = Color(0xFF1C272C);

  // ── Neutral / Surfaces ───────────────────────────────────────────────
  static const Color background = Color(0xFFF7F9FA); // Very light grey-blue
  static const Color surface = Colors.white;
  static const Color onSurface = Color(0xFF192428); // High contrast dark charcoal
  static const Color surfaceVariant = Color(0xFFEFF2F3);
  static const Color onSurfaceVariant = Color(0xFF455A64);
  static const Color border = Color(0xFFCFD8DC);
  static const Color divider = Color(0xFFE0E0E0);

  // ── Semantic ─────────────────────────────────────────────────────────
  // Danger (Red)
  static const Color danger = Color(0xFFD32F2F);
  static const Color onDanger = Colors.white;
  static const Color dangerContainer = Color(0xFFFFEBEE);
  static const Color onDangerContainer = Color(0xFFB71C1C);

  // Success (Green)
  static const Color success = Color(0xFF2E7D32);
  static const Color onSuccess = Colors.white;
  static const Color successContainer = Color(0xFFE8F5E9);
  static const Color onSuccessContainer = Color(0xFF1B5E20);

  // Warning (Amber / Orange)
  static const Color warning = Color(0xFFED6C02);
  static const Color onWarning = Colors.white;
  static const Color warningContainer = Color(0xFFFFF3E0);
  static const Color onWarningContainer = Color(0xFFE65100);

  // Info (Blue)
  static const Color info = Color(0xFF0288D1);
  static const Color onInfo = Colors.white;
  static const Color infoContainer = Color(0xFFE1F5FE);
  static const Color onInfoContainer = Color(0xFF01579B);

  // Aliases for ergonomics
  static const Color error = danger;
  static const Color onError = onDanger;
  static const Color errorContainer = dangerContainer;
  static const Color textPrimary = onSurface;
  static const Color textSecondary = onSurfaceVariant;
}
