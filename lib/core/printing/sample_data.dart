/// Sample data for the Phase 1 Arabic printing spike.
///
/// Contains torture-test strings that exercise letter joining, mixed
/// Arabic/English/digit runs, lam-alef ligatures, diacritics, very long
/// words, parentheses inside RTL, and plate-number formatting.
abstract final class PrintSampleData {
  // ── Shop header ────────────────────────────────────────────────────
  static const String shopName = 'مركز الحكل لصيانة السيارات';
  static const String shopAddress = 'شارع الملك فيصل — الجيزة — مصر';
  static const String shopPhone1 = '01012345678';
  static const String shopPhone2 = '01198765432';

  // ── Invoice header ─────────────────────────────────────────────────
  static const String invoiceNumber = '000123';
  static const String invoiceDate = '24/10/2026';
  static const String customerName = 'أحمد عبد الرحمن محمد';
  static const String customerPhone = '01234567890';
  static const String plateNumber = 'أ ب ج 1234';
  static const String carMakeModel = 'تويوتا كورولا 2019';
  static const String odometer = '85,230 كم';

  // ── Invoice lines (torture-test strings) ───────────────────────────
  static const List<SampleInvoiceLine> lines = <SampleInvoiceLine>[
    SampleInvoiceLine('تغيير زيت المحرك', 1, 15000, 15000),
    SampleInvoiceLine('فلتر زيت أصلي MANN', 1, 8500, 8500),
    SampleInvoiceLine('زيت موتول 5W-30 – 4 لتر', 4, 25000, 100000),
    SampleInvoiceLine('فلتر هواء المحرك', 1, 6000, 6000),
    SampleInvoiceLine('فلتر مكيّف (كربون)', 1, 12000, 12000),
    SampleInvoiceLine('تغيير تيل فرامل أمامي BREMBO', 1, 35000, 35000),
    SampleInvoiceLine('تغيير تيل فرامل خلفي', 1, 28000, 28000),
    SampleInvoiceLine('خرطوم مياه رادياتير (علوي)', 1, 9500, 9500),
    SampleInvoiceLine('سائل تبريد (أخضر) 2 لتر', 2, 7500, 15000),
    SampleInvoiceLine('غسيل وتشحيم شامل', 1, 10000, 10000),
    SampleInvoiceLine('فحص كمبيوتر (OBD-II)', 1, 5000, 5000),
    SampleInvoiceLine('ضبط زوايا بالليزر', 1, 15000, 15000),
    SampleInvoiceLine('ترصيص 4 إطارات', 4, 2500, 10000),
    SampleInvoiceLine('سير مجموعة (Kit – Gates)', 1, 45000, 45000),
    SampleInvoiceLine('شمعات إشعال NGK Iridium × 4', 4, 6000, 24000),
    SampleInvoiceLine('بطارية فارتا 60 أمبير (VARTA)', 1, 180000, 180000),
    SampleInvoiceLine('مساعد أمامي يمين KYB', 1, 55000, 55000),
    SampleInvoiceLine('مساعد أمامي يسار KYB', 1, 55000, 55000),
    SampleInvoiceLine('كشف كهرباء + إصلاح ضفيرة', 1, 20000, 20000),
    SampleInvoiceLine('إطار ميشلان 205/55R16 Primacy 4', 4, 95000, 380000),
    SampleInvoiceLine('مقص علوي يمين (بالمحمل)', 1, 42000, 42000),
    SampleInvoiceLine('مقص علوي يسار (بالمحمل)', 1, 42000, 42000),
    SampleInvoiceLine(
      'طقم جلد مكابح خلفي — الاسطوانة الرئيسية فقط',
      1,
      18000,
      18000,
    ),
    SampleInvoiceLine('زجاج أمامي (بارا بريز) Pilkington', 1, 250000, 250000),
    SampleInvoiceLine(
      // Very long unbroken word to test wrapping.
      'ممتصاصاتاهتزازاتمحركعلويسفليأماميخلفييمينيسار',
      1,
      1000,
      1000,
    ),
  ];

  // ── Totals ─────────────────────────────────────────────────────────
  static const int subtotal = 137800000; // = sum of all line totals
  // Actual sum: let the builder compute it; these are for the preview.
  static const int discount = 5000000; // 50,000.00 EGP discount
  static const int total = 132800000; // subtotal − discount
  static const int paid = 100000000; // 1,000,000.00 EGP paid
  static const int remaining = 32800000; // total − paid

  // ── Footer ─────────────────────────────────────────────────────────
  static const String footerTerms =
      'الضمان لا يشمل سوء الاستخدام. يُرجى الاحتفاظ بالفاتورة.';
  static const String thankYou = 'شكرًا لزيارتكم — نتمنى لكم رحلة آمنة';

  // ── Torture-test extras ────────────────────────────────────────────
  /// Lam-alef ligature, diacritics, mixed parentheses.
  static const String tortureText1 = 'لا إله إلّا الله (تجربة لام-ألف)';

  /// English brand in the middle of Arabic.
  static const String tortureText2 =
      'زيت Castrol EDGE 5W-30 (تخليقي بالكامل / Fully Synthetic)';

  /// Arabic-Indic digits.
  static const String tortureText3 = 'رقم اللوحة: ١٢٣٤ أ ب ج';

  /// Thousands separator and decimals.
  static const String tortureText4 = 'الإجمالي: 1,250.50 ج.م';

  /// Slash and parentheses in RTL.
  static const String tortureText5 = 'قطعة (OEM/After-market) — 3 قطع';
}

/// A single line in the sample invoice.
class SampleInvoiceLine {
  const SampleInvoiceLine(
    this.description,
    this.quantity,
    this.unitPrice,
    this.total,
  );

  final String description;
  final int quantity;

  /// Price in piasters.
  final int unitPrice;

  /// Total in piasters.
  final int total;
}
