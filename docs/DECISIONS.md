# Decisions

## Phase 0

### Project location

The app lives in `D:\Hekal`, not `C:\dev\garage_erp`. The path is plain ASCII with no spaces. Flutter Windows builds break or lock when the path contains Arabic characters or the folder is synced by OneDrive. Confirm this drive is not a OneDrive/Desktop synced folder before relying on daily builds.

### Flutter SDK location

Flutter is installed at `C:\dev\flutter` (stable 3.47.8, Dart 3.13.7). The SDK is kept outside the app repo so upgrades do not mix with project history.

### Visual Studio vs Build Tools

The machine had no Visual Studio. Phase 0 installed **Visual Studio 2022 Build Tools 17.14.42** with the `VCTools` workload, MSVC 14.44, CMake, and Windows 11 SDK 10.0.26100. That is enough for Flutter Windows. The full Community IDE is not required. Android SDK was not installed on purpose.

### No database in Phase 0

There was no attached `database.dart`. The Drift schema, `garage.sqlite`, repositories, and seed data are authored in **Phase 2** from the master prompt data model. Phase 0 only reserves `lib/core/db/`.

### Packages

Only packages listed in the master prompt are used. `cupertino_icons` from `flutter create` was removed. Versions are the latest compatible with Flutter 3.47 / Dart 3.13 at the time of bootstrap.

### Fonts

Google currently ships Cairo as one variable TTF (`Cairo[slnt,wght].ttf` from `google/fonts`). Static Regular/SemiBold/Bold files are not published on that tree. The variable file is copied to `assets/fonts/Cairo-Regular.ttf`, `Cairo-SemiBold.ttf`, and `Cairo-Bold.ttf` and registered at weights 400, 600, and 700 so the UI and later PDFs stay offline. Phase 1 will confirm joining and mixed Arabic/English in print.

### Offline rule

The app does not call the network, load Google Fonts at runtime, or send telemetry.

---

## Phase 1 — Arabic Printing Spike

### Arabic PDF Rendering Approach

The `pdf` package natively supports RTL layout and Arabic text reshaping when:
1. `pw.MultiPage` or `pw.Page` specifies `textDirection: pw.TextDirection.rtl`.
2. A true Arabic Unicode font is loaded (`Cairo-Regular.ttf`, `Cairo-SemiBold.ttf`, `Cairo-Bold.ttf`) and configured on the `pw.ThemeData`.
3. In `pdf`, `pw.Row` automatically inherits RTL directionality from the enclosing page context (`Directionality.of(context)`). Calling `textDirection` on `pw.Row` is invalid as `Flex` checks context.

### Evaluation of Arabic Rendering

| Test Item | Status | Notes |
| :--- | :--- | :--- |
| **Letter joining (تشبيك الحروف)** | سليم 100% | حزم الحروف متصلة بشكل طبيعي مع خط Cairo |
| **Directionality (RTL)** | سليم 100% | الجداول والمحاذاة تبدأ من اليمين لليسار |
| **Lam-Alef Ligature (لا)** | سليم | تظهر متصلة ومضبوطة |
| **Mixed Arabic + English runs** | سليم | مصطلحات مثل `MANN` و `5W-30` تظهر في مكانها الصحيح |
| **Western Numbers** | سليم | الأرقام إنجليزية (0-9) مع فواصل آلاف دون انقلاب الترتيب |
| **Arabic-Indic Numbers** | سليم | تظهر كما هي بدون تشويه |
| **Parentheses in RTL** | سليم | الأقواس تحيط بالكلمة بشكل صحيح |
| **Unbroken Word Wrapping** | سليم | الكلمات الطويلة تلتف بدون قطع غير منطقي |
| **Multi-page Pagination** | سليم | الفاتورة 25 سطر ترحل للصفحة 2 مع ترقيم "صفحة 1 من 2" |
| **80mm Receipt Continuous Height** | سليم | إيصال مدمج بعرض 80 مم بدون فواصل صفحات عشوائية |

### Printer Integration Decision

- **Interactive printing:** Use `Printing.layoutPdf` which invokes the native Windows Print dialog, allowing printer selection and scale verification (100% actual size).
- **Direct thermal receipt printing:** Use `Printing.directPrintPdf` when a thermal printer is selected in settings, avoiding annoying dialog popups for counter receipts.
- **Save as PDF fallback:** Exporting raw bytes directly to the user's `Documents` directory guarantees an offline paper trail even if printers run out of paper or disconnect.
- **RepaintBoundary fallback:** Rendering Flutter widgets to 300 DPI images was evaluated as fallback (d), but not needed because the Cairo TTF vector pipeline produced 100% sharp, selectable Arabic text directly.
