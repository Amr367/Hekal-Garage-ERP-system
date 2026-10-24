/// Every user-facing UI string lives here. Widgets must not hard-code Arabic.
abstract final class AppStrings {
  static const String appTitle = 'نظام مركز الصيانة';
  static const String bootstrapHeadline = 'نظام مركز الصيانة والمخزن';
  static const String bootstrapBody =
      'التطبيق شغال أوفلاين بالكامل. الواجهة عربي من اليمين لليسار، والخط المستخدم Cairo.';
  static const String bootstrapPhaseLabel = 'مرحلة 2 — طبقة الداتابيز ومستودعات البيانات';
  static const String currencyLabel = 'العملة: الجنيه المصري (ج.م)';
  static const String rtlProofLabel = 'اتجاه النص: من اليمين لليسار';

  // ── Phase 1: print test ──────────────────────────────────────────
  static const String printTestTitle = 'اختبار الطباعة العربي';
  static const String printTestPreviewA4 = 'معاينة فاتورة A4';
  static const String printTestPreviewReceipt = 'معاينة إيصال 80mm';
  static const String printTestButton = 'اختبار الطباعة';

  // ── Phase 2: database ────────────────────────────────────────────
  static const String openDatabaseFolder = 'فتح مجلد قاعدة البيانات';
  static const String loadSeedData = 'تحميل البيانات الأولية (أقسام وخدمات)';
  static const String seedDataLoadedSuccess = 'تم تحميل البيانات الأولية بنجاح.';
  static const String seedDataAlreadyLoaded = 'البيانات الأولية محملة مسبقاً.';
}
